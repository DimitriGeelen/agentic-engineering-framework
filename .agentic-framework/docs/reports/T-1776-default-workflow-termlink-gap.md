# T-1776 — default workflow declares TermLink, spawn driver doesn't route it

**Status:** Discovery filed; architectural choice belongs to human.
**Anchor:** T-1687 (orchestrator-rethink arc)
**Predecessors:** T-1773 (spawn driver), T-1775 (ollama-loop route).
**Discovered while:** auditing remaining NotImplementedError stubs after T-1775.

---

## The gap

`.context/project/workflows/default.yaml:2` declares `worker_kind: TermLink`.

The Q12 fallback contract (`lib/resolver.py:load_workflow`) means: any
`task_type` without its own workflow falls back to `default.yaml`. After
T-1773+T-1775, the spawn driver routes `pi` and `ollama-loop`. It does NOT
route `TermLink` — it raises `NotImplementedError` with the deferral message.

End-to-end consequence:

```
$ fw resolver run T-XXX some-unknown-task-type
  → load_workflow falls back to default.yaml
  → envelope.worker_kind = "TermLink"
  → spawn_dispatch raises NotImplementedError
```

This means the most-default path through the substrate is currently a trap.
Documented dispatches (`cheap-research`, `ollama-research`) work; ad-hoc
dispatches via `fw resolver run T-XXX <novel_type>` would crash.

## Why this happened

The resolver+spawn split (T-1689 + T-1773) was designed when `fw termlink
dispatch` was the only dispatch surface. `worker_kind: TermLink` was the
honest description of "this dispatch goes to the TermLink subsystem". The
spawn driver added a SECOND dispatch surface (`pi`, `ollama-loop`), but the
fallback workflow was not updated to point at one of those.

## Three resolution options

### A) Build a TermLink Python primitive

Add `lib/termlink_worker.py:TermLinkWorker` mirroring `PiWorker`/`OllamaLoopWorker`,
wrapping `fw termlink dispatch` as a subprocess. Add `_spawn_termlink` to
spawn.py and register in `_DISPATCHERS`.

**Cost:** ~150 LOC + ~10 unit tests. Mirrors the OllamaLoopWorker shape.
**Pro:** Unified `fw resolver run` works for all workflows; default fallback unbroken.
**Con:** Adds a layer over an already-mature dispatch surface (`fw termlink
dispatch`). Two ways to dispatch via TermLink: directly via the CLI, or
indirectly via the spawn driver.

### B) Shell adapter (no Python primitive)

Make `_spawn_termlink` a thin shell exec: spawn `fw termlink dispatch`,
poll its result.jsonl, translate to outcome dict.

**Cost:** ~80 LOC + ~5 tests.
**Pro:** Smallest delta. Reuses all existing TermLink machinery.
**Con:** Mixed paradigm — pi/ollama-loop are Python primitives, TermLink is
a shell wrapper. Outcome translation is fragile (depends on result.jsonl
schema, which evolves).

### C) Change default.yaml's worker_kind

Set `default.yaml:2` to `worker_kind: ollama-loop` (cheapest, requires
litellm running) OR `worker_kind: pi` (requires pi binary).

**Cost:** 1-line workflow edit.
**Pro:** Trivial. No spawn-driver code added.
**Con:** Adds a hard dependency to default fallback. If neither litellm nor
pi is set up on the host, default-fallback dispatches fail with a clearer
error ("provider not configured") but the substrate becomes
config-dependent.

## Recommendation

**Option C with `ollama-loop`** seems lowest-cost and most aligned with the
arc direction (orchestrator routes through cheap local inference by
default). It keeps the spawn driver clean (no TermLink shell adapter) and
means `default.yaml` requires litellm only when actually invoked. The
`fw doctor` checks already gate on workflow markers, so a missing litellm
proxy surfaces as a doctor warning rather than a runtime crash.

The `worker_kind: TermLink` decision then becomes a per-workflow opt-in for
heavyweight, multi-step dispatches that need TermLink's session machinery.
That's an honest separation: TermLink is a heavyweight surface accessed via
its own CLI; resolver+spawn handles lightweight dispatch via local primitives.

If the human prefers Option A or B, the build is well-scoped — T-1775
established the OllamaLoopWorker pattern that TermLinkWorker would follow.

## Forward-look

This filing does not change code. The current state is the safest one — the
NotImplementedError raise is loud and points at T-1773. No silent failure.

The next session can:
- Confirm the direction (A/B/C) on this task's Human #H1
- File a build task for the chosen direction (or close this DEFER if C)
- After resolution: extend `tests/unit/test_resolver_run.py` with a
  default-fallback case that proves the gap is closed
