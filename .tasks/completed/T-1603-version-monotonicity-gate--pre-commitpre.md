---
id: T-1603
name: "VERSION monotonicity gate — pre-commit/pre-push hook refusing decreasing VERSION
  (T-1602 follow-up)"
description: >
  Pre-commit hook (or pre-push) that refuses any commit decreasing VERSION. Trigger:
  T-1602 surfaced framework VERSION rollback 1.5.463 → 1.5.19 in cc38e98f5 (T-1540
  iter1) — silent side-effect of a git checkout against stale ref. No structural gate
  caught it. 12 consumers paid the cost (pinned 1.5.307, ahead of HEAD for 4 days).
  Fix: hook reads HEAD VERSION + working-tree VERSION, refuses if working VERSION
  semver-lower than HEAD. Bypass via Tier 2 (--no-verify with logged reason). Highest
  leverage of the T-1602 SUMMARY recommendations.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-29T08:05:09Z
last_update: '2026-06-11T22:23:53Z'
date_finished: 2026-04-29T18:29:24Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1603: VERSION monotonicity gate — pre-commit/pre-push hook refusing decreasing VERSION (T-1602 follow-up)

## Context

T-1602 surfaced a silent VERSION rollback in commit cc38e98f5 (T-1540 iter1): VERSION dropped from 1.5.463 to 1.5.19 (~440 patch versions) as a side-effect of a `git checkout` against a stale ref. 12 consumers paid the cost (pinned 1.5.307, ahead of HEAD for 4 days). No structural gate caught it. Fix: pre-push hook compares each pushed ref's local VERSION against the existing remote VERSION; refuses if local is semver-lower. Pre-push (not pre-commit) — failure mode is the bad VERSION reaching shared state, not the local commit; pre-push runs once per push.

## Acceptance Criteria

### Agent
- [x] `agents/git/lib/hooks.sh` pre-push hook adds a VERSION monotonicity check BEFORE the audit section: for each pushed ref, compares `git show $local_sha:VERSION` against the remote VERSION (`git show $remote_sha:VERSION` if known); blocks push if local is semver-lower than remote
- [x] Pre-push hook VERSION marker bumped (1.2 → 1.3) AND commit-msg VERSION marker bumped (1.7 → 1.8) so `fw git install-hooks` redeploys the new pre-push to consumers
- [x] Hooks reinstalled locally via `bin/fw git install-hooks --force`; `.git/hooks/pre-push` contains the new check
- [x] Unit test `tests/unit/pre_push_version_monotonicity.bats` covers: (a) higher VERSION passes, (b) equal VERSION passes, (c) lower VERSION blocks with non-zero exit, plus cc38e98f5 incident-shape pin and tag-push pass-through
- [x] Hook plumbing tests still pass: `bats tests/unit/pre_push_version_monotonicity.bats tests/unit/hook_dispatcher.bats tests/unit/hook_absolute_paths.bats` → 15/15 OK

## Verification

bats tests/unit/pre_push_version_monotonicity.bats
grep -q "VERSION monotonicity" .git/hooks/pre-push

## RCA

**Symptom:** Framework `VERSION` was rolled back ~440 patch versions on 2026-04-27 (1.5.463 → 1.5.19) as a silent side-effect of commit cc38e98f5 (T-1540 iter1). 12 governed consumers ended up pinned ahead of HEAD for 4 days.

**Root cause:** No structural gate validated VERSION monotonicity. The hook stack (commit-msg, post-commit, pre-push) had no check on the VERSION file's value relative to its prior state. A `git checkout` against a stale ref silently overwrote VERSION, and no gate fired.

**Why structurally allowed:** VERSION is a single-line text file with no "monotonic non-decrease" invariant declared anywhere. The pre-push audit checks structure (YAML parses, dirs exist) but not semantic invariants on individual files.

**Prevention:** Pre-push hook now compares `git show $local_sha:VERSION` against the remote tip's VERSION; if local sorts before remote under `sort -V`, the push is blocked. Bypass via `--no-verify` (Tier 0 protected, logged). Unit tests pin: higher passes, equal passes, lower blocks, the cc38e98f5 shape blocks, tag-only pushes pass through.

## Recommendation

**Recommendation:** GO
**Rationale:** The cc38e98f5 incident shape is now blocked structurally. Tests pin all five behaviors. Hook redeployment to consumers is wired (commit-msg + pre-push markers both bumped — consumers' next `fw git install-hooks` redeploys both).
**Evidence:**
- `bats tests/unit/pre_push_version_monotonicity.bats` → 6/6 pass
- `bats tests/unit/hook_dispatcher.bats tests/unit/hook_absolute_paths.bats` → 9/9 pass (no regression)
- `grep -q "VERSION monotonicity" .git/hooks/pre-push` → present locally
- Test `pre-push BLOCKS the cc38e98f5 case (1.5.463 → 1.5.19)` directly pins the original incident

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-29T08:05:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1603-version-monotonicity-gate--pre-commitpre.md
- **Context:** Initial task creation

### 2026-04-29T08:05:42Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-29T18:22:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6702e3f3
- **Timestamp:** 2026-06-02T14:58:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-29T18:29:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
