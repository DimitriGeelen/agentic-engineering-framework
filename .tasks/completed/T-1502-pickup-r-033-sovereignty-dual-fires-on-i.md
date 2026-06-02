---
id: T-1502
name: "Pickup: R-033 sovereignty dual-fires on inception completion (decide + work-completed) — collapse to one (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-115. Type: feature-proposal.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [pickup, feature-proposal]
components: [C-004, lib/inception.sh, lib/task-audit.sh]
related_tasks: []
created: 2026-04-26T11:13:25Z
last_update: 2026-04-26T13:58:26Z
date_finished: 2026-04-26T13:58:26Z
source_task_id_in_origin: T-115
source_project_in_origin: "003-NTB-ATC-Plugin"
---

# T-1502: Pickup: R-033 sovereignty dual-fires on inception completion (decide + work-completed) — collapse to one (from 003-NTB-ATC-Plugin)

## Problem Statement

**Pickup claims R-033 (human sovereignty gate) fires twice on inception completion: once at `fw inception decide`, once at the auto-triggered `fw task update --status work-completed`. Pickup proposes collapsing to one fire.**

Origin (003-NTB-ATC-Plugin / P-008 / T-115): downstream agent observed "every inception close burns a sovereignty bypass with logged audit noise". Combined with T-012 (Watchtower CLAUDECODE-inheritance bug) the human had to manually bypass on the CLI side too. Pickup ranks three fixes: (1) `decide` auto-transitions to work-completed, (2) R-033 accepts a recent `## Decision` entry as sovereignty proof, (3) explicit "decision-already-recorded" short-circuit message.

**Why this might already be fixed:** the pickup was filed 2026-04-25T08:00Z — predating the framework-side fixes for both items (T-1262 `--from-watchtower`, T-637 `--skip-sovereignty` in chained call). Need to validate whether the dual-fire still occurs as described.

## Assumptions

- **A1:** `do_inception_decide` (`lib/inception.sh:494`) already calls `update-task.sh --status work-completed --skip-sovereignty` with the bypass — so R-033 logs ONE bypass event for the inception arc, not two real human prompts. **Confirmed:** lib/inception.sh:494 reads `"$AGENTS_DIR/task-create/update-task.sh" "$task_id" --status work-completed --skip-sovereignty --reason "Inception decision: $decision_upper"`.
- **A2:** The Watchtower path (T-1262 `--from-watchtower` flag) reaches the same `do_inception_decide` finalizer — so a Watchtower decide DOES auto-transition to work-completed without a second human prompt. **Confirmed:** web/blueprints/inception.py:497 passes `--from-watchtower` which exempts the T-1259 CLAUDECODE guard.
- **A3:** "Two sovereignty exercises" in the pickup actually meant *one human decide-action* + *one logged bypass at the chained work-completed transition* — not two human prompts. The bypass IS the audit record that human authority was exercised at decide-time. Validated by inspecting `.gate-bypass-log.yaml` post-T-1505 close: one entry per inception, not two.
- **A4:** The proposed Option 1 ("decide auto-transitions to work-completed") IS what the framework does today, since T-637. Pickup's Option 1 is asking for what already exists.
- **A5:** Live evidence — five inceptions decided GO via Watchtower in this session (T-1500, T-1503, T-1504, T-1505, T-1509). Each produced exactly one bypass-log entry, no second human prompt. Falsifiable by counting entries.

## Exploration Plan

1. **Confirm A1+A4** (5 min) — read `lib/inception.sh:485-495`. ✅ `--skip-sovereignty` is on the chained call.
2. **Confirm A2** (5 min) — read `web/blueprints/inception.py:497`. ✅ `--from-watchtower` is passed and propagates to `do_inception_decide`.
3. **Confirm A3+A5** (5 min) — `grep T-1505` `.context/working/.gate-bypass-log.yaml`. Expect: 1 entry per close.
4. **Recurrence check** (5 min) — search `learnings.yaml` and `concerns.yaml` for "dual-fire" / "sovereignty twice" / "R-033 twice" — does downstream still hit this post-T-1262?
5. **Recommendation** (5 min).

## Technical Constraints

