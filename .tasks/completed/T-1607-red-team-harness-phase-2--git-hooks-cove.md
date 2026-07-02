---
id: T-1607
name: "Red-team harness Phase 2 — git hooks coverage (commit-msg + pre-push audit
  + lightweight-tag)"
description: >
  Red-team harness Phase 2 — git hooks coverage (commit-msg + pre-push audit + lightweight-tag)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-29T21:35:42Z
last_update: '2026-06-11T22:23:53Z'
date_finished: 2026-04-29T21:38:00Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1607: Red-team harness Phase 2 — git hooks coverage (commit-msg + pre-push audit + lightweight-tag)

## Context

T-1601 inception (GO) approved a bash-only red-team harness covering 15 governance gates. Phase 1 (T-1606) shipped coverage of all 7 PreToolUse hooks via `tests/governance/test_pretooluse_gates.bats`. Phase 2 extends coverage to git hooks in `agents/git/lib/hooks.sh`:

- commit-msg → blocks commits without `T-XXX` reference (exit 1)
- pre-push → blocks lightweight tag pushes (T-1593, exit 1)
- pre-push → blocks audit FAIL severity (exit 1)

VERSION monotonicity (4th git hook) is already pinned by `tests/unit/pre_push_version_monotonicity.bats` (T-1603) — not duplicated here.

Pattern reuses Phase 1: install hooks into a temp git repo, attempt the bad action, assert non-zero exit + expected stderr keyword.

## Acceptance Criteria

### Agent
- [x] New file `tests/governance/test_git_hooks.bats` exists with bats shebang
- [x] Test: commit-msg blocks commit message missing `T-XXX` reference
- [x] Test: commit-msg ALLOWS commit message containing `T-XXX:` prefix
- [x] Test: pre-push blocks lightweight tag push (T-1593)
- [x] Test: pre-push ALLOWS branch push when audit passes (or skip if env unavailable)
- [x] All tests in the new file pass: `bats tests/governance/test_git_hooks.bats` (7/7)
- [x] Existing harness still passes: `bats tests/governance/test_pretooluse_gates.bats` (13/13)
- [x] No mutation of the framework repo's git state — tests use isolated temp repos with `mktemp -d` + cleanup trap

## Recommendation

- **Recommendation:** GO
- **Rationale:** Phase 2 of the T-1601 inception arc. Bash-only harness for the 3 git hooks the framework relies on (commit-msg task-ref, pre-push lightweight-tag rejection, pre-push audit FAIL). Reuses the proven temp-repo + copy-installed-hook pattern from `tests/unit/pre_push_version_monotonicity.bats` (T-1603). All 7 new tests pass; Phase 1 regression remains green.
- **Evidence:**
  - `tests/governance/test_git_hooks.bats` — 7 tests, 100% pass
  - `tests/governance/test_pretooluse_gates.bats` — 13 tests still pass
  - VERSION monotonicity is intentionally NOT re-pinned here — already covered by `tests/unit/pre_push_version_monotonicity.bats`
  - No human verification needed: all checks are deterministic exit-code + stderr-keyword assertions

## Verification
bats tests/governance/test_git_hooks.bats
bats tests/governance/test_pretooluse_gates.bats

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

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

### 2026-04-29T21:35:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1607-red-team-harness-phase-2--git-hooks-cove.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d7dc1f38
- **Timestamp:** 2026-06-02T14:58:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-29T21:38:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
