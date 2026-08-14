# T-1617 — Inception DEFER does not move task to completed — semantics question (parking

> **Inception research artifact** (backfilled by T-2515 from the `T-1617` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-1617-inception-defer-does-not-move-task-to-co.md`. **Decision recorded: GO.**

## Problem Statement

`lib/inception.sh:485-491`:

```bash
# Complete task if go or no-go (not defer)
...
if [ "$decision" = "go" ] || [ "$decision" = "no-go" ]; then
    ...
    update-task.sh ... --status work-completed
fi
```

DEFER explicitly does NOT trigger the work-completed transition. The task stays at `started-work`, remains in `.tasks/active/`, and appears in handover Work-In-Progress and `fw task list`. The Decision section IS written (line 463: "Update Decision section via Python"), so the decision IS final, but lifecycle state remains "in progress."

Today T-1611 was DEFER'd at 08:48Z with a complete recommendation written; status is still `started-work` and the file is still in `active/`. Across the framework's history any DEFER'd inception is sitting in active/ with the same ambiguity — counted as work-in-progress, surfacing in dashboards, even though no agent or human will act on it until the parking condition lifts.

The question this inception explores: **what is DEFER's correct lifecycle state?**

Three candidate semantics:

- **A. DEFER → completed/ (with note)**: parked-but-archived. Removes the WIP noise. Risk: a future GO/NO-GO has to "reactivate" a completed task.
- **B. DEFER → active/, status=parked (new state)**: explicit lifecycle state. Filterable. Doesn't pretend the task is finished but doesn't claim it's actively being worked. Risk: new state needs gate plumbing across update-task.sh, audit, Watchtower.
- **C. Keep current behavior, fix dashboards only**: filter DEFER'd tasks out of WIP/handover queries. Cheapest. Risk: under-models the lifecycle (still no clear "this is parked" view).

## Assumptions

| # | Assumption | Spike |
|---|------------|-------|
| 1 | The current behavior (DEFER stays active) is intentional per code comment, not an oversight. | 1 |
| 2 | Real DEFER tasks accumulate in active/ over time, creating chronic noise. | 2 |
| 3 | A new `parked` status (Option B) is plumbed through update-task.sh's existing transition matrix without major surgery. | 3 |
| 4 | Watchtower / handover / fw task list could surface "parked" tasks via a single filter rather than touching every consumer. | 3 |

## Exploration Plan

Three spikes (each <15min):

- **Spike 1 — confirm the code is intentional + scan history.** DONE inline (this session): `lib/inception.sh:485` comment is explicit ("Complete task if go or no-go (not defer)"). Search git log for the decision: was DEFER-stays-active a deliberate choice or a by-product?
- **Spike 2 — count DEFER'd active tasks today.** `grep -l "Decision.*DEFER" .tasks/active/*.md`. Establish the size of the chronic-noise problem.
- **Spike 3 — design comparison.** Read existing transitions in `agents/task-create/update-task.sh` (which states transition to which) and decide whether Option A/B/C maps cleanly onto the existing model.

## Technical Constraints

- The lifecycle (Captured → Started Work ↔ Issues → Work Completed) is documented in CLAUDE.md. Adding a state requires a doc update plus tests.
- T-1068 invariants enforce status⇄horizon coherence — a `parked` state would need its own rule (probably horizon=`later`).
- Watchtower's `/tasks` view + handover Work-In-Progress + fw task list all read status; adding a state has fan-out cost.
- Reversibility: a parked task should be promotable back to `started-work` cheaply if the future GO/NO-GO arrives.

## Scope Fence

**IN scope:**
- Decide between Options A/B/C.
- If A: extend `lib/inception.sh:491` condition to include DEFER, add reasoning comment.
- If B: add `parked` status + lifecycle plumbing in update-task.sh + dashboards.
- If C: identify the dashboard/handover queries that need a DEFER-filter.

**OUT of scope (deferred):**
- Re-defining DEFER's meaning at the human-process level (DEFER means "come back later" — not changing that).
- Auto-cron that promotes DEFER → started-work after a TTL (separate proposal).
- Cross-project propagation if downstream consumers have their own DEFER'd inceptions (handle once the framework decides).

## Go/No-Go Criteria

**GO if (any one option viable + bounded):**
- Option C identified concretely: a small list of queries (≤3 files) need a `Decision != DEFER` filter and the changes are ≤30 lines total.
- OR Option A traced cleanly: extending the line 491 conditional + handling the move-to-completed-with-DEFER-Decision-block already-written case.

**NO-GO if:**
- All three options expand into multi-week refactors.
- The "DEFER stays active" behavior is load-bearing for a flow we don't yet understand (Spike 1 turns up a deliberate rationale that breaks if we change it).

## Recommendation

- **Recommendation:** GO
- **Rationale:** This is a real semantic gap that creates governance noise (T-1611 sitting in active/ with a final DEFER decision is the canonical witness). Option C (filter DEFER'd tasks out of WIP/handover) is the smallest reversible change and probably sufficient. Option A (move to completed/ with parked note) is also viable. The decision between them is the inception's job. Either way, a fix is bounded.
- **Evidence:**
  - Code source: `lib/inception.sh:485-491` explicitly excludes DEFER (intentional, not a bug)
  - Concrete witness: T-1611 (filed earlier this session, DEFER'd 08:48Z, still in active/ as of now)
  - Cross-cutting impact: handover Work-In-Progress + Watchtower /tasks + fw task list all read status without filtering on Decision
  - Smallest viable path (Option C): one helper `task_is_actively_worked()` that returns false if `Decision == DEFER`, called from the 3 consumers

## Decision

**Decision**: GO

**Rationale**: - Recommendation: GO
- Rationale: This is a real semantic gap that creates governance noise (T-1611 sitting in active/ with a final DEFER decision is the canonical witness). Option C (filter DEFER'd tasks out of WIP/handover) is the smallest reversible change and probably sufficient. Option A (move to completed/ with parked note) is also viable. The decision between them is the inception's job. Either way, a fix is bounded.
- Evidence:
  - Code source: `lib/inception.sh:485-491` explicitly excludes DEFER (intentional, not a bug)
  - Concrete witness: T-1611 (filed earlier this session, DEFER'd 08:48Z, still in active/ as of now)
  - Cross-cutting impact: handover Work-In-Progress + Watchtower /tasks + fw task list all read status without filtering on Decision
  - Smallest viable path (Option C): one helper `task_is_actively_worked()` that returns false if `Decision == DEFER`, called from the 3 consumers

**Date**: 2026-04-30T09:22:10Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-acf2423e
- **Timestamp:** 2026-06-02T14:58:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-30T09:22:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
