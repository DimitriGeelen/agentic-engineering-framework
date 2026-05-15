---
id: T-1834
name: "Purge MS_OAUTH client secret from framework git history — filter-repo commit 79e3361 (T-1828 follow-up, Tier 0)"
description: >
  Follow-up to T-1828 mirror-unstick. Secret (Azure AD OAuth client secret originally from 050-email-archive .env) is embedded in framework git history at commit 79e3361 (T-1736: Spike B), file .context/spikes/T-1736-prompts.jsonl line 1581. The file was removed from HEAD in commit 7fba568e7 but remains in history. GitHub secret-scanning blocks push of any commit range containing 79e3361. Plan: git filter-repo --invert-paths --path .context/spikes/T-1736-prompts.jsonl, then force-push to BOTH OneDev (origin) and GitHub. Tier 0 — requires explicit human approval before history rewrite. All framework consumers must re-clone or hard-reset after force-push. Sequence with: (a) verify MS_OAUTH_CLIENT_SECRET rotated in 050-email-archive Azure app first (b) snapshot current refs to .git/refs-backup (c) filter-repo (d) force-push origin (e) force-push github (f) notify consumers via framework:pickup. Blocks T-1828 closure.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bug, fw-upgrade-incident-2026-05-14, security, tier0, git-history, follow-up]
components: []
related_tasks: []
created: 2026-05-14T20:42:14Z
last_update: 2026-05-15T07:38:02Z
date_finished: null
---

# T-1834: Purge MS_OAUTH client secret from framework git history — filter-repo commit 79e3361 (T-1828 follow-up, Tier 0)

## Context

MS_OAUTH client secret (Azure AD app from `050-email-archive` `.env`) was inlined in a
session prompt during T-1736 Spike B. The spike harvester captured that prompt verbatim
into `.context/spikes/T-1736-prompts.jsonl` and the file was committed at `79e3361d`
on 2026-05-05. The file was deleted from HEAD by `7fba568e7` (T-1828) but the blob
persists in history. GitHub's server-side secret scanner (GH013) has rejected every
push since — this is the actual cause of the mirror stall that T-1828 first attributed
to the T-1603 hook.

T-1844 (shipped 2026-05-15) is the prevention layer; this task is the **historical purge**.

## Acceptance Criteria

### Agent
- [ ] [P1] Working tree committed or stashed (filter-repo refuses dirty trees)
- [ ] [P1] Refs snapshot written to `.git/refs-backup-T-1834-<timestamp>`
- [ ] [P1] `git filter-repo --invert-paths --path .context/spikes/T-1736-prompts.jsonl --force` exits 0
- [ ] [P1] `git log --all -- .context/spikes/T-1736-prompts.jsonl` returns empty (file scrubbed from every commit)
- [ ] [P1] `agents/git/lib/secret-scan.sh scan-tree` returns 0 findings post-filter
- [ ] [P1] `origin` and `github` remotes re-added after filter-repo (it strips remotes by default)
- [ ] [P2] `git push --force-with-lease origin master` succeeds
- [ ] [P2] `git push --force-with-lease github master` succeeds (proves GH013 cleared)
- [ ] [P2] `.context/working/.mirror-sync.log` shows no `##PUSH-FAILED-STDERR remote=github` after the push
- [ ] [P3] Cross-repo purge prompt published at `docs/handouts/T-1834-cross-repo-purge-prompt.md`

### Human
- [ ] [PREREQUISITE] MS_OAUTH client secret rotated in Azure AD app registration for `050-email-archive`.
  **Steps:**
  1. Sign in to Azure Portal → App registrations → find the app for `050-email-archive`
  2. Certificates & secrets → revoke the leaked client secret → generate a new one
  3. Update `050-email-archive/.env` (and any pipeline secret store) with the new value
  4. Confirm with the email-archive smoke test
  **Expected:** Email-archive flow works with new secret; old secret returns 401.
  **If not:** STOP. History rewrite without rotation is theatre — anyone who pulled before today still has the live secret.