- **Sovereignty bypass logging is deliberate:** `.gate-bypass-log.yaml` records every bypass for audit. Removing the second R-033 check would also remove the bypass log entry — reducing audit fidelity.
- **R-033 separation of concerns:** the gate at decide vs at work-completed serve different roles — decide records the *decision*, work-completed transitions the *task state*. Collapsing couples two concerns.
- **Legacy CLI workflow must keep working:** humans editing `## Decision` manually then running `fw task update --status work-completed` (direct-CLI, no `do_inception_decide`) MUST still hit a real R-033 prompt — they didn't go through inception decide.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- A1, A2, A4 are FALSE — i.e. the framework still produces two real human prompts per inception close
- Bypass-log entries show ≥2 per inception close (proving the dual-fire persists)
- A redesign meaningfully reduces friction without losing audit fidelity

**NO-GO if:**
- A1+A2+A4 hold — pickup is asking for what already exists; close as obsolete with a learning that the bypass-log entry *is* the structural audit record
- "Dual-fire" was a misreading: one decide + one logged bypass = one human action with audit trail, working as designed
- Removing the second R-033 check would lose audit fidelity in `.gate-bypass-log.yaml`

**DEFER if:**
- Pickup's Option 2 (general "fresh ## Decision = sovereignty proof, time-windowed") is desirable as a future generalisation but premature — needs a non-inception use case to justify
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** NO-GO (close as obsolete)

**Rationale:** The pickup's "dual-fire" is a misreading of the existing structural design, not a bug:

1. **Pickup's Option 1 already exists.** `lib/inception.sh:494` chains `update-task.sh --status work-completed --skip-sovereignty` after recording the decision — the `decide → work-completed` auto-transition has been live since T-637. Pickup's preferred fix is what the framework does today.

2. **Watchtower path also works.** T-1262 added `--from-watchtower` which exempts the T-1259 CLAUDECODE guard. Five inceptions decided in this session via Watchtower (T-1500, T-1503, T-1504, T-1505, T-1509) all transitioned to `completed/` cleanly with no second human prompt.

3. **What the pickup called "dual-fire" is one human action + one audit log entry.** Bypass-log inspection shows exactly ONE entry per inception close (e.g. `T-1455 2026-04-25T18:02:40Z "Inception decision: GO"`). The bypass entry IS the structural audit record proving the human's decide-time authority propagated to the work-completed transition. Removing the second R-033 check would also remove that audit entry — reducing fidelity, not improving it.

4. **Cross-reference partner bug T-1496.** Pickup mentions T-012 (Watchtower CLAUDECODE-inheritance breaking the finalizer) — that pickup is now T-1496 here. T-1496 should be evaluated separately; resolving it (along with T-1262 already shipped) closes the Watchtower path without touching R-033.

The right action is closure + a learning entry, not a code change:
- **Close T-1502 as NO-GO** with this rationale.
- **Capture L-XXX:** "R-033 dual-fire is a misreading — `do_inception_decide` already passes `--skip-sovereignty` to the chained work-completed call. The bypass-log entry is the structural audit record, not noise."
- **Inform 003-NTB-ATC-Plugin** via pickup-back: this works as designed; if you're seeing two prompts, your framework is pre-T-1262 — run `fw upgrade`.

**Evidence:**
- `lib/inception.sh:494` — `--skip-sovereignty` is on the chained call
- `web/blueprints/inception.py:497` — `--from-watchtower` exempts the agent-block guard
- `.context/working/.gate-bypass-log.yaml` — exactly one entry per inception close (T-1455, T-1346, T-1388 each have one entry per close)
- This session's audit trail: T-1500, T-1503, T-1504, T-1505, T-1509 all transitioned cleanly to completed/ via Watchtower decide, no second human prompt
- T-637 (--skip-sovereignty in inception decide chain) and T-1262 (--from-watchtower for Flask) are the two prior fixes that already resolve this

**Alternative considered (DEFERRED, not REJECTED):** pickup's Option 2 — "R-033 should accept a recent `## Decision` entry as sovereignty proof" — is a sound generalisation for non-inception flows. Defer until a real non-inception use case exists. Don't pre-build for hypothetical workflows.

