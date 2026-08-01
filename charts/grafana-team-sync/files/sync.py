#!/usr/bin/env python3
"""Reconcile Grafana teams and folder permissions from GitLab group membership.

Grafana OSS can express the access model we want — everyone reads every dashboard, each
team writes only inside its own folder — because folder permissions are additive on top of
the org role and cover alert rules as well as dashboards. What OSS cannot do is Team Sync,
the mapping of IdP groups onto Grafana teams at login; that is an Enterprise feature. This
job is that missing piece, pushed in from outside on a schedule.

Teams are not configured here. They are discovered from GrafanaFolder custom resources
carrying a team label, which idp-argocd-user-apps renders from its own `teams` list. That
indirection is deliberate: onboarding a team stays a single-file edit in one repository,
and this job picks the new team up on its next run with no deployment of its own.

Only the Python standard library is used, so the job runs on a stock python image with no
package installation and no supply chain of its own.
"""

import base64
import json
import logging
import os
import re
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request

# Permission levels as understood by Grafana's folder permissions API.
PERMISSION_VIEW = 1
PERMISSION_EDIT = 2

SERVICEACCOUNT = "/var/run/secrets/kubernetes.io/serviceaccount"

# GitLab surfaces group and project access tokens as synthetic "bot" members of the group.
# They must not be propagated into Grafana teams — including this job's own token, which
# would otherwise appear as a member of every team it syncs.
BOT_USERNAME = re.compile(r"^(group|project)_\d+_bot")

log = logging.getLogger("grafana-team-sync")


def request(url, *, method="GET", headers=None, body=None, context=None, allow_404=False):
    """Perform one HTTP request, returning (payload, response_headers).

    Returns (None, None) for a 404 when allow_404 is set; every other error status raises.
    """
    data = json.dumps(body).encode() if body is not None else None
    headers = dict(headers or {})
    if data:
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, context=context, timeout=30) as response:
            raw = response.read()
            payload = json.loads(raw) if raw else None
            return payload, response.headers
    except urllib.error.HTTPError as err:
        if err.code == 404 and allow_404:
            return None, None
        # The response body carries Grafana's and GitLab's actual error messages, which are
        # far more useful than the status line alone when a run fails at 03:00.
        detail = err.read().decode(errors="replace")[:500]
        raise RuntimeError(f"{method} {url} failed: HTTP {err.code}: {detail}") from err


# --- Discovery: which teams exist, according to the cluster -------------------------------

def discover_teams(team_label, group_annotation):
    """List GrafanaFolder CRs marked as team-owned.

    Yields (team_name, gitlab_group, folder_uid) for each. The folder is created and owned
    by grafana-operator; this job only reads the CR to learn what to reconcile.
    """
    with open(f"{SERVICEACCOUNT}/token", encoding="utf-8") as handle:
        token = handle.read().strip()
    context = ssl.create_default_context(cafile=f"{SERVICEACCOUNT}/ca.crt")

    url = (
        "https://kubernetes.default.svc"
        "/apis/grafana.integreatly.org/v1beta1/grafanafolders"
        f"?labelSelector={urllib.parse.quote(team_label)}"
    )
    payload, _ = request(
        url, headers={"Authorization": f"Bearer {token}"}, context=context
    )

    teams = []
    for item in payload.get("items", []):
        metadata = item["metadata"]
        name = metadata["labels"][team_label]
        group = metadata.get("annotations", {}).get(group_annotation)
        uid = item.get("spec", {}).get("uid")
        if not group or not uid:
            log.error(
                "GrafanaFolder %s/%s is labelled as team-owned but is missing %s or spec.uid; skipping",
                metadata["namespace"], metadata["name"], group_annotation,
            )
            continue
        teams.append((name, group, uid))
    return sorted(teams)


# --- GitLab: the desired membership -------------------------------------------------------

def gitlab_members(base_url, token, group_path):
    """Return the set of usernames in a GitLab group.

    Uses /members/all rather than /members so that members inherited from the parent `idp`
    group are included — someone granted access at the `idp` level is a real member of the
    subgroup as far as GitLab authorization is concerned, so Grafana should agree.
    """
    usernames = set()
    page = 1
    while True:
        url = (
            f"{base_url}/api/v4/groups/{urllib.parse.quote(group_path, safe='')}"
            f"/members/all?per_page=100&page={page}"
        )
        payload, headers = request(url, headers={"PRIVATE-TOKEN": token})
        for member in payload:
            username = member["username"]
            if member.get("state") != "active":
                continue
            if BOT_USERNAME.match(username):
                continue
            usernames.add(username.lower())

        next_page = headers.get("X-Next-Page")
        if not next_page:
            return usernames
        page = int(next_page)


