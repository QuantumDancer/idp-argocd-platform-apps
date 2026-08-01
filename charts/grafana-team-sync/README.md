# grafana-team-sync

Reconciles Grafana teams, their membership, and per-team folder permissions from GitLab
group membership.

## Why this exists

The access model is: **everyone reads every dashboard, each team writes only inside its own
folder** — where "writes" includes creating alert rules, not just dashboards.

Grafana OSS can express this. Folder permissions are additive on top of the org role and
apply to every resource in the folder, so a user whose org role is `Viewer` and who holds
`Edit` on `team-a/` can create dashboards and alert rules there and nowhere else. No user
is ever given the `Editor` org role; write access comes only from folder grants.

What Grafana OSS *cannot* do is **Team Sync** — mapping IdP groups onto Grafana teams at
login. That is an Enterprise feature. This CronJob is that missing piece, pushed in from
outside on a schedule.

## How a team gets here

Teams are **not** configured in this chart, and this chart creates no folders. The platform
already provisions every folder a team owns, and labels each one with its owning team:

| Folder | Created by | Example UID |
| --- | --- | --- |
| Team home folder | `TeamInfraEnvironment` Crossplane XR | `team-a` |
| Per-system folder | Backstage scaffolder | `team-a-e2e-backstage-test` |

Both carry `idp.rottler.io/team: team-a`. That label is the source of truth, so this job
simply lists the labelled folders and grants each team `Edit` on all of its own:

```
GrafanaFolders labelled idp.rottler.io/team
        │
        ▼
this CronJob, every 15 minutes
        │
GitLab group idp/<team>  ──>  Grafana team <team>  ──>  Edit on every folder it owns
```

Onboarding `team-c` is a two-line edit to `teams` in
[`idp-argocd-user-apps`](https://gitlab.home.rottlr.de/idp/platform/idp-argocd-user-apps)'s
`values.yaml` — the same edit that already creates its `AppProject` and its
`TeamInfraEnvironment`. Nothing here changes and nothing needs redeploying.

The GitLab group path is derived from the team name via `gitlabGroupPattern`
(`idp/{team}` by default), mirroring the convention the `AppProject` template already
hardcodes. That is what lets the job work against folders it does not own without requiring
them to be annotated.

Folders are deduplicated by `spec.uid`, because Backstage renders one CR per *component* of
a system while all of a system's components share a single folder.

## Why folder permissions are not in the GrafanaFolder manifest

`GrafanaFolder.spec.permissions` exists and takes raw JSON, but Grafana's folder permissions
API identifies a team by a **numeric id** assigned at team creation time. That id has no
stable representation in git. So the folder manifests leave `spec.permissions` unset — which
also means grafana-operator does not manage the ACL and will not fight this job — and the
CronJob, which has resolved the id, writes it.

The job writes the folder's permission list with a single `POST`, which **replaces** rather
than merges. That is what makes it idempotent, and what strips the default `Editor → Edit`
entry Grafana attaches to new folders.

## Prerequisite: the GitLab token

A **group access token on the `idp` group** — not a personal access token. It is scoped to
exactly the subtree the job reads, survives people leaving, and cannot see anything outside
`idp/`.

Create at `https://gitlab.home.rottlr.de/idp` → **Settings → Access tokens → Add new token**:

| Field | Value |
| --- | --- |
| Token name | `grafana-team-sync` |
| Expiry date | Required, max 1 year — **needs rotation** |
| Role | `Reporter` (minimum that can list members of a private group) |
| Scopes | `read_api` **only** |

`read_api` is the narrowest scope covering `GET /groups/:id/members/all`. `api` would add
unnecessary write access; `read_user` only reads the token owner's own profile.

Verify it, then store it — note the URL-encoded group path, and that `secrets/` is the KV v2
mount the `vault-backend` ClusterSecretStore points at:

```bash
curl -s -H "PRIVATE-TOKEN: <token>" \
  "https://gitlab.home.rottlr.de/api/v4/groups/idp%2Fteam-a/members/all" | jq -r '.[].username'

vault kv put secrets/idp/platform/observability/grafana-team-sync gitlab-token=<token>
```

## Operating it

Trigger a run without waiting for the schedule:

```bash
kubectl create job --from=cronjob/grafana-team-sync team-sync-manual -n grafana
kubectl logs -n grafana job/team-sync-manual
```

**`X is in the GitLab group for Y but has never signed in to Grafana; skipping`** is
expected, not a fault. Grafana creates a user record on first OAuth login, so a member who
has never opened Grafana does not exist yet to be added to a team. They are picked up
automatically on a later run.

If that warning appears for someone who *has* signed in, the likely cause is a mismatch
between the GitLab username and the `login` Grafana stored for them at first sign-in.

## Porting this elsewhere

`files/sync.py` is standard library only and talks to two HTTP APIs. Moving it to a
different Grafana OSS instance means changing the discovery source (`discover_teams`) and
the membership source (`gitlab_members`); the Grafana half is unchanged.
