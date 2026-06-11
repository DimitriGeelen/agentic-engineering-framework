---
id: T-1103
name: "Inception: episodic auto-generation on partial-complete tasks — premature memory
  of unfinalized work (G-034)"
description: >
  Inception task — RCA the auto-trigger that generates episodic memory for tasks in
  partial-complete state (status=work-completed but file still in .tasks/active/,
  awaiting human AC verification). Trigger: /opt/termlink T-909 transcript 2026-04-11
  — fw inception decide T-909 go printed 'Partial-complete: 1 human AC(s) pending
  verification' AND 'Task stays in active/' AND 'Episodic generated: T-909.yaml' in
  the same block. Result: long-term memory now contains a 'done' record for a task
  the human never finalized. Compounds with G-032 (which silently force-completes)
  to systematically pollute episodic memory. Investigate: (1) where the episodic auto-trigger
  fires in update-task.sh — gate condition and timing; (2) whether the trigger should
  follow physical file location (.tasks/completed/) or status field (work-completed);
  (3) what happens when human eventually rejects the partial-complete (does episodic
  get rewritten? deleted? left stale?); (4) backwards compat — how many existing episodic
  files were generated this way and might need re-generation; (5) recommend GO/NO-GO/DEFER
  + concrete remediation. Origin: G-034.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: [T-1093, G-034, G-032]
created: 2026-04-11T12:37:39Z
last_update: '2026-06-11T22:23:40Z'
date_finished: 2026-04-11T20:08:11Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:40Z'
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

# T-1103: Inception: episodic auto-generation on partial-complete tasks — premature memory of unfinalized work (G-034)

## Problem Statement

When `fw task update T-XXX --status work-completed` runs against a task with unchecked human ACs, the framework correctly enters **partial-complete** state: the status field becomes `work-completed`, but the task file STAYS in `.tasks/active/` with `owner` flipped to `human`, awaiting human finalization. This is a deliberate design — partial-complete is a recognized state.

However, the auto-trigger for **episodic generation** fires on the status transition alone, without waiting for the file to physically move to `.tasks/completed/`. Result: episodic memory contains a "done" record for tasks the human never finalized. Future agents reading episodic will treat them as completed and accept their decisions/learnings as authoritative — even if the human ultimately rejects the work.

**Compounding effect with G-032:** G-032 silently force-completes inception tasks via `fw inception decide`. That trigger now ALSO fires episodic generation via this gap. So every inception that ends in `go`/`no-go` produces a premature episodic for a task with unverified ACs. This systematically pollutes the episodic memory store.

**For whom:** Every future agent that reads `.context/episodic/` for prior-task context. The framework's long-term memory.

**Why now:** Caught in /opt/termlink T-909 transcript (2026-04-11) — `fw inception decide T-909 go` printed `Partial-complete: 1 human AC(s) pending verification`, `Task stays in active/`, AND `Episodic generated: T-909.yaml` in the same output block. The episodic was written to a task that the framework explicitly said was not finalized.

**Severity:** High. Episodic is the framework's truth about prior work. Premature episodic poisons memory, and the human cannot easily detect which episodics are real vs partial-complete.

## Assumptions

A-1: The episodic auto-trigger lives in `agents/task-create/update-task.sh` and fires on the status field, not on file location. (Testable by reading update-task.sh and locating the trigger.)

A-2: Gating the trigger on physical file location (`.tasks/completed/`) is a one-line fix and preserves the intent for fully-completed tasks. (Testable by sketching the patch and tracing the flow.)

A-3: For partial-complete tasks, the right behavior is "defer episodic until the human finalizes" — the second status update (or human re-check that moves the file) triggers it. (Testable by checking what update-task.sh does on the human-finalization path.)

A-4: Existing episodic files in `.context/episodic/` may include premature ones generated under this bug. Need an audit to know how many are corrupted. (Testable by cross-referencing episodic files with task files still in `.tasks/active/`.)

A-5: When the human eventually rejects a partial-complete (status flips back to `started-work` or `issues`), the existing premature episodic is left stale. There is no cleanup. (Testable by reading update-task.sh transition handling.)

## Exploration Plan

**Phase 1 — Locate the trigger.** `grep -n "generate-episodic\|generate_episodic\|episodic" agents/task-create/update-task.sh`. Find the trigger condition. Document what it gates on.

