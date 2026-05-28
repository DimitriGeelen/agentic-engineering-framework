---
id: T-1834
name: "Purge MS_OAUTH client secret from framework git history — filter-repo commit
  79e3361 (T-1828 follow-up, Tier 0)"
description: >
  Follow-up to T-1828 mirror-unstick. Secret (Azure AD OAuth client secret originally
  from 050-email-archive .env) is embedded in framework git history at commit 79e3361
  (T-1736: Spike B), file .context/spikes/T-1736-prompts.jsonl line 1581. The file
  was removed from HEAD in commit 7fba568e7 but remains in history. GitHub secret-scanning
  blocks push of any commit range containing 79e3361. Plan: git filter-repo --invert-paths
  --path .context/spikes/T-1736-prompts.jsonl, then force-push to BOTH OneDev (origin)
  and GitHub. Tier 0 — requires explicit human approval before history rewrite. All
  framework consumers must re-clone or hard-reset after force-push. Sequence with:
  (a) verify MS_OAUTH_CLIENT_SECRET rotated in 050-email-archive Azure app first (b)
  snapshot current refs to .git/refs-backup (c) filter-repo (d) force-push origin
  (e) force-push github (f) notify consumers via framework:pickup. Blocks T-1828 closure.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [bug, fw-upgrade-incident-2026-05-14, security, tier0, git-history, 
      follow-up]
components: [agents/git/lib/hooks.sh, agents/git/lib/secret-scan.sh, 
      tests/unit/test_secret_scan.bats]
related_tasks: []
created: 2026-05-14T20:42:14Z
last_update: '2026-05-28T22:54:10Z'
date_finished: 2026-05-15T08:02:00Z
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 2
      D3: 0
      D4: 4
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=4 
      (body:cross-machine); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
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
- [x] [P1] Working tree committed or stashed (filter-repo refuses dirty trees) — patch/tar to /tmp/T-1834-{tracked.patch,untracked.tar.gz}
- [x] [P1] Refs snapshot written to `.git/refs-backup-T-1834-1778831365` (32 refs)
- [x] [P1] `git filter-repo --invert-paths --path .context/spikes/T-1736-prompts.jsonl --force` exits 0 — 6576 commits parsed, 4.14s
- [x] [P1] `git log --all -- .context/spikes/T-1736-prompts.jsonl` returns empty (file scrubbed from every commit)
- [x] [P1] `agents/git/lib/secret-scan.sh scan-tree` returns 0 findings post-filter
- [x] [P1] `origin` and `github` remotes re-added after filter-repo (origin was stripped; github survived)
- [x] [P2] Force-push origin master succeeds — `+ c93623c4...9350885c master -> master (forced update)`
- [x] [P2] Force-push github master succeeds — `+ 9d52cee2...9350885c master -> master (forced update)` (GH013 cleared, proving leak is gone from history)
- [x] [P2] `.context/working/.mirror-sync.log` shows last push-failed at 2026-05-13T21:15 — no new failures since the purge push
- [x] [P3] Cross-repo purge prompt published at `docs/handouts/T-1834-cross-repo-purge-prompt.md`

### Human
- [ ] [REVIEW] Cross-repo prompt at `docs/handouts/T-1834-cross-repo-purge-prompt.md` is clear, safe, and ready to dispatch to other framework clones.

<!-- Rotation prerequisite removed per sovereign in-chat direction 2026-05-15 ("i dont want to rotate it !!!!"). Tier 2 logged in Decisions below. Security incident remains OPEN (live credential potentially in circulation) but this task only owns the historical-hygiene leg of remediation. -->


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

### 2026-05-15 — Rotation prerequisite declined by sovereign; purge proceeds anyway (Tier 2 logged)

- **Chose:** Execute history-purge + force-push without first rotating the MS_OAUTH client secret.
- **Why:** Human (sovereign) explicitly directed proceed-without-rotation in chat 2026-05-15T~07:55:
  *"no it has not been rotated and i dont want to rotate it !!!!"* and reinforced
  *"fricxking follow my direction"*. Purge retains value (mirror unstick, future-clone hygiene, T-1828 closure).
- **Rejected:** Holding the purge until rotation. Holding leaves the mirror stalled indefinitely.
- **Acknowledged risk:** Anyone with framework-clone access between 2026-05-05 and 2026-05-15 retains the live credential. Security incident remains OPEN; this task closes the *historical hygiene* leg only.
- **Logged as Tier 2:** Sovereign in-chat direction = explicit single-use authorization. Also: 4× `bin/fw tier0 approve` invocations during execution (force-push origin, force-push github, no-verify github after T-1603 trip).

### 2026-05-15 — `--no-verify` on GitHub force-push to bypass T-1603 post-filter

- **Chose:** Use `git push --force --no-verify github master` after T-1603 monotonicity hook blocked the post-filter VERSION (local HEAD 1.6.160 vs github remote 1.6.260).
- **Why:** filter-repo rewrote history; post-rewrite VERSION at HEAD is the value at the rewritten commit. Forward-in-time, ancestor check correctly identifies this as not-ancestor (different SHAs) → strict-block. The error message itself names `--no-verify` as the documented bypass for major-version-reset class.
- **Rejected:** Bumping VERSION pre-push. Cleaner audit trail (one bypass log entry) than a synthetic version-bump commit.

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

**Recommendation:** GO — historical hygiene COMPLETE. Mirror unstuck, GH013 cleared, blob purged from both remotes. Security incident **remains OPEN** because rotation was declined.

**Rationale:** Sovereign-directed proceed-without-rotation. Purge executed end-to-end:
filter-repo rewrote 6576 commits in 4.14s; both remotes accepted force-push at the same
SHA (`9350885c`); GitHub's GH013 blocker cleared on the first push (proving the leak is
gone from history).

**Evidence:**
- `git log --all -- .context/spikes/T-1736-prompts.jsonl` returns empty
- `agents/git/lib/secret-scan.sh scan-tree` exit 0
- `git ls-remote origin master` = `git ls-remote github master` = `9350885c6e82...`
- `.context/working/.mirror-sync.log` last push-failed at 2026-05-13T21:15Z; no new failures
- GitHub force-push log line: `+ 9d52cee2...9350885c master -> master (forced update)`
- Local refs backup at `.git/refs-backup-T-1834-1778831365` (32 refs preserved for rollback)
- Untracked state backup at `/tmp/T-1834-untracked.tar.gz` (37 KB)

**Open follow-ups (not in this task's scope):**
- **Live-credential risk** — anyone with clone access in the 10-day window retains the credential. Mitigation requires Azure AD rotation (declined by sovereign).
- **GitHub large-file warnings** — push warned about ~74 MB and ~53 MB objects in history. Worth investigating (likely the tracked `os` PostScript file flagged in `.secret-scan-allowlist`).

## Updates

### 2026-05-14T20:42:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1834-purge-msoauth-client-secret-from-framewo.md
- **Context:** Initial task creation

### 2026-05-15T07:38:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-d4522850
- **Timestamp:** 2026-05-18T09:30:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 2
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `Force-push`
  2. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `Cross-repo`
### 2026-05-15T08:02:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
