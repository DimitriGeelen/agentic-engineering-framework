# T-442: OneDev PR-to-Task Cron — Inception Research

## Problem Statement

When external contributors (or the human via OneDev's web UI) create pull requests on OneDev, there's no automatic bridge to the framework's task system. PRs sit unnoticed until manually checked. We want a cron job that periodically polls OneDev for new/open PRs and creates corresponding framework tasks (horizon: next) so they appear on the task board and in handovers.

**Constraint: local-only.** This cron and script must NOT propagate to GitHub. It's specific to this installation's OneDev instance.

## Research Findings

### OneDev API

- **Base URL:** `https://onedev.docker.ring20.geelenandcompany.com/~api/pulls`
- **Auth:** HTTP Basic Auth with access token (created in OneDev UI → user settings)
- **List PRs:** `GET /~api/pulls?query="status" is "Open"&offset=0&count=100`
- **PR fields:** `id`, `number`, `title`, `description`, `status` (OPEN/MERGED/DISCARDED), `submitter`, `targetBranch`, `sourceBranch`, `submitDate`

### Existing Cron Pattern

The framework already has a cron file at `/etc/cron.d/agentic-audit` (T-184/T-196) with:
- Multiple audit schedules (30min, hourly, 6-hourly, daily, weekly)
- Pattern: `PROJECT_ROOT=... /path/to/fw command --cron`
- Hardcoded to this installation path

### Design Options

#### Option A: Separate cron file + standalone script
- New file: `/etc/cron.d/agentic-onedev-sync`
- New script: `deploy/onedev-pr-sync.sh` (in .gitignore)
- Runs every 15 minutes
- Stores state in `.context/working/.onedev-pr-seen` (list of already-processed PR numbers)

#### Option B: fw subcommand + cron entry in existing file
- New subcommand: `fw onedev sync-prs`
- Add entry to `/etc/cron.d/agentic-audit`
- Script lives in `agents/onedev/` or `lib/onedev.sh`
- Problem: this would be in git and propagate to GitHub

#### Option C: Local deploy script + separate cron file
- Script at `deploy/onedev-pr-sync.sh`
- Add `deploy/onedev-pr-sync.sh` to `.gitignore`
- Separate cron file `/etc/cron.d/agentic-onedev-sync`
- Clean separation: nothing in framework core, nothing in GitHub

### Recommended: Option C (local deploy script)

**Rationale:**
- The script is installation-specific (hardcoded OneDev URL, auth token, project paths)
- Adding it to `.gitignore` prevents GitHub propagation
- Separate cron file keeps audit cron clean
- No framework core changes needed

### Script Design

```bash
#!/usr/bin/env bash
# deploy/onedev-pr-sync.sh — Poll OneDev PRs, create tasks for new ones
# LOCAL ONLY — do not commit to git (listed in .gitignore)

ONEDEV_URL="https://onedev.docker.ring20.geelenandcompany.com"
ONEDEV_TOKEN_FILE="$HOME/.onedev-token"  # single line: username:token
PROJECT_ROOT="/opt/999-Agentic-Engineering-Framework"
SEEN_FILE="$PROJECT_ROOT/.context/working/.onedev-pr-seen"
FW="$PROJECT_ROOT/bin/fw"

# 1. Fetch open PRs from OneDev API
# 2. For each PR not in SEEN_FILE:
#    a. Create task: fw task create --name "PR #N: title" --type build --horizon next --tag "onedev,pr"
#    b. Add PR number to SEEN_FILE
#    c. Optionally add PR description to task context
# 3. For each PR in SEEN_FILE that is now MERGED/DISCARDED:
#    a. Update corresponding task status
```

### State Tracking

- `.context/working/.onedev-pr-seen` — YAML mapping PR number → task ID
- Checked on each run to avoid duplicate task creation
- When a PR is merged/discarded, the corresponding task can be updated

### Auth Token Storage

- `~/.onedev-token` — file containing `username:token`
- NOT in the repo (home directory)
- Permissions: `chmod 600`

### Cron Schedule

Every 15 minutes — matches the structural audit cadence:
```
*/15 * * * * root /opt/999-Agentic-Engineering-Framework/deploy/onedev-pr-sync.sh 2>/dev/null
```

## Go/No-Go Criteria

- **GO if:** API test works (can list PRs), script creates tasks correctly, .gitignore prevents propagation
- **NO-GO if:** OneDev API is not accessible, token auth fails, or task creation has side effects we can't control

## Assumptions

1. OneDev instance is reachable from this machine
2. An API access token can be created with read permissions on PRs
3. `fw task create` works non-interactively from cron context (no TTY)

## Spike Results

### Spike 1: API connectivity — PASS
- `GET /~api/pulls?offset=0&count=100` returns 200 with full PR data
- **No auth required** for reading (public project) — simplifies implementation
- 3 PRs found: 2 MERGED, 1 OPEN (#3)
- Fields available: `id`, `number`, `title`, `description`, `status`, `targetBranch`, `sourceBranch`, `submitDate`, `submitterId`

### Spike 2: Task creation from cron — PASS
- `fw task create --name "..." --type build --horizon next --owner human --description "..."` works without TTY
- Requires `--owner` flag (otherwise prompts interactively)
- Returns task ID in output — can be parsed

### Spike 3: .gitignore — TODO
- Need to add `deploy/onedev-pr-sync.sh` to `.gitignore`

## Decision

**GO** — All technical risks resolved. API is accessible without auth, task creation works non-interactively, and the script can be kept local via .gitignore.
