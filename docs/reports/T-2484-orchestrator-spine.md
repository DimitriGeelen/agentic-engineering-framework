# T-2484 — Orchestrator dispatch spine: one real end-to-end dispatch

**Status:** inception, in exploration
**Created:** 2026-06-24
**Origin:** reflection dialogue on why we introduced worktrees → critical scope-creep
review → discovery that the orchestrator has never dispatched.

---

## Why this inception exists (the thread)

The 2026-06-24 session finished the parallel-work / merge-back tooling (T-2473/74/77/81/82/83).
The operator then asked for an **ultra-deep critical reflection**: *why did we start
introducing worktrees, are we on track, is there scope creep?* That dialogue walked back up
the dependency chain and found the real keystone was never built.

## Dialogue Log

### Segment 1 — why worktrees, and is it scope creep?

**Agent reflection.** Worktrees were never the goal; they are a *substrate* for one ambition:
run multiple agents in parallel without collision (arc-011). The cascade: parallel agents →
need isolation → worktrees → shared `.context/` lineage collides on merge → ~10 tasks + 3 OBS
entries (OBS-080/085/086) spent making merge-back not-hard. **Sharp finding:** most merge-back
pain is *self-inflicted* by the worktree decision — the historical "work on master, handover
pushes" model had no merge-back problem. We may have built a parallel substrate whose demand
(concurrency) was never validated, while the work itself stayed sequential.

Scope-creep verdict: **yes, signals present** (solution-first, self-inflicted problem, long
point-fix tail — T-2464 itself named "7+ point-fixes, one root", capability ahead of use) —
**but not pure waste** (OBS-085 YAML resolver and `fw_reanchor_from_cwd` + the un-partitionable
taxonomy help any multi-writer host, parallel or not).

**Operator Q1 (parallelism need):** answered **"Scaling target, soon"** — not yet regularly
concurrent, but a concrete near-term plan to run many parallel agents; wants the substrate ready.

**Operator Q2 (direction):** *"maybe we need to differentiate, arc worktrees for arc or
particular high-impact type of tasks that cannot be run in isolation — it then becomes an
orchestrator decision."*

### Segment 2 — the reframe: tiered isolation as an orchestrator decision

**Agent reflection.** This turns worktrees from a *default* into a *tier*: a light lane
(small/low-blast/sequential → work in place, no merge-back problem) and a heavy lane (high-impact
/ non-isolatable → worktree quarantine → the integrate/union/go-live machinery). This
**retroactively justifies** the week's merge-back work as the heavy-lane backend rather than
indicting it. Crucially the routing is mostly *wiring existing primitives* (`fw write-set check`,
`fw fabric blast-radius`), not new plumbing. Real risks flagged: (1) write-set *undecidability*
degrades the policy to "worktree everything"; (2) there is no orchestrator to *make* the
decision yet (memory: "orchestrator not wired").

### Segment 3 — two corrections that re-aimed the whole thing

**Operator (a):** *do NOT isolate at the arc level — limit to task level; arc-level worktrees
cause huge buildup and task-closure hogs, keeping valuable improvements out of the code.*
→ Inverts the agent's "arc_id → heavy lane" heuristic. Isolation is **per-task**; arc membership
is not a trigger (if anything, a reason to land each task *faster*). Continuous-integration
argument. **[CONVERGED]**

**Operator (b):** *getting the orchestrator wired should be prioritised above all — surprised to
discover it isn't, because without proper orchestrator triage / dispatching / task-crafting /
routing it all falls apart, collapses and stays single-agent execution.*
→ Re-prioritises everything: the keystone is the orchestrator, not worktree polish. The
light/heavy routing decision is *itself* an orchestrator function. **[CONVERGED]**

### Segment 4 — empirical grounding

Agent checked live state before proposing:
- `fw orchestrator status` → **"no dispatches captured yet"** (`.context/dispatches.jsonl` empty).
- **~30+ active orchestrator/dispatch/routing tasks** (T-1636/37, T-1684/85/87, T-1701, T-1773-76,
  T-1792-1807, T-1818-21, …) — substrate, worker primitives, and Watchtower panels, all built
  before a single dispatch ever ran.

**Finding:** the same scope-creep pattern, one level up and far bigger — *dashboards for an engine
that never turned over*. This empirically confirms the operator's instinct.

### Segment 5 — agreed direction

**Operator (IW-1 / IW-4):** *"yes, actually let's start with one and then have more quickly"* +
*"go"*. Bar for "wired" = **one real end-to-end dispatch as slice 1, then iterate to many
quickly** (autonomous queue-picking is slice 2+, not now). Green light to file this inception and
capture the dialogue. **[CONVERGED]**

---

## Findings so far

1. **F1 — Orchestrator has literally never dispatched.** Live: `fw orchestrator status` empty.
   [verified]
2. **F2 — ~30 substrate tasks exist ahead of a working spine.** [verified via active/ grep]
3. **F3 — The spine, not the panels, is the critical path.** triage → craft → route → spawn →
   capture-outcome. [hypothesis — Spike 1/2 to confirm]
4. **F4 — Isolation granularity is per-task, never per-arc** (operator decision). [converged]
5. **F5 — Worktree/merge-back work is parked, not wasted** — it is the eventual heavy-lane backend
   the orchestrator will call once it routes. [converged]

## Next steps (exploration)

- **[OPEN] Spike 1** — substrate map: what along triage→outcome is implemented vs stubbed vs
  missing (read T-1773/74/75/1797/1636 + live `fw resolver`/`orchestrator`/`outcome`).
- **[OPEN] Spike 2** — attempt one real dispatch end-to-end with existing verbs; the first break
  point is the first build slice.
- **[OPEN] Triage** — classify the ~30 tasks into critical-path / defer / kill.
- Then finalise Recommendation + named first slice → `fw task review T-2484` for operator go/no-go.

## Provisional recommendation

**GO** (confirm the specific first slice after Spike 1 + Spike 2). Orchestrator-above-all is the
operator's stated priority; the move is one real dispatch then iterate, not more substrate. The
inception is self-limiting (triage, not construction).