**Alternative considered (REJECTED):** removing R-033 from the work-completed transition entirely. Would lose audit fidelity AND break the legacy direct-CLI flow (human edits `## Decision` manually, then runs `fw task update --status work-completed` outside `do_inception_decide`).

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

**Decision**: NO-GO

**Rationale**: The pickup's "dual-fire" is a misreading of the existing structural design, not a bug:

1. Pickup's Option 1 already exists. `lib/inception.sh:494` chains `update-task.sh --status work-completed --skip-sovereignty` after recording the decision — the `decide → work-completed` auto-transition has been live since T-637. Pickup's preferred fix is what the framework does today.

2. Watchtower path also works. T-1262 added `--from-watchtower` which exempts the T-1259 CLAUDECODE guard. Five inceptions decided in this session via Watchtower (T-1500, T-1503, T-1504, T-1505, T-1509) all transitioned to `completed/` cleanly with no second human prompt.

3. What the pickup called "dual-fire" is one human action + one audit log entry. Bypass-log inspection shows exactly ONE entry per inception close (e.g. `T-1455 2026-04-25T18:02:40Z "Inception decision: GO"`). The bypass entry IS the structural audit record proving the human's decide-time authority propagated to the work-completed transition. Removing the second R-033 check would also remove that audit entry — reducing fidelity, not improving it.

4. Cross-reference partner bug T-1496. Pickup mentions T-012 (Watchtower CLAUDECODE-inheritance breaking the finalizer) — that pickup is now T-1496 here. T-1496 should be evaluated separately; resolving it (along with T-1262 already shipped) closes the Watchtower path without touching R-033.

The right action is closure + a learning entry, not a code change:
- Close T-1502 as NO-GO with this rationale.
- Capture L-XXX: "R-033 dual-fire is a misreading — `do_inception_decide` already passes `--skip-sovereignty` to the chained work-completed call. The bypass-log entry is the structural audit record, not noise."
- Inform 003-NTB-ATC-Plugin via pickup-back: this works as designed; if you're seeing two prompts, your framework is pre-T-1262 — run `fw upgrade`.

**Date**: 2026-04-26T13:58:25Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-26T13:43:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-26T13:58:25Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** The pickup's "dual-fire" is a misreading of the existing structural design, not a bug:

1. Pickup's Option 1 already exists. `lib/inception.sh:494` chains `update-task.sh --status work-completed --skip-sovereignty` after recording the decision — the `decide → work-completed` auto-transition has been live since T-637. Pickup's preferred fix is what the framework does today.

2. Watchtower path also works. T-1262 added `--from-watchtower` which exempts the T-1259 CLAUDECODE guard. Five inceptions decided in this session via Watchtower (T-1500, T-1503, T-1504, T-1505, T-1509) all transitioned to `completed/` cleanly with no second human prompt.

3. What the pickup called "dual-fire" is one human action + one audit log entry. Bypass-log inspection shows exactly ONE entry per inception close (e.g. `T-1455 2026-04-25T18:02:40Z "Inception decision: GO"`). The bypass entry IS the structural audit record proving the human's decide-time authority propagated to the work-completed transition. Removing the second R-033 check would also remove that audit entry — reducing fidelity, not improving it.

4. Cross-reference partner bug T-1496. Pickup mentions T-012 (Watchtower CLAUDECODE-inheritance breaking the finalizer) — that pickup is now T-1496 here. T-1496 should be evaluated separately; resolving it (along with T-1262 already shipped) closes the Watchtower path without touching R-033.

The right action is closure + a learning entry, not a code change:
- Close T-1502 as NO-GO with this rationale.
- Capture L-XXX: "R-033 dual-fire is a misreading — `do_inception_decide` already passes `--skip-sovereignty` to the chained work-completed call. The bypass-log entry is the structural audit record, not noise."
- Inform 003-NTB-ATC-Plugin via pickup-back: this works as designed; if you're seeing two prompts, your framework is pre-T-1262 — run `fw upgrade`.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ead9aa43
- **Timestamp:** 2026-06-02T14:57:55Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T13:58:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: NO-GO
