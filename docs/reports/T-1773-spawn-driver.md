# T-1773 — spawn-side dispatch driver build report

**Status:** Agent ACs complete (pi route only). Other worker_kinds explicitly deferred.
**Anchor:** T-1687 (orchestrator-rethink arc)
**Predecessors:** T-1700 (litellm), T-1701 (pi RPC) — both shipped worker primitives but stopped at the worker.

---

## What v1 ships

| Deliverable | File | LOC |
|-------------|------|-----|
| Spawn primitive (pi-only routing) | `lib/spawn.py` | 175 |
| Unit tests (mocked PiWorker) | `tests/unit/test_spawn.py` | 219 |

Resolver is **untouched** — `lib/resolver.py` does not gain a `provider` field
in the envelope. Pi route re-reads the workflow YAML to obtain it; this keeps
the envelope schema worker-kind-agnostic. The cost is one extra YAML load per
pi dispatch, an acceptable trade for not polluting the envelope contract with
a pi-specific field.

## What v1 does NOT ship (explicit deferral)

| Worker kind | v1 behavior | Reason |
|-------------|------------|--------|
| `pi` | Routes to `_spawn_pi` | The only worker primitive that exists (PiWorker, T-1701) |
| `ollama-loop` | Raises `NotImplementedError` | No primitive yet — claude-p with redirected env vars is the current pattern but it's untested as a callable from spawn driver |
| `TermLink` | Raises `NotImplementedError` | Has its own dispatch surface (`fw termlink dispatch`); needs a thin adapter |
| `Task` | Raises `NotImplementedError` | Inline path — should not reach a spawn driver per ADR-0002 |

CLI integration (`fw resolver run` or `fw orchestrator dispatch`) is also
deferred. v1 ships a tested primitive callable from Python, not a half-wired
CLI. The Human AC #H1 documents the manual one-liner.

## Outcome contract

`spawn_dispatch(envelope)` returns:

```python
{
  "status": "success" | "error",
  "events_count": int,
  "events_path": "<blob_dir>/events.jsonl",
  "terminal_event": {"type": "agent.done"} | {"type": "error", ...} | None,
}
```

Side effects:
- `<blob_dir>/events.jsonl` populated with one event per line (JSONL)
- `.context/dispatches.jsonl` row matching `dispatch_id` rewritten with
  outcome=success|error and events_count

## update_outcome_row contract

Atomic via `tmp.write + os.replace` so a crash mid-rewrite leaves the original
file intact. Returns:
- `True` if a row was found and rewritten
- `False` if dispatch_id absent, log file missing, or no row matched

Malformed JSON lines in `dispatches.jsonl` are preserved verbatim (not dropped)
so historical corruption doesn't cascade.

## Tests (13/13 passing in 0.10s)

| Test | Pins |
|------|------|
| pi_route_success | events.jsonl populated, status=success on agent.done |
| pi_route_error_terminal | status=error on terminal error event, retryable carried |
| other_worker_kinds_raise_notimplemented | ollama-loop / TermLink / Task all raise with T-1773 in message |
| unknown_worker_kind_raises_spawnerror | typos surface as SpawnError, not silent |
| update_outcome_row_rewrites_match | targeted single-row rewrite |
| update_outcome_row_no_match_returns_false | safe no-op when ID absent |
| update_outcome_row_no_log_returns_false | safe no-op when log missing |
| update_outcome_row_empty_dispatch_id_returns_false | guards against empty IDs |
| module_imports_without_pi_on_path | PiWorker import deferred to handler |
| pi_route_uses_envelope_provider_when_present | envelope override path |
| pi_route_falls_back_to_workflow_provider | re-read workflow YAML on envelope miss |
| pi_route_missing_provider_raises_spawnerror | clear error when both absent |
| spawn_dispatch_finalises_outcome_row | end-to-end: dispatch → row outcome update |

## Architectural decisions

### `provider` resolution: envelope first, workflow fallback

Resolver's envelope omits `provider` because it's pi-specific. The spawn
driver checks envelope first (callers can override per-dispatch), falls back
to re-reading the workflow YAML. If both absent, raises SpawnError with a
clear message. This means the resolver stays clean and per-pi-call
overrides are still possible.

### Pi-only v1 routing

Three worker kinds raise `NotImplementedError` rather than silently falling
through. Each error message names T-1773 so future grep-for-deferral lands
correctly. Rejected: a generic "default" handler that wraps `subprocess.run`
— too generic, masks bugs.

### update_outcome_row preserves malformed lines

A bad line in `dispatches.jsonl` (corruption from a crash, manual edit) is
preserved verbatim during rewrite. Rejected: drop bad lines silently — would
mask data loss. Rejected: fail the rewrite — would block legitimate updates
indefinitely.

## Forward-look

When a second worker primitive matures, extend `_DISPATCHERS` rather than
rewrite. The natural next step is an `ollama-loop` primitive at
`lib/ollama_loop.py` (currently the loop is shell-only via env-var redirected
`claude -p`). Once that exists, T-1773's deferral can close.

CLI integration (`fw resolver run`) is a 30-line follow-up: add a `run`
subcommand to `lib/resolver.py:main` that builds the envelope (already
supported) and immediately calls `spawn.spawn_dispatch`. Single point of
divergence from existing `dispatch` command.
