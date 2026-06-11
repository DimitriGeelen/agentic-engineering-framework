---
id: T-1608
name: "Red-team harness Phase 3 — task-lifecycle gates (P-010, P-011, RCA, inception-decide
  CLAUDECODE)"
description: >
  Red-team harness Phase 3 — task-lifecycle gates (P-010, P-011, RCA, inception-decide
  CLAUDECODE)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-29T21:39:09Z
last_update: '2026-06-11T22:23:53Z'
date_finished: 2026-04-29T21:43:02Z
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

# T-1608: Red-team harness Phase 3 — task-lifecycle gates (P-010, P-011, RCA, inception-decide CLAUDECODE)

## Context

T-1601 inception (GO) Phase 3 — final phase of the bash-only red-team harness. Phase 1 (T-1606) covered 7 PreToolUse hooks. Phase 2 (T-1607) covered 3 git hooks. Phase 3 covers 4 task-lifecycle gates in `agents/task-create/update-task.sh` + `lib/inception.sh`:

- **P-010** unchecked AC gate (Agent ACs unchecked → block `--status work-completed`)
- **P-011** verification gate (failing `## Verification` command → block)
- **RCA gate** (T-1550) — bug-class task with empty `## RCA` → block
- **inception-decide CLAUDECODE gate** (T-1259) — refuses when `$CLAUDECODE=1` without `--i-am-human`

Pattern: synthetic task file in `.tasks/active/T-99XX-...md`, invoke `update-task.sh` (or `bin/fw inception decide`), assert non-zero exit + expected stderr keyword, teardown removes file from both `active/` and `completed/`.

Block-only coverage — allow paths trigger irreversible side effects (move to completed/, episodic generation). Block paths are what governance regression detection needs to pin.

## Acceptance Criteria

### Agent
- [x] New file `tests/governance/test_task_lifecycle_gates.bats` with bats shebang
- [x] Test: P-010 blocks `--status work-completed` when Agent ACs are unchecked
- [x] Test: P-011 blocks `--status work-completed` when a `## Verification` command fails
- [x] Test: RCA gate (T-1550) blocks bug-class task with empty `## RCA`
- [x] Test: inception-decide refuses with `CLAUDECODE=1` set (T-1259)
- [x] Test: inception-decide ALLOWS with `--i-am-human` even when `CLAUDECODE=1`
- [x] All tests pass: `bats tests/governance/test_task_lifecycle_gates.bats` (5/5)
- [x] Phase 1 + 2 still pass: combined run shows 25/25 across all 3 phases
- [x] Teardown removes synthetic task files from both active/ and completed/ — verified clean

## Recommendation

- **Recommendation:** GO
- **Rationale:** Closes the T-1601 inception arc — bash-only red-team harness now covers all 14 governance gates from the original 15-gate inventory (the 15th, VERSION monotonicity, was already pinned by T-1603 in `tests/unit/`). Phase 3 covers the 4 task-lifecycle gates: P-010 (unchecked AC), P-011 (verification), RCA (T-1550), and inception-decide CLAUDECODE (T-1259). All BLOCK paths verified; ALLOW paths intentionally not tested (they have irreversible side effects and are exercised by normal framework use).
- **Evidence:**
  - `tests/governance/test_task_lifecycle_gates.bats` — 5 tests, 5/5 pass
  - Combined: `bats tests/governance/{test_pretooluse_gates,test_git_hooks,test_task_lifecycle_gates}.bats` → 25/25 pass
  - Residue check: `T-99XX` synthetic fixtures cleaned from active/, completed/, episodic/
  - Total governance coverage now: 7 PreToolUse + 3 git hooks + 4 task-lifecycle + 1 VERSION (T-1603) = 15 gates pinned

## Verification
bats tests/governance/test_task_lifecycle_gates.bats
bats tests/governance/test_pretooluse_gates.bats
bats tests/governance/test_git_hooks.bats
test -z "$(ls .tasks/active/ | grep -E 'T-99[0-9][0-9]' || true)"
test -z "$(ls .tasks/completed/ | grep -E 'T-99[0-9][0-9]' || true)"

## RCA

**Symptom:** Governance gates were not being systematically tested for negative cases. T-1597 sweep showed extensive evidence of gates working in normal flow, but no test that fires each gate with known-bad input and verifies the block. A silent regression — a hook returning exit 0 when it should return 2 — would only surface when a real incident exposed it.

**Root cause:** The framework's 15 enforcement gates (7 PreToolUse + 3 git hooks + 4 task-lifecycle + 1 VERSION) had no red-team harness. Existing tests verified happy-path behavior; no inverse-test asserted that bad inputs are rejected with the expected exit code and message.

**Why structurally allowed:** The framework grew organically — each gate was added with focused unit tests for its own logic, but no umbrella suite cross-checked them as a class. The 15-gate inventory was implicit, scattered across hook scripts, lib functions, and documentation — never enumerated in one place until T-1601 inception ran the spike.

**Prevention:** Three governance-tier red-team test files now pin every gate (T-1606 PreToolUse, T-1607 git hooks, T-1608 task-lifecycle). VERSION monotonicity already pinned by T-1603. Combined: `bats tests/governance/*.bats` runs 25 tests; if any gate is silently weakened, the corresponding test fails. Note: this RCA was triggered as a false-positive (the gate matched the literal word "RCA" in this build task's title), which itself is a known limitation worth flagging — the bug-class detector relies on keyword matching, so meta-tasks about the gate get caught. Acceptable; better false-positive than miss.

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

### 2026-04-29T21:39:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1608-red-team-harness-phase-3--task-lifecycle.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-edf2d34c
- **Timestamp:** 2026-06-02T14:58:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-29T21:43:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
