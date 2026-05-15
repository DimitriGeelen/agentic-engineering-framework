# T-1775 — ollama-loop worker primitive build report

**Status:** Agent ACs complete. ollama-loop route is the 2nd `_DISPATCHERS` entry.
**Anchor:** T-1687 (orchestrator-rethink arc)
**Predecessors:** T-1700 (litellm proxy + env redirection pattern), T-1773 (spawn driver), T-1774 (`fw resolver run` CLI).

---

## What v1 ships

| Deliverable | File | LOC |
|-------------|------|-----|
| Worker primitive | `lib/ollama_loop.py` | 142 |
| Spawn driver route | `lib/spawn.py:_spawn_ollama_loop` + `_DISPATCHERS["ollama-loop"]` | +56 |
| Unit tests (worker) | `tests/unit/test_ollama_loop.py` | 13 tests |
| Unit tests (spawn extension) | `tests/unit/test_spawn.py` (+3) | 3 tests |

After this build: `_DISPATCHERS = {"pi": _spawn_pi, "ollama-loop": _spawn_ollama_loop}`.
Two of the four worker_kinds are wired. `TermLink` and `Task` remain
deferred.

## Sketch-vs-implementation

The original plan was to mirror PiWorker exactly. Five small deviations:

| # | Sketch | Built | Why |
|---|--------|-------|-----|
| 1 | `prompt()` reusable per instance | Single-shot — raises on second call | `claude -p` reads prompt as positional argv, not stdin. Re-prompting on the same instance would mean a second Popen, which is what creating a new worker already does. Single-shot pins the contract. |
| 2 | stdin pipe for prompt | `stdin=DEVNULL` | Same reason as above — claude -p never reads stdin. |
| 3 | Prompt via stdin write | Prompt in argv | Matches `claude -p "$PROMPT"` shell pattern at `agents/termlink/termlink.sh:714`. |
| 4 | Terminal event = `agent.done` (PiWorker convention) | Terminal event = `type=result` with `is_error: bool` | claude -p's stream-json contract uses `type=result` as the terminal event; mapping it to PiWorker's `agent.done` would have been protocol-mixing. |
| 5 | env via env arg only | env arg + os.environ overlay | Without inheriting os.environ, the spawned `claude` couldn't find PATH/HOME; with full inheritance the dispatch host's tokens leak. The merge: os.environ first, envelope `env` overrides specific keys. |

## Outcome contract

Identical to pi route — `spawn_dispatch(envelope)` returns:

```python
{
  "status": "success" | "error",
  "events_count": int,
  "events_path": "<blob_dir>/events.jsonl",
  "terminal_event": {"type": "result", "is_error": bool, ...} | None,
}
```

Side effects:
- `<blob_dir>/events.jsonl` — one stream-json event per line
- `.context/dispatches.jsonl` row matching `dispatch_id` rewritten with `outcome=success|error` and `events_count`

## Tests (29/29 passing in 0.15s)

| Test | Pins |
|------|------|
| module_import_does_not_spawn_claude | Lazy: import doesn't subprocess |
| prompt_yields_events_until_result | Terminal `type=result` ends iteration |
| terminal_result_is_error_true_still_ends | Error terminal still ends iteration |
| tools_flag_built_from_allowed_tools | `--tools t1,t2,t3` argv shape |
| no_tools_flag_when_allowed_tools_empty | Empty list → flag omitted |
| env_merging_envelope_overrides_os_environ | os.environ + overlay precedence |
| argv_carries_prompt_model_streamjson_verbose | `-p PROMPT --model X --output-format stream-json --verbose` |
| unicode_separators_do_not_split_events | U+2028/U+2029 inside JSON strings |
| malformed_json_lines_are_skipped | Invalid lines don't crash iteration |
| close_idempotent | Second close() is a no-op |
| close_kills_hung_process | Wait timeout → kill, then second wait |
| context_manager_closes_on_exit | `with` block clears proc |
| prompt_is_single_shot | Second prompt() call raises RuntimeError |
| ollama_loop_route_success (spawn) | Driver routes ollama-loop, success path |
| ollama_loop_route_error_terminal (spawn) | is_error=True → status=error |
| ollama_loop_route_passes_env_and_tools (spawn) | Envelope env + tools forwarded |

Existing pi route tests + spawn deferral matrix updated (TermLink/Task only)
and continue to pass.

## Architectural decisions

### `claude -p` is single-shot per worker, prompt via argv

Mirrors the existing shell pattern at `agents/termlink/termlink.sh:714`. The
alternative (long-lived `claude` process with multi-turn protocol) would
duplicate what PiWorker already does for pi — and `claude -p` does not have
that mode. Pinning single-shot is honest about what the binary is; spawning
a new worker per dispatch is the natural unit of work for this primitive
anyway.

### Terminal event is `type=result`, not `agent.done`

claude -p's stream-json contract uses `result` as terminal. The spawn driver
route maps `terminal["is_error"]` to status (`error` if true). This means
the outcome contract stays unified across worker_kinds — the caller doesn't
care that pi calls it `agent.done` and claude -p calls it `result`; both
populate `terminal_event` in the outcome dict and the driver applies the
right error mapping per route.

### env merge: os.environ first, envelope env overrides

Without os.environ inheritance, claude can't find PATH/HOME. With full
inheritance + no overlay, ANTHROPIC_BASE_URL/KEY won't be redirected. The
right shape is: take everything from os.environ, then let the workflow
override specific keys. Tests pin the precedence (`OLLAMA_LOOP_TEST_OVERRIDE`
old → new) and the keep behavior (`OLLAMA_LOOP_TEST_KEEP`).

### Tools flag formatted as comma-joined argv pair

`--tools Read,Bash,Grep` matches existing `agents/termlink/termlink.sh`
pattern and claude -p's CLI contract. Empty list = flag omitted (default
catalogue applies). No validation of tool names — claude -p validates against
its built-in set, same as termlink.sh.

## Forward-look

Two NotImplementedError stubs remain in `_DISPATCHERS`:

| Worker kind | Current state | Next step |
|-------------|--------------|-----------|
| `TermLink` | NotImplementedError | A thin adapter onto `fw termlink dispatch`. Different shape: TermLink is fire-and-forget with its own event surface. May not need a Python primitive at all — could route via shell exec. |
| `Task` | NotImplementedError | Per ADR-0002, the Task tool is an inline path that should NOT reach a spawn driver. The right resolution may be to remove `Task` from VALID_WORKER_KINDS rather than build a route. |

The orchestrator arc's headline mechanic is now fully exercised end-to-end
for two workers. T-1700 #H1+#H2 (litellm install + login + smoke) is the
remaining gate to live observation of the ollama-loop route — Agent ACs
ship this build.