**Phase 2 — Trace the partial-complete path.** Read update-task.sh path for `--status work-completed` when human ACs are unchecked. Confirm: does it move the file? Does it call episodic generation?

**Phase 3 — Audit existing episodics for corruption.** For every file in `.context/episodic/T-*.yaml`, check whether the corresponding task file is in `.tasks/active/` or `.tasks/completed/`. Active = corrupted (premature). Count and sample 5.

**Phase 4 — Sketch the fix.** Patch the trigger gate to require physical completion. Ensure the human finalization path (second status update that physically moves the file) re-triggers it.

**Phase 5 — Recommendation.** GO (ship the gate fix + cleanup audit) / DEFER (gate fix is fine, cleanup of existing premature episodics can wait) / NO-GO (the partial-complete state itself is a misfeature; redesign rather than patch).

## Scope Fence

**IN scope:** RCA, audit, sketch, recommendation. May read framework source and `.context/episodic/`. May write findings to `docs/reports/T-1103-episodic-partial-rca.md`.

**OUT of scope:** Implementing the gate fix. Cleaning up existing premature episodics. Modifying update-task.sh. Build work comes from descendant tasks after the GO decision.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
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

**GO if:**
- Root cause confirmed with line-level evidence in update-task.sh
- Fix is surgical (one guard, zero structural change)
- Corruption is measurable and bounded (68 episodics, 6.8%)

**NO-GO if:**
- The partial-complete state itself is a misfeature that should be redesigned (it is not — it is working correctly except for this one trigger)
- The fix would break the human-finalization path (it does not — Trigger 1 already handles that correctly)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** Root cause confirmed. The episodic auto-trigger at `agents/task-create/update-task.sh:792` fires unconditionally inside the `work-completed` transition block, with no guard for the `PARTIAL_COMPLETE` flag that is correctly set at line 144. The task file correctly stays in `active/` on partial-complete, but the episodic generates anyway. The fix is one `if [ "${PARTIAL_COMPLETE:-false}" = false ]` conditional wrapping lines 792-802. The human-finalization path (Trigger 1 at line 352) already has the correct guard and will generate the episodic when the human finalizes. Zero structural change required.

**Evidence:**
- `update-task.sh:792` — episodic trigger has no `PARTIAL_COMPLETE` guard (confirmed by reading code)
- `update-task.sh:144` — `PARTIAL_COMPLETE=true` correctly set when human ACs are unchecked
- `update-task.sh:352-360` — human-finalization trigger has correct guard (`if [ ! -f episodic ]`)
- `lib/inception.sh:303` — inception decide calls `update-task.sh --force`, compounding: every inception task with a human AC generates a premature episodic on `fw inception decide`
- **68 of 996 episodics (6.8%) are premature** — task still in `active/` with `work-completed` status, all with `owner: human` and 1 unchecked human AC (confirmed by cross-reference audit)
- Full RCA at `docs/reports/T-1103-episodic-partial-rca.md`

## Structural Upgrade (added 2026-04-11 — chokepoint+test discipline pass per T-1105)

The worker's `PARTIAL_COMPLETE` guard at `update-task.sh:792` is correct but lives at the wrong layer — it's a defensive conditional next to the bug, not a chokepoint. Upgrade by moving the trigger to the actual completion event:

**Chokepoint (event, not state):**
- Episodic generation should fire on the **physical file move** (`mv .tasks/active/T-XXX → .tasks/completed/T-XXX`), NOT on the status field. The file move is the canonical "task is finalized" signal — partial-complete by definition does not move the file. Make episodic generation a side effect of `_finalize_task()` (or whatever wraps the move), not of `--status work-completed`.
- This eliminates the gate-vs-state-mismatch class entirely. Future status fields (e.g., `archived`, `deferred`) won't accidentally trigger episodic generation.

**Invariant test:**
- `tests/lint/no-orphan-episodics.bats` — for every `.context/episodic/T-XXX.yaml`, assert the corresponding task file is in `.tasks/completed/`. Run on every commit. Catches both this bug and any future regression. Run as a one-shot now to identify the 68 corrupted episodics already in the repo.

**Cleanup task (downstream):**
- The 68 corrupted episodics are not just stale — they're polluting future agents' memory. The fix needs a **migration** that either deletes them or marks them with `partial_complete: true` until human finalization. Worker's recommendation didn't address the existing corruption.

