# T-3532 — Workflow-management task class (WM-NNN)

**Inception.** Operator-originated, 2026-09-28. Recommendation: **GO**.

## Problem statement

The task gate (`check-active-task.sh`, P-002) refuses every Write/Edit and every Bash
command it cannot prove is a read, whenever focus is null. Focus goes null at exactly the
moment a task closes. So the work that *follows* a close — and the work that *precedes*
selecting the next task — has no task it can run under, and is structurally unreachable.

Twelve recorded instances (OBS-250). Three on 2026-09-28 alone:

| # | What was refused | Consequence |
|---|---|---|
| 1 | Worker `judge-arc-r1` committing its own finished T-3527 deliverable | Filed **T-3530** purely to run `git commit` |
| 2 | `fw context add-learning` for T-3529 | The framework **prompted for the learning at close, then refused the command that records it** |
| 3 | `fw arcs`, `fw bvp`, `checkpoint.sh budget`, reading an audit YAML | An **autonomous mandate could not read the objectives it was told to select from** — it stopped at step zero |

## The reframe that makes this tractable

The question is not "how do we get around the gate". It is **why the gate exists**, and
then giving the exempt-looking work a home that satisfies it.

Operator, verbatim (2026-09-28):

> *"Why is this rule in there? … One reason I can think about is that we want to prevent
> rogue sabotage or unintended mishap taking place. And the only way we currently can
> ensure that all framework governance is applied is by having an active task. So maybe we
> should have a routine for this, which is a standing task … Workflow management tasks. For
> instance, call it WM001 … And then your focus to WM001 is select new tasks to work on."*

The gate's purpose is **governance coverage** — every action attributable and governed —
not bookkeeping. Selection *is* work. Close-out *is* work. They need tasks, not exemptions.

**This is strictly better than the alternative the agent had recommended** (a time-boxed
grace window on focus after close). A grace window buys ergonomics by weakening the gate for
a period; a standing task buys the same ergonomics while leaving the invariant —
*nothing gets done without a task* — completely intact. Nothing is traded.

## Half of this is already specified and was never built

CLAUDE.md §Enforcement Tiers, unchanged since the tiers were written:

| Tier | Description | Bypass | Implementation |
|---|---|---|---|
| 3 | Pre-approved categories (health checks, status queries, git-status) | Configured | **Spec only** |

Tier 3 is the **read** half of this problem, specified and never implemented. Four of the
seven blocks observed today were pure reads. The gate's own block message says so:
*"this command writes nothing the gate can detect … that is a gap in the allowlist worth
filing."* It has been printing that instruction to agents, unfiled, for as long as it has
existed.

**Proposed split:** Tier 3 covers reads. The WM class covers writes that belong to no
deliverable.

## Proposed shape (to be settled by this inception, not asserted here)

A **closed** set of workflow-management tasks in their own `WM-` namespace. Closed, not
open — an open namespace becomes the dumping ground within a month.

| Id | Scope | Fence |
|---|---|---|
| WM-001 | Selection & discovery — reads, ranking, deciding what is next | No source writes |
| WM-002 | Close-out & trailing work — `vendor self`, `add-learning`, `termlink cleanup` | Scoped to the task just closed |
| WM-003 | Session lifecycle — init, resume, handover, cleanup | No source writes |

Adding a fourth requires an operator ruling.

**Boundary test, so the category stays honest:** *if it produces no deliverable and closes
no acceptance criterion of a delivery task, it is WM.* The moment work under a WM task
starts producing a deliverable, it needs a real T-task. That line is checkable by an audit
rail.

## Risks — the three that decide the design

**R1 — A standing task is a standing exemption.** If WM-001 is permanently available as
focus, an agent that does not want to scope real work can sit in it and edit source. That is
the precise rogue-action risk the gate exists to prevent, re-entering through the front
door. **Mitigation:** per-WM scope fences, enforced in the gate rather than by convention.
Precedent exists — the G-020 gate already admits metadata-only `fw task update` from a
blocked state and nothing else (T-3299). *(IW-2)*

**R2 — A never-closing task breaks machinery that assumes closure.** Episodic generation,
staleness audits, horizon invariants, review-queue counts, arc completion ratios all assume
tasks end. A permanently-open `T-` task would read as stale work forever. This is the
strongest argument for the separate namespace: `WM-` is a **different class** those
mechanisms skip by construction, not by special-case. *(IW-1)*

**R3 — Traceability must not collapse into one bucket.** Today any commit traces to its
`T-NNNN`. If housekeeping lands under `WM-001`, that resolution is lost. **Mitigation:** WM
tasks carry a rolling log rather than acceptance criteria, each entry naming its real
subject — `WM-001` becomes an *attribution channel*, not a black hole. *(IW-3)*

## Open questions

Filed on the task as **IW-1 … IW-5** (directory-vs-marker; enforce-vs-advise the fences;
how WM-002 is scoped to the just-closed task; whether Tier 3 ships here or separately; and
the interaction with OBS-468/T-3432, where session-scoped focus means close *fails* to clear
focus and the session hard-deadlocks). IW-4 is the one worth deciding first: Tier 3 is
separable, cheaper, and alone would have unblocked 4 of today's 7 instances.

## Dialogue log

**2026-09-28 — operator, on the asymmetry of estimate errors** (from this thread's earlier
decision, recorded because it set the reasoning style applied here):

> *"What's worse — something that has high value but never gets done because it was never
> estimated, or something that has high value, gets done, but might cost a little less or a
> little more?"*

and the follow-up that closed a hole in the agent's proposal:

> *"If we cannot measure we should fall back to an estimate, right? Because if we cannot
> measure and it stays empty, then it still gets not done."*

The agent had proposed "measure it" with no floor — which leaves unmeasurable tasks empty,
i.e. re-excluded. The corrected rule: **measure → estimate (marked) → never empty.**
*Unmeasured must never mean unranked.*

**2026-09-28 — operator, on the WM class:** quoted in full under *The reframe* above.

**Course correction recorded:** the agent's Decision-2 advisory was a grace window on focus.
The operator's standing-task proposal supersedes it, because it preserves the invariant
instead of suspending it. The agent's own scoring table had already marked the grace
window's Reliability at `+` *precisely because it weakens the gate*, while the operator's
option scores `+++` on that axis — the agent should have reached this conclusion by reading
its own table.

## Relationship to the session's recurring defect class

This session fixed two instances of *a check that cannot run must not answer as a check that
ran and judged* (OBS-560, OBS-562), and one of *a value that cannot be measured must not
disappear* (the cost-default ruling). This inception is the third member of the same family:
**an action that cannot be attributed must not become unreachable.** In each case the
failure mode is silence — a verdict, a value, or a capability that vanishes rather than
declaring itself.
