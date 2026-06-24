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

## Spike 1 — substrate map [DONE]

Explore-agent map (full detail in dialogue notes). **The chain is shipped end-to-end; no code
gap blocks a dispatch.**
- Triage = a workflow (`task_type=prompt-triage`), not separate code. [implemented]
- Craft = `lib/resolver.py` `resolve()` + `capture_dispatch()` (appends the real envelope row to
  `.context/dispatches.jsonl`). [implemented]
- Route = `worker_kind` → `_DISPATCHERS` in `lib/spawn.py` (`pi`, `ollama-loop`, `TermLink` all
  wired; `Task` raises NotImplementedError). [implemented]
- Spawn = `lib/spawn.py` `spawn_dispatch()` → all 3 worker classes exist on disk
  (`lib/pi_worker.py`, `lib/ollama_loop.py`, `lib/termlink_worker.py`). [implemented]
- Outcome = `lib/outcome.py` `backprop_outcome()` appends to `dispatch-outcomes.jsonl`.
  [implemented]
- `fw orchestrator improve` = STUB ("v2 not yet implemented"). [stub, out of scope]

**Spike-1 conclusion:** the blocker is *runtime/invocation*, not construction. The
ollama-loop/triage workflows point at a litellm proxy on `localhost:4000` which is **down**
(connection refused). The `TermLink` worker path (`default.yaml`) is the one that can fire live.

## Spike 2 — one real dispatch [DONE — SUCCESS]

Drove a controlled real dispatch: throwaway probe task **T-2485** (ACs: make no changes, confirm
receipt, stop) via `python3 lib/resolver.py run T-2485 default` (TermLink worker, hub up).

**Result — the loop turned over for the first time in the framework's history:**
- `dispatch_id 4e2f4f03-…` written to `.context/dispatches.jsonl` (was empty).
- TermLink worker `tl-e76a0679` spawned → ran → exited 0; `status: success`, terminal=result,
  is_error=False, 15 events.
- `python3 lib/outcome.py backprop T-2485` → outcome appended.
- `fw orchestrator status`: **Dispatches 1 · Outcome events 1 · Enriched 1/1 (100%)** — was
  "no dispatches captured yet."

**Zero new code was required.** A1 (composable from existing primitives) — CONFIRMED.

## Smoking gun — why it was never invoked (NEW, Spike 2)

`fw resolver run` and `fw outcome backprop` both fail with **`Permission denied`**. Root cause:
`bin/fw` invokes these verbs via `exec "$FW_LIB_DIR/<x>.sh"` (needs `+x`), but `lib/resolver.sh`
and `lib/outcome.sh` are committed **mode 100644** (`git ls-files -s` confirms — not a worktree
glitch). `lib/ask.sh` is the lone `exec`-style verb at 100755, which is why it survives. The
dispatch substrate was *unrunnable from the CLI for its entire existence* — it only works by
calling `python3 lib/*.py` directly, which no caller does. **This is the concrete reason the
orchestrator never dispatched, and the fix is one line.**

## Findings (final)

1. **F1 — Orchestrator never dispatched.** [verified — now: 1 dispatch, enriched 100%]
2. **F2 — ~30 substrate tasks exist ahead of a working spine.** [verified]
3. **F3 — The spine works end-to-end with ZERO new code.** [verified live — Spike 2]
4. **F4 — Isolation granularity is per-task, never per-arc.** [converged — operator]
5. **F5 — Worktree/merge-back work is parked, not wasted** (eventual heavy-lane backend). [converged]
6. **F6 — `exec`-style fw verbs (`resolver`, `outcome`, `pause`) are broken** by committed 100644
   perms → `Permission denied`. The keystone bug. [verified — `git ls-files -s`]
7. **F7 — Default runtime down:** ollama-loop/triage workflows target litellm `:4000` (refused);
   TermLink path is the working lane. [verified — Spike 1]

## Backlog triage (lightweight, by category)

- **Critical-path (do now):** the exec-bit fix (F6) + a real *caller* that invokes `fw resolver
  run` (T-1774 is the CLI; what's missing is something that *calls* it on a real task).
- **Runtime enablement (next):** bring up litellm `:4000` OR default more workflows to TermLink
  (F7) so triage/research lanes work, not just `default`.
- **Defer (until the spine is used in anger):** all Watchtower panels (T-1792-1807), outcome-
  quality/workflow-coverage panels, multi-LLM cost-aware routing (T-1637), peer-consult
  (T-1818-21).
- **Reframe (not kill):** `fw orchestrator improve` (v2 self-improvement) stays a stub until v1
  actually runs a workload.

## Recommendation (final)

**GO.** The orchestrator spine is real and *proven live* (Enriched 1/1) — the problem was never
construction; it was that the CLI was unrunnable (F6) and nothing ever called it. First build
slice is tiny and concrete:

1. **Slice 1 (keystone, ~1 line):** `chmod +x` the `exec`-style `lib/*.sh` (or switch `bin/fw`
   to `bash "$FW_LIB_DIR/…"`), restoring `fw resolver` / `fw outcome` / `fw pause`. Pin with a
   test asserting every `exec "$FW_LIB_DIR/*.sh"` target is executable. → unblocks the CLI.
2. **Slice 2:** a real caller — dispatch one genuine task (not a probe) via `fw resolver run` and
   confirm a clean outcome.
3. **Slice 3 (runtime):** litellm `:4000` up, or repoint triage/research workflows to TermLink.

Autonomous queue-picking (IW-4) and all panels remain deferred. The inception delivered its
question: the spine exists, works, and the gap was a one-line perms bug + no caller.
