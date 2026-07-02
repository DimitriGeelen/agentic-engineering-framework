---
id: T-1316
name: "Pickup from email-archive: Watchtower verification CWD bug (sourced T-1044)"
description: >
  Bug from /opt/050-email-archive (T-1044): Watchtower runs verification commands
  with CWD=.agentic-framework/ instead of PROJECT_ROOT, causing HTTP 500 on inception
  decide GO. Root cause verified: watchtower.sh:169 cd's to FRAMEWORK_ROOT; update-task.sh:223
  evals verification with no cd to PROJECT_ROOT. One-line fix proposed (Option 1).
  Proposal artifact at docs/proposals/T-1316-from-email-archive-watchtower-verification-cwd.md.

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-18T20:33:46Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-04-18T22:49:32Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1316: Pickup from email-archive: Watchtower verification CWD bug (sourced T-1044)

## Problem Statement

When the Watchtower invokes `fw task update T-XXX --status work-completed` (or `inception decide go`) via its web routes, the P-011 verification gate runs verification commands with **CWD=`<project>/.agentic-framework/`** instead of CWD=`<project>/`. Any verification command using a relative path (the canonical form, e.g. `test -f docs/reports/...`) fails, and the route returns HTTP 500.

Same command run from terminal passes (CWD is correct). Bug only manifests in vendored consumer projects through the web UI.

Source: pickup from email-archive (T-1044). Full proposal at `docs/proposals/T-1316-from-email-archive-watchtower-verification-cwd.md`. Same class as T-1043/T-1315 — vendored-vs-repo mode blind spot.

## Assumptions

1. `bin/watchtower.sh:172` `cd "$FRAMEWORK_ROOT"` is intentional (lets `python3 -m web.app` find the package) — confirmed.
2. `agents/task-create/update-task.sh:223` evals verification with no CWD reset — confirmed.
3. Verification commands across the codebase already assume project-root-relative paths (e.g. our own `grep -q "..." web/shared.py`) — confirmed by survey.
4. `cd "$PROJECT_ROOT"` inside the verification subshell is non-breaking for callers that already happen to be in PROJECT_ROOT (no-op).

## Exploration Plan

None — RCA already done by email-archive's pickup, with line numbers verified in our copy. Implementation:
- Option 1 (chosen): one-line fix in `update-task.sh:223` adding `cd "$PROJECT_ROOT" &&` to the eval subshell.
- Skip Option 2 (changing watchtower.sh CWD) because it has a wider blast radius (Flask static/template path resolution) and Option 1 alone closes the verification-gate failure mode.

## Technical Constraints

- Must not break callers that already ran from PROJECT_ROOT (cd is idempotent).
- Must not introduce new Bash error modes if `$PROJECT_ROOT` is unset (it's exported by `fw` shim).
- Must keep the existing TASKS_DIR/CONTEXT_DIR unset behaviour (T-739).

## Scope Fence

**IN:** One-line edit to `agents/task-create/update-task.sh:223`. Bats regression test in `tests/unit/update_task_verification.bats` covering relative-path verification from non-PROJECT_ROOT CWD.

**OUT:** Changing `watchtower.sh` CWD (Option 2). Auditing other eval sites (`healing.sh`, etc.) for the same issue — separate task if needed.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (T-1317 build verified, regression test green)
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

grep -q 'cd "$PROJECT_ROOT" && eval' agents/task-create/update-task.sh
bats tests/unit/update_task_verification.bats

## Recommendation

**Recommendation:** GO

**Rationale:** Reported with full RCA, verified line numbers (`bin/watchtower.sh:172`, `agents/task-create/update-task.sh:223`), Option 1 fix is one line and strictly more correct (relative paths now resolve where task authors expect). Risk near zero — verification commands in our own tasks already assume PROJECT_ROOT-relative paths.

**Evidence:**
- Confirmed `cd "$FRAMEWORK_ROOT"` at `bin/watchtower.sh:172`.
- Confirmed `eval "$cmd"` with no CWD reset at `agents/task-create/update-task.sh:223`.
- Email-archive provided live `/proc/PID/cwd` evidence.
- Same bug class as T-1043/T-1315 (vendored-mode blind spot).
- Option 2 (change watchtower.sh CWD) deferred — wider blast radius, separate task if needed.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Reported with full RCA, verified line numbers (`bin/watchtower.sh:172`, `agents/task-create/update-task.sh:223`), Option 1 fix is one line and strictly more correct (relative paths now resolve where task authors expect). Risk near zero — verification commands in our own tasks already assume PROJECT_ROOT-relative paths.

Evidence:
- Confirmed `cd "$FRAMEWORK_ROOT"` at `bin/watchtower.sh:172`.
- Confirmed `eval "$cmd"` with no CWD reset at `agents/task-create/update-task.sh:223`.
- Email-archive provided live `/proc/PID/cwd` evidence.
- Same bug class as T-1043/T-1315 (vendored-mode blind spot).
- Option 2 (change watchtower.sh CWD) deferred — wider blast radius, separate task if needed.

**Date**: 2026-04-18T22:50:07Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-18T20:34:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-18T22:49:32Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Reported with full RCA, verified line numbers (`bin/watchtower.sh:172`, `agents/task-create/update-task.sh:223`), Option 1 fix is one line and strictly more correct (relative paths now resolve where task authors expect). Risk near zero — verification commands in our own tasks already assume PROJECT_ROOT-relative paths.

Evidence:
- Confirmed `cd "$FRAMEWORK_ROOT"` at `bin/watchtower.sh:172`.
- Confirmed `eval "$cmd"` with no CWD reset at `agents/task-create/update-task.sh:223`.
- Email-archive provided live `/proc/PID/cwd` evidence.
- Same bug class as T-1043/T-1315 (vendored-mode blind spot).
- Option 2 (change watchtower.sh CWD) deferred — wider blast radius, separate task if needed.

### 2026-04-18T22:49:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-18T22:50:07Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Reported with full RCA, verified line numbers (`bin/watchtower.sh:172`, `agents/task-create/update-task.sh:223`), Option 1 fix is one line and strictly more correct (relative paths now resolve where task authors expect). Risk near zero — verification commands in our own tasks already assume PROJECT_ROOT-relative paths.

Evidence:
- Confirmed `cd "$FRAMEWORK_ROOT"` at `bin/watchtower.sh:172`.
- Confirmed `eval "$cmd"` with no CWD reset at `agents/task-create/update-task.sh:223`.
- Email-archive provided live `/proc/PID/cwd` evidence.
- Same bug class as T-1043/T-1315 (vendored-mode blind spot).
- Option 2 (change watchtower.sh CWD) deferred — wider blast radius, separate task if needed.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ed1c752b
- **Timestamp:** 2026-06-02T14:56:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