**Why this is more reliable:** the worker's guard adds a conditional next to the bug. The chokepoint moves the trigger to the actual event. The test makes the invariant continuously enforced — no orphan episodics, ever.

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Root cause confirmed. The episodic auto-trigger at `agents/task-create/update-task.sh:792` fires unconditionally inside the `work-completed` transition block, with no guard for the `PARTIAL_COMPLETE` flag that is correctly set at line 144. The task file correctly stays in `active/` on partial-complete, but the episodic generates anyway. The fix is one `if [ "${PARTIAL_COMPLETE:-false}" = false ]` conditional wrapping lines 792-802. The human-finalization path (Trigger 1 at line 352) already has the correct guard and will generate the episodic when the human finalizes. Zero structural change required.

Evidence:
- `update-task.sh:792` — episodic trigger has no `PARTIAL_COMPLETE` guard (confirmed by reading code)
- `update-task.sh:144` — `PARTIAL_COMPLETE=true` correctly set when human ACs are unchecked
- `update-task.sh:352-360` — human-finalization trigger has correct guard (`if [ ! -f episodic ]`)
- `lib/inception.sh:303` — inception decide calls `update-task.sh --force`, compounding: every inception task with a human AC generates a premature episodic on `fw inception decide`
- 68 of 996 episodics (6.8%) are premature — task still in `active/` with `work-completed` status, all with `owner: human` and 1 unchecked human AC (confirmed by cross-reference audit)
- Full RCA at `docs/reports/T-1103-episodic-partial-rca.md`

**Date**: 2026-04-11T20:08:11Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Root cause confirmed. The episodic auto-trigger at `agents/task-create/update-task.sh:792` fires unconditionally inside the `work-completed` transition block, with no guard for the `PARTIAL_COMPLETE` flag that is correctly set at line 144. The task file correctly stays in `active/` on partial-complete, but the episodic generates anyway. The fix is one `if [ "${PARTIAL_COMPLETE:-false}" = false ]` conditional wrapping lines 792-802. The human-finalization path (Trigger 1 at line 352) already has the correct guard and will generate the episodic when the human finalizes. Zero structural change required.

Evidence:
- `update-task.sh:792` — episodic trigger has no `PARTIAL_COMPLETE` guard (confirmed by reading code)
- `update-task.sh:144` — `PARTIAL_COMPLETE=true` correctly set when human ACs are unchecked
- `update-task.sh:352-360` — human-finalization trigger has correct guard (`if [ ! -f episodic ]`)
- `lib/inception.sh:303` — inception decide calls `update-task.sh --force`, compounding: every inception task with a human AC generates a premature episodic on `fw inception decide`
- 68 of 996 episodics (6.8%) are premature — task still in `active/` with `work-completed` status, all with `owner: human` and 1 unchecked human AC (confirmed by cross-reference audit)
- Full RCA at `docs/reports/T-1103-episodic-partial-rca.md`

**Date**: 2026-04-11T20:08:11Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-11T12:46:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-11T20:08:11Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Root cause confirmed. The episodic auto-trigger at `agents/task-create/update-task.sh:792` fires unconditionally inside the `work-completed` transition block, with no guard for the `PARTIAL_COMPLETE` flag that is correctly set at line 144. The task file correctly stays in `active/` on partial-complete, but the episodic generates anyway. The fix is one `if [ "${PARTIAL_COMPLETE:-false}" = false ]` conditional wrapping lines 792-802. The human-finalization path (Trigger 1 at line 352) already has the correct guard and will generate the episodic when the human finalizes. Zero structural change required.

Evidence:
- `update-task.sh:792` — episodic trigger has no `PARTIAL_COMPLETE` guard (confirmed by reading code)
- `update-task.sh:144` — `PARTIAL_COMPLETE=true` correctly set when human ACs are unchecked
- `update-task.sh:352-360` — human-finalization trigger has correct guard (`if [ ! -f episodic ]`)
- `lib/inception.sh:303` — inception decide calls `update-task.sh --force`, compounding: every inception task with a human AC generates a premature episodic on `fw inception decide`
- 68 of 996 episodics (6.8%) are premature — task still in `active/` with `work-completed` status, all with `owner: human` and 1 unchecked human AC (confirmed by cross-reference audit)
- Full RCA at `docs/reports/T-1103-episodic-partial-rca.md`

### 2026-04-11T20:08:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:15Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6592a67c
- **Timestamp:** 2026-06-02T14:55:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