- [ ] [REVIEW] Tier 0 approval to rewrite framework git history and force-push to both remotes.
  **Steps:**
  1. Read the **Plan** section below
  2. Confirm rotation prerequisite is done
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw tier0 approve`
  4. Reply "go" in chat
  **Expected:** `.context/working/.tier0-approval` exists. Agent then executes plan steps 3-8.
  **If not:** Task stays in `started-work`; no destructive action taken.
- [ ] [REVIEW] Cross-repo prompt at `docs/handouts/T-1834-cross-repo-purge-prompt.md` is clear, safe, and ready to dispatch to other framework clones.

## Verification

# History purged
test -z "$(git log --all --pretty=format:%H -- .context/spikes/T-1736-prompts.jsonl)"
# Scan-tree clean
agents/git/lib/secret-scan.sh scan-tree
# Mirror healthy — most recent github line is not a failure
! tail -50 .context/working/.mirror-sync.log | grep -q '##PUSH-FAILED-STDERR remote=github'

## RCA

**Symptom:** GitHub mirror has been blocked since 2026-05-05. T-1828's first RCA blamed
the T-1603 VERSION-monotonicity hook (tag-counter-reset). After T-1843 shipped stderr
capture, the actual GH013 secret-protection error surfaced within 60s of the next sync.

**Root cause:** Two-layer failure.
1. **Content path:** MS_OAUTH client secret was inlined verbatim in a session prompt
   under T-1736 Spike B. The harvester script read that JSONL and copied the prompt
   into the spike corpus; the corpus was committed.
2. **Boundary path:** The harvester read session JSONLs from outside `PROJECT_ROOT`
   (`~/.claude/projects/.../*.jsonl`) — a path-isolation violation. This is the shape
   that Layer 3 RCA T-1833 (inception) addresses.

**Why structurally allowed:**
- No pre-commit secret scan existed (now shipped by T-1844)
- Spike harvesters had no sandbox or path-isolation guard (T-1833 proposed inception)
- No content-redaction step between session-harvest and corpus-commit

**Prevention:**
- **Layer 1 (commit gate):** T-1844 pre-commit secret scan — 11-pattern catalogue catches this class at commit time
- **Layer 2 (harvest sandbox):** T-1833 inception — path-isolation in spike harvesters
- **Layer 3 (mirror observability):** T-1843 stderr capture — surfaces server-side rejections in <60s
- **Layer 4 (paging):** not yet filed — mirror-failure threshold alerting

## Evolution

### 2026-05-15 — RCA correction via T-1843 stderr capture

- **What changed:** T-1828's initial RCA blamed T-1603 hook (tag-counter-reset). T-1843's
  stderr-capture fix surfaced the real cause within minutes of the next sync: GH013 secret
  protection rejecting the commit range containing `79e3361d`.
- **Plan impact:** T-1828's proposed `--no-verify` push would NOT have unstuck the mirror —
  it bypasses the local hook, not GitHub's server-side scanner.
- **Triggered:** This task already existed but its priority shifted from "follow-up cleanup"
  to "critical path for T-1828 closure". T-1844 root-cause prevention shipped first; this
  is the historical hygiene that closes the live incident.

## Decisions

### 2026-05-15 — `filter-repo --invert-paths --path` (file purge), not line-level redaction

- **Chose:** Drop `.context/spikes/T-1736-prompts.jsonl` from every commit via
  `git filter-repo --invert-paths --path .context/spikes/T-1736-prompts.jsonl`.
- **Why:** The file was a transient spike corpus already deleted from HEAD. File-level
  removal is the cleanest filter-repo invocation and leaves no diff context referencing
  the redacted bytes.
- **Rejected:**
  - `filter-repo --replace-text` — rewrites same SHAs but leaves placeholder lines that betray location. No safety gain.
  - BFG repo-cleaner — predecessor to filter-repo, less actively maintained.
  - Cherry-pick + rebase from before 79e3361d — every spike commit after that point would need manual replay; same blast radius, more failure modes.

### 2026-05-15 — Force-push both remotes, not just GitHub

- **Chose:** Force-push the rewritten history to OneDev (`origin`) AND GitHub (`github`) after Tier 0 approval.
- **Why:** Asymmetric purge leaves OneDev with the leak indefinitely. OneDev is internal-only but still a leak surface.
- **Rejected:** GitHub-only purge — preserves the leak on OneDev, defeats the point.

## Plan

Sequencing — each step is a hard prerequisite for the next.

1. **Rotation (HUMAN)** — rotate MS_OAUTH client secret in Azure AD app for 050-email-archive. Without this, history rewrite is theatre.
2. **Tier 0 approval (HUMAN)** — `cd /opt/999-Agentic-Engineering-Framework && bin/fw tier0 approve`, then reply "go".
3. **Snapshot + clean tree (AGENT)** — `git for-each-ref ... > .git/refs-backup-T-1834-<ts>`; commit or stash the 60+ uncommitted files (mostly cron byproducts).
4. **Execute filter-repo (AGENT)** — `git filter-repo --invert-paths --path .context/spikes/T-1736-prompts.jsonl --force`.
5. **Re-add remotes + verify (AGENT)** — restore `origin` and `github`; confirm `git log --all -- .context/spikes/T-1736-prompts.jsonl` empty + scan-tree clean.
6. **Force-push origin (AGENT, Tier 0)** — `git push --force-with-lease origin master --tags`.
7. **Force-push github (AGENT, Tier 0)** — `git push --force-with-lease github master --tags`. Expect GH013 to clear; this closes T-1828.
8. **Notify consumers (AGENT)** — publish `docs/handouts/T-1834-cross-repo-purge-prompt.md`; queue framework:pickup envelope for known clones.

## Recommendation

**GO** — pending HUMAN rotation + Tier 0 approval.

**Rationale:** The leak has been live in OneDev for 10 days; the mirror has been blocked
for 10 days. T-1844 prevents recurrence at commit-time; this task closes the live incident.

**Evidence:**
- T-1843 stderr capture confirmed GH013 as the actual mirror cause
- `agents/git/lib/secret-scan.sh scan-tree` on current HEAD returns 0 findings (T-1844 verified)
- `git log --all -- .context/spikes/T-1736-prompts.jsonl` returns exactly 2 commits — purge target is precise
- `/usr/bin/git-filter-repo` installed and tested

## Updates

### 2026-05-14T20:42:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1834-purge-msoauth-client-secret-from-framewo.md
- **Context:** Initial task creation

### 2026-05-15T07:38:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