# --- Grafana: the current state, and how to move it ---------------------------------------

def grafana_request(base_url, auth, path, **kwargs):
    return request(f"{base_url}{path}", headers={"Authorization": auth}, **kwargs)[0]


def ensure_team(base_url, auth, name):
    """Return the numeric id of the Grafana team called `name`, creating it if absent.

    The numeric id is the reason this job exists in the shape it does: folder permissions
    reference a team by id, which Grafana assigns at creation time and which therefore
    cannot be written into a GrafanaFolder manifest in git.
    """
    found = grafana_request(
        base_url, auth, f"/api/teams/search?name={urllib.parse.quote(name)}"
    )
    for team in found.get("teams", []):
        if team["name"] == name:
            return team["id"]

    created = grafana_request(base_url, auth, "/api/teams", method="POST", body={"name": name})
    log.info("created Grafana team %s (id %s)", name, created["teamId"])
    return created["teamId"]


def reconcile_members(base_url, auth, team_id, team_name, desired):
    """Align a Grafana team's membership with `desired`, a set of lowercased logins."""
    current = {
        member["login"].lower(): member["userId"]
        for member in grafana_request(base_url, auth, f"/api/teams/{team_id}/members")
    }

    for login in sorted(desired - current.keys()):
        user = grafana_request(
            base_url, auth,
            f"/api/users/lookup?loginOrEmail={urllib.parse.quote(login)}",
            allow_404=True,
        )
        # Grafana creates a user record on first OAuth login, so a GitLab member who has
        # never opened Grafana simply does not exist yet. That is expected, not an error;
        # they will be picked up by a later run once they sign in.
        if user is None:
            log.warning(
                "%s is in the GitLab group for %s but has never signed in to Grafana; skipping",
                login, team_name,
            )
            continue
        grafana_request(
            base_url, auth, f"/api/teams/{team_id}/members",
            method="POST", body={"userId": user["id"]},
        )
        log.info("added %s to team %s", login, team_name)

    for login in sorted(current.keys() - desired):
        grafana_request(
            base_url, auth, f"/api/teams/{team_id}/members/{current[login]}", method="DELETE"
        )
        log.info("removed %s from team %s", login, team_name)


def write_folder_permissions(base_url, auth, folder_uid, team_id):
    """Grant everyone read and the owning team write on one folder.

    This endpoint replaces the folder's entire permission list rather than merging into it,
    which is what makes the job idempotent and what strips the default `Editor -> Edit`
    entry that Grafana attaches to new folders. Removing it matters: write access is meant
    to come only from team membership, never from an org role.
    """
    grafana_request(
        base_url, auth, f"/api/folders/{folder_uid}/permissions",
        method="POST",
        body={"items": [
            {"role": "Viewer", "permission": PERMISSION_VIEW},
            {"teamId": team_id, "permission": PERMISSION_EDIT},
        ]},
    )


def main():
    logging.basicConfig(
        level=logging.INFO, format="%(levelname)s %(name)s %(message)s", stream=sys.stdout
    )

    grafana_url = os.environ["GRAFANA_URL"].rstrip("/")
    gitlab_url = os.environ["GITLAB_URL"].rstrip("/")
    gitlab_token = os.environ["GITLAB_TOKEN"]
    team_label = os.environ["TEAM_LABEL"]
    group_annotation = os.environ["GITLAB_GROUP_ANNOTATION"]

    credentials = f"{os.environ['GRAFANA_USER']}:{os.environ['GRAFANA_PASSWORD']}"
    auth = "Basic " + base64.b64encode(credentials.encode()).decode()

    teams = discover_teams(team_label, group_annotation)
    if not teams:
        log.info("no GrafanaFolders labelled %s found; nothing to do", team_label)
        return 0
    log.info("reconciling %d team(s): %s", len(teams), ", ".join(name for name, _, _ in teams))

    # Every team is attempted even when an earlier one fails, so that a single broken GitLab
    # group cannot stop the rest from converging. Failures are collected and reported at the
    # end so the Job is still marked failed and retried.
    failed = []
    for name, group, folder_uid in teams:
        try:
            desired = gitlab_members(gitlab_url, gitlab_token, group)
            team_id = ensure_team(grafana_url, auth, name)
            reconcile_members(grafana_url, auth, team_id, name, desired)
            write_folder_permissions(grafana_url, auth, folder_uid, team_id)
            log.info(
                "team %s: %d GitLab member(s), folder %s writable by team %s",
                name, len(desired), folder_uid, team_id,
            )
        except (RuntimeError, KeyError, ValueError) as err:
            log.error("team %s failed: %s", name, err)
            failed.append(name)

    if failed:
        log.error("failed to reconcile: %s", ", ".join(failed))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
