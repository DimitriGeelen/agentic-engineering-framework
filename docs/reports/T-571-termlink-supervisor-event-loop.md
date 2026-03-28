# T-571: TermLink Supervisor Event Loop — Research Artifact

## Problem Statement

**For whom:** Framework sessions dispatching parallel TermLink workers (via `fw termlink dispatch`).
**Why now:** Current dispatch is fire-and-forget with file-based polling. T-577 exposed timeout orphans. As TermLink dispatch becomes the preferred mechanism for heavy parallel work (T-630 universal task gate), reliability gaps become blocking.

**The gap:** No supervisor process monitors dispatched workers. A worker can crash, hang, or orphan without the dispatcher knowing until a hard timeout expires (600s default). There is no heartbeat, no graceful shutdown signal, and no crash recovery.

## Current Dispatch Flow

1. `fw termlink dispatch --name X --prompt P --task T-XXX`
2. `termlink spawn --name X --wait` opens a real terminal session
3. `termlink pty inject X` sends a bash script containing `claude -p "$PROMPT"`
4. Worker runs, writes result to `/tmp/tl-dispatch/X/result.md`
5. Worker emits `termlink event emit X worker.done` with exit code
6. `fw termlink wait --name X` calls `termlink event wait` (fast path), falls back to 2s file polling

**Failure modes:**
- Worker crash before `event emit` → no done signal → waits until hard timeout
- Worker hang (infinite loop in claude) → indistinguishable from "still working"
- Timeout orphan (T-577) → process survives session deregistration, invisible
- No progress signal → dispatcher has zero visibility during execution

## Available TermLink Primitives

| Primitive | Purpose | Reliability |
|-----------|---------|-------------|
| `event emit/wait/poll` | Pub-sub signaling between sessions | High, <10ms |
| `event broadcast` | Fan-out to all listeners | High |
| `discover --tag X --json` | Find sessions by tag | Immediate |
| `status <session> --json` | Session health/state | Immediate |
| `interact <session> <cmd> --json` | Sync command execution | Blocking, reliable |
| `pty output <session>` | Read terminal buffer | Non-blocking |
| `signal <session> SIGTERM` | Send OS signal to session | Immediate |

**Key insight:** All primitives needed for a supervisor exist individually. They are not orchestrated into a loop.

## Spike 1: Supervisor Architecture Options

### Option A: Event-Driven Supervisor Loop (bash)

A bash script that:
1. Maintains a worker registry (name → PID → task → start_time)
2. Runs an event loop: `while true; do ... sleep 2; done`
3. Each tick: `termlink discover --tag $TASK --json` to find active workers
4. Checks `termlink status $worker --json` for each worker (alive/dead)
5. Listens for `worker.done` events via `event poll` (non-blocking)
6. Detects crash: session gone from discover + no done event → crash recovery
7. Detects hang: elapsed > threshold + no heartbeat → SIGTERM + restart or escalate

**Pros:** Uses existing bash infrastructure. No new language. Simple state machine.
**Cons:** Bash loops are fragile. No proper concurrency. `sleep 2` polling is coarse.

### Option B: Worker-Side Heartbeat Protocol

Workers emit periodic heartbeat events:
```bash
# Injected into dispatch script
while true; do
  termlink event emit $SESSION_NAME worker.heartbeat -p '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'
  sleep 30
done &
HEARTBEAT_PID=$!
```

Supervisor checks: "last heartbeat > 60s ago" → worker presumed dead.

**Pros:** Push-based, no polling. Workers self-report.
**Cons:** Requires modifying the dispatch injection script. Background process in worker shell adds complexity. If `claude -p` consumes all CPU, heartbeat process may starve.

### Option C: TermLink Native Supervisor (Rust feature request)

TermLink itself manages worker lifecycles:
```
termlink supervisor start --tag task-T-571
termlink supervisor status
termlink supervisor shutdown --graceful
```

**Pros:** Proper process management, crash detection built-in, no bash fragility.
**Cons:** Requires TermLink code changes. Not available today. Violates "use what exists" principle.

## Spike 2: Crash Detection Strategies

| Strategy | Detection Latency | False Positive Risk | Implementation |
|----------|------------------|--------------------|----|
| Session disappears from `discover` | 2-4s (poll interval) | Low | Bash, existing primitives |
| Heartbeat timeout | 30-60s | Medium (CPU starvation) | Bash + worker modification |
| `termlink status` exit code | 2-4s (poll interval) | Low | Bash, existing primitives |
| `pty output` check for error strings | 2-4s | High (regex matching) | Fragile, not recommended |

**Recommendation:** Session-gone detection via `discover` is the simplest and most reliable. Heartbeat adds defense-in-depth for hung (not crashed) workers.

## Spike 3: Graceful Shutdown Protocol

Current: no graceful shutdown. Workers run until done or timeout-killed.

**Proposed protocol:**
1. Supervisor broadcasts `supervisor.shutdown` event
2. Workers check for shutdown event periodically (or register trap)
3. Workers write partial results, emit `worker.done` with `status: interrupted`
4. Supervisor waits N seconds, then `termlink signal $worker SIGTERM`
5. After 5 more seconds, `termlink signal $worker SIGKILL` if still alive

**Complexity:** Medium. Requires both supervisor and worker-side changes.

## Assumption Testing

- **A1:** TermLink event primitives are reliable enough for supervision. **VALIDATED** — event emit/wait/poll work, <10ms latency. Used in current dispatch for `worker.done`.
- **A2:** Session disappearance is detectable. **VALIDATED** — `termlink discover` and `termlink status` both report session state.
- **A3:** Worker-side heartbeat is feasible. **PARTIALLY VALIDATED** — background process works but CPU starvation under heavy `claude -p` load is untested.
- **A4:** The supervisor loop is needed now. **NOT VALIDATED** — current dispatch handles 1-3 workers adequately. The framework rarely dispatches >3 workers in practice. The problem is real but not urgent.

## Recommendation: CONDITIONAL GO

**GO for Phase 1** (lightweight supervisor using existing primitives):
- Add crash detection to `fw termlink wait` via `discover` polling (Option A, minimal)
- Add graceful shutdown via `signal SIGTERM` when dispatcher is interrupted
- No heartbeat protocol yet (Option B deferred — adds complexity without proven need)

**DEFER Phase 2** (full supervisor event loop) until:
- TermLink dispatch becomes the primary dispatch mechanism (currently optional)
- >5 parallel workers are dispatched regularly (current max observed: 3)
- A crash goes undetected and causes data loss (no incidents yet)

**NO-GO for Option C** (Rust-level supervisor) — premature; bash-level supervision suffices for current scale.

## Evidence Summary

| Evidence | Source | Implication |
|----------|--------|-------------|
| Max 3 parallel workers observed | T-522 session logs | Supervisor complexity unjustified at current scale |
| T-577 orphan bug | Production incident | Crash detection needed, but dispatch watchdog already mitigates |
| Event system works | TermLink test suite (264 tests) | Primitives are reliable building blocks |
| `fw termlink cleanup` exists | agents/termlink/termlink.sh | Orphan cleanup is already partially automated |
| No data loss from dispatch failures | Episodic memory search | Problem is annoying, not critical |
