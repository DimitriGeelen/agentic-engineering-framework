---
id: T-1828
name: "github mirror stalled — VERSION tag-reset trips T-1603 hook, blocks fix-shipped
  commits from reaching GitHub consumers"
description: >
  GitHub mirror at 9d52cee27 (T-1725, 2026-05-04), 294 commits behind origin. Auto-recover
  cron (T-1594) push-failing every 15 min for hours. Root cause: VERSION stamping
  via `git describe` counter resets at each new tag — v1.6.2 created after last GitHub
  push, dropped stamped VERSION from 1.6.260 to 1.6.148. T-1603 pre-push hook (correctly
  per spec) blocks as monotonicity violation. fix-shipped commits for T-1822/T-1823/T-1824/T-1825/T-1634
  cannot reach GitHub-cloning consumers; /opt/termlink reports they cannot `fw upgrade`
  to pick up cwd-trap fix.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bug, fw-upgrade-incident-2026-05-14, mirror, version-monotonicity]
components: [C-004, agents/git/lib/hooks.sh, agents/git/lib/secret-scan.sh, 
      bin/fw, lib/inception.sh, lib/mirror.sh, lib/upgrade.sh, 
      tests/unit/test_doctor_consumer_version_ahead.bats, 
      tests/unit/test_mirror_stderr_capture.bats, 
      tests/unit/test_pre_push_monotonic_ancestor.bats, 
      tests/unit/test_secret_scan.bats, 
      tests/unit/test_upgrade_downgrade_guard.bats, 
      web/templates/prompt_detail.html]
related_tasks: [T-1542, T-1594, T-1602, T-1603, T-1822, T-1823, T-1824, T-1825, 
      T-1634, T-1826, T-1827, T-1833, T-1834]
created: 2026-05-14T18:22:32Z
last_update: '2026-08-16T22:24:45Z'
date_finished: 2026-05-15T20:19:25Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 4
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 1
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=2 (body:telemetry-or-audit-entry); 
      D3=4 (body:framework-level-ux); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=1 (body/components:prompt-incidental); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 4
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 1
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=2 (body:telemetry-or-audit-entry); 
      D3=4 (body:framework-level-ux); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=1 (body/components:prompt-incidental); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1828: github mirror stalled — VERSION tag-reset trips T-1603 hook, blocks fix-shipped commits from reaching GitHub consumers

## Context

OPS-2 from the fw-upgrade-incident-2026-05-14 cluster. Sibling to T-1826 (OPS-1 inbound relay stall) and T-1827 (pickup follow-up). termlink-agent reported (framework:pickup offset 12, HIGH severity) that the GitHub mirror is 10 days stale at commit `9d52cee27`. Consumer at /opt/termlink cannot pick up the cwd-trap fix (T-1822) because their re-vendor source — GitHub — is missing the shipped commit `508783801` and 293 others.

The mirror sync cron (T-1594, every 15 min) IS running. The push is being **structurally refused** by the T-1603 pre-push hook because local `VERSION` (1.6.160) numerically compares lower than the GitHub-side `VERSION` (1.6.260).

## Acceptance Criteria

### Agent
- [x] Root cause documented (RCA section filled, including why tag-reset triggers it)
- [x] Bypass command pre-built as a copy-pasteable Tier-2 line for the human
- [x] Prevention task filed for Level-C fix (VERSION-stamping algorithm not subject to tag-reset rollback) — T-1829
- [x] L-entry written to project memory (Level-A lock-in for next agent who hits this) — L-376

### Human
- [x] [REVIEW] Approve the bypass push to unstick the mirror
  **Steps:**
  1. Read RCA + Recommendation below
  2. From this directory run: `cd /opt/999-Agentic-Engineering-Framework && git push --no-verify github master`
  3. Verify: `git ls-remote https://github.com/DimitriGeelen/agentic-engineering-framework.git HEAD` — should show `8158d577e3ebe77d560afb2e4361093765331bd1`
  4. Log the Tier-2 bypass to `.context/working/.gate-bypass-log.yaml` (agent will do post-push)

  **Expected:** GitHub HEAD = `8158d577e` (matches origin). Consumer at /opt/termlink can now `fw upgrade` and pick up T-1822 cwd-trap fix + 293 other commits.

  **If not:** the push failed for a different reason (auth, network) — share error and we diagnose.

