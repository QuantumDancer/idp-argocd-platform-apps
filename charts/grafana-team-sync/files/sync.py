#!/usr/bin/env python3
"""Reconcile Grafana teams and folder permissions from GitLab group membership.

Grafana OSS can express the access model we want — everyone reads every dashboard, each
team writes only inside its own folder — because folder permissions are additive on top of
the org role and cover alert rules as well as dashboards. What OSS cannot do is Team Sync,
the mapping of IdP groups onto Grafana teams at login; that is an Enterprise feature. This
job is that missing piece, pushed in from outside on a schedule.

Teams are not configured here. They are discovered from the GrafanaFolder custom resources
that the platform already creates for them: one home folder per team from the
TeamInfraEnvironment Crossplane XR, plus one per system scaffolded by Backstage. All of them
carry an `idp.rottler.io/team` label naming their owning team, so that label — rather than
any list maintained here — is the source of truth, and a team gains write access to a new
folder the moment the platform labels one for it.

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

def discover_team_folders(team_label):
    """Map each team name to the Grafana folder UIDs it owns.

    Every GrafanaFolder the platform creates for a team is labelled with that team's name:
    the home folder from the TeamInfraEnvironment XR, and one per Backstage-scaffolded
    system. A team is granted write access to all of them.

    Folders are keyed by UID rather than by CR, because Backstage renders one CR per
    component of a system while all of them point at the same folder — writing that folder's
    permissions once per component would be redundant, not merely untidy.
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

    owned = {}
    for item in payload.get("items", []):
        metadata = item["metadata"]
        uid = item.get("spec", {}).get("uid")
        # grafana-operator generates a UID when the CR omits one, and that generated value
        # is not readable from the spec. Such a folder cannot be addressed here, so skip it
        # loudly rather than guessing.
        if not uid:
            log.warning(
                "GrafanaFolder %s/%s has no spec.uid; skipping",
                metadata["namespace"], metadata["name"],
            )
            continue
        owned.setdefault(metadata["labels"][team_label], set()).add(uid)

    return {team: sorted(uids) for team, uids in sorted(owned.items())}


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
    # The GitLab group is derived from the team name rather than read off the folder,
    # matching the same convention the AppProject template already hardcodes. That keeps
    # this job working against folders the platform creates without needing them annotated.
    group_pattern = os.environ["GITLAB_GROUP_PATTERN"]

    credentials = f"{os.environ['GRAFANA_USER']}:{os.environ['GRAFANA_PASSWORD']}"
    auth = "Basic " + base64.b64encode(credentials.encode()).decode()

    teams = discover_team_folders(team_label)
    if not teams:
        log.info("no GrafanaFolders labelled %s found; nothing to do", team_label)
        return 0
    log.info("reconciling %d team(s): %s", len(teams), ", ".join(teams))

    # Every team is attempted even when an earlier one fails, so that a single broken GitLab
    # group cannot stop the rest from converging. Failures are collected and reported at the
    # end so the Job is still marked failed and retried.
    failed = []
    for name, folder_uids in teams.items():
        try:
            desired = gitlab_members(gitlab_url, gitlab_token, group_pattern.format(team=name))
            team_id = ensure_team(grafana_url, auth, name)
            reconcile_members(grafana_url, auth, team_id, name, desired)
            for folder_uid in folder_uids:
                write_folder_permissions(grafana_url, auth, folder_uid, team_id)
            log.info(
                "team %s: %d GitLab member(s), %d folder(s) writable by team %s: %s",
                name, len(desired), len(folder_uids), team_id, ", ".join(folder_uids),
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