## Verification

# Verify GitHub HEAD matches origin HEAD after bypass push.
git ls-remote https://github.com/DimitriGeelen/agentic-engineering-framework.git HEAD | grep -q "$(git rev-parse HEAD)"

## RCA

**Symptom:** Mirror sync (T-1594 cron, 15-min cadence) has been failing for hours. GitHub HEAD stuck at `9d52cee27` from 2026-05-04. Consumer `/opt/termlink` cannot pick up `T-1822` cwd-trap fix because their re-vendor source (GitHub) is missing the fix.

**Root cause:** VERSION stamping in `agents/git/lib/hooks.sh:533-551` uses `git describe --tags --match 'v[0-9]*' | awk` → emits `<major>.<minor>.<commits-since-tag>`. The commits-since-tag counter **resets to 0 at each new tag**. Locally, `v1.6.2` was created after the last successful GitHub push; HEAD is now `v1.6.2-148-...` → stamped `1.6.148`. GitHub still holds VERSION `1.6.260` from `v1.6.1-260-...` (the tip at the last successful push). 148 < 260 numerically — the T-1603 hook correctly identifies a rollback per its sort-V check, even though commit time is 10 days *newer*.

**Why structurally allowed:**
- T-1603 hook's monotonicity check operates on stamped-VERSION strings, not commit-time or commit-graph reachability. It cannot distinguish "rollback" (HEAD reset to older commit) from "stamping algorithm reset" (new tag mid-stream).
- VERSION-stamping algorithm trusts `git describe`'s counter to be monotonic, but counter is monotonic only within a single tag epoch. New tag → new epoch → counter restart.
- T-1602 (the origin of T-1603) was the legitimate-rollback class; the tag-reset class was not in scope at the time.
- The mirror cron writes `push-failed` to the log but does **not** surface stderr — the actual error message ("VERSION 1.6.160 < remote 1.6.260") is invisible to the audit-time check. `fw doctor` does not surface this either.

**Prevention:**
- **Level C (this task spawns):** change VERSION stamping algorithm to be cross-tag-monotonic. Options: (a) use `git rev-list --count HEAD` (total commits) instead of tag-counter, (b) include tag-name in version (`1.6.2.148` not `1.6.148`), (c) maintain stamp file in `.context/working/.version-counter` that only increases. See T-XXXX (filed below).
- **Level B (this task):** mirror sync wrapper logs stderr to the audit trail so the next stall is visible in <15 min, not after consumers report.
- **Level A (this task — L-entry):** "VERSION tag-reset rollback class — creating a new `v<M>.<m>.<p>` tag resets the patch-counter to 0, which the T-1603 hook reads as rollback; the legitimate workaround is bypass-push, not undo-the-tag."

## Evolution

<!-- Not arc-tagged — leave empty. -->

## Decisions

### 2026-05-14 — bypass mechanism

- **Chose:** `git push --no-verify github master` as one-shot bypass; file Level-C follow-up for algorithmic fix.
- **Why:** the 294-commit history cannot be rewritten (visible on origin/master and many consumer-vendored copies). Bumping VERSION past 1.6.260 with a synthetic commit would make THIS push work but doesn't fix the underlying class. `--no-verify` is what the T-1603 hook itself documents as the bypass path (line 50 of the hook).
- **Rejected:**
  - Delete `v1.6.2` tag — destructive on a published tag, breaks anything relying on the tag.
  - Force-push to GitHub — destructive on the 9d52cee27 history; consumers who already cloned would see history rewrite.
  - Synthetic VERSION bump commit — works for one push but masks the structural issue; the next tag will trigger the same stall.

## Updates

### 2026-05-14T18:22:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1828-github-mirror-stalled--version-tag-reset.md
- **Context:** Initial task creation; root cause identified before filing.

### 2026-05-15T20:16:00Z — Resolved: autonomous heal via T-1834 history purge

- **Status:** Mirror back in sync. `git ls-remote github HEAD` returns `7bac0aa5` matching local HEAD.
- **Resolution path:** T-1834 (history-purge of MS_OAUTH secret from commit `79e3361`) completed in commit `53293e76`. After history rewrite + force-push, GitHub push-protection no longer blocks. The T-1594 mirror sync cron then succeeded at 2026-05-15T19:30:05Z and has held green every 15min since (4 consecutive `synced` log entries: 19:30, 19:45, 20:00, 20:15).
- **Verification:** the AC's `git ls-remote ... | grep -q $(git rev-parse HEAD)` line returns PASS (also re-run capture-then-grep form to inoculate against L-387; passes).
- **State at close:** github HEAD = `7bac0aa5` = local HEAD; mirror-sync.log clean since the purge; T-1603 hook untouched (the bypass was historical, not permanent); Level-C follow-up T-1829 already filed for cross-tag-monotonic VERSION stamping.

### 2026-05-14T20:30:00Z — Layer 3 discovery: bypass push blocked by GitHub secret-scanning
- **Action:** Tier 0 approved bypass push attempted (`git push --no-verify github master`). Local pre-push hook passed (T-1603 bypass worked). **GitHub-side push-protection rejected** the push: a Microsoft Azure AD OAuth client secret is embedded in commit `79e3361` (T-1736 spike), file `.context/spikes/T-1736-prompts.jsonl` line 1581.
- **Root cause (Layer 3):** T-1736 spike (prompt-triage classifier) harvested Claude Code session JSONLs from outside PROJECT_ROOT (path-isolation violation per feedback_path_isolation_strict). One harvested session-summary entry contained a real (or once-real) OAuth client secret. Filed as **T-1833** (inception — path-isolation in spike-harvest tooling).
- **Mitigation:** removed offending file from HEAD via `git rm .context/spikes/T-1736-prompts.jsonl` → commit `7fba568e7`. Secret remains in history (commit 79e3361). Push still blocked until history rewrite.
- **Path to closure:** T-1834 (build, Tier 0) — `git filter-repo` to purge the file from history + force-push to OneDev + GitHub. Sequence after secret rotation verification in 050-email-archive's Azure AD app.
- **L-378 captured:** agent must never quote secret values verbatim in chat (recursive contamination via session JSONL).

## Recommendation

**Recommendation:** GO — approve the bypass push, file Level-C follow-up.

**Rationale:** the bypass path is what the T-1603 hook documents (line 50: `Bypass: git push --no-verify (Tier 0 protected, logged)`). The legitimate-rollback class T-1603 was built to catch (T-1602: HEAD reset to old commit) is structurally different from this class (tag-reset of stamping counter). The hook can stay; the bypass is correct policy for this incident; the Level-C follow-up will eliminate the recurrence.

**Evidence:**
- Mirror push-failed log shows 16+ consecutive failures since 13:30Z (`.context/working/.mirror-sync.log`)
- GitHub HEAD: `9d52cee27` (T-1725, 2026-05-04) — 294 commits behind origin
- Hook output captured: `"master: VERSION 1.6.160 < remote 1.6.260"`
- `git describe --tags --match 'v[0-9]*'` returns `v1.6.2-148-g8158d577e` locally, `v1.6.1-34-g9d52cee27` at github HEAD — confirms tag-reset cause
- T-1822 fix (cwd-trap, what /opt/termlink needs) is in commit `508783801` which is in the stuck 294-commit chain

### 2026-05-14T20:43:38Z — status-update [task-update-agent]
- **Change:** status: started-work → issues

## Reviewer Verdict (v1.5)

- **Scan ID:** R-08f464ac
- **Timestamp:** 2026-06-02T14:59:53Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `git ls-remote https://github.com/DimitriGeelen/agentic-engineering-framework.git HEAD | grep -q "$(git rev-parse HEAD)"`
### 2026-05-15T20:19:25Z — status-update [task-update-agent]
- **Change:** status: issues → work-completed
