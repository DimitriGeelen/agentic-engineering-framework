# T-1701 — pi RPC backend integration build report

**Status:** Agent ACs complete. Human ACs pending live install + smoke test.
**Anchor:** T-1687 (orchestrator-rethink arc)
**Predecessor inception:** T-1692 GO (`docs/reports/T-1692-pi-rpc-integration.md`)
**Sibling v1 build pattern:** T-1700 (litellm proxy adapter)

---

## What v1 ships (agent-deliverable)

| Deliverable | File | LOC |
|-------------|------|-----|
| PiWorker subprocess wrapper | `lib/pi_worker.py` | 124 |
| Workflow declaration | `.context/project/workflows/cheap-research.yaml` | 19 |
| Unit tests (mocked Popen) | `tests/unit/test_pi_worker.py` | 196 |

`fw doctor` pi-installed gate already shipped via T-1694; v1 verifies its
runtime behavior (WARN with workflow + missing binary) rather than re-wiring it.

`lib/resolver.py` is **untouched** — `pi` is already in `VALID_WORKER_KINDS`
(line 59) since T-1696. Resolver is dispatch-prep only; spawn-side execution is
the worker's responsibility.

## Sketch-vs-implementation diff

T-1692's wrapper sketch (RPC integration doc, §"lib/pi_worker.py — sketch") is
implemented faithfully. Deviations:

1. **`binary` parameter added** — defaults to `"pi"` from PATH, but tests mock
   the Popen call so test rigs do not need pi installed. Sketch hardcoded `"pi"`.
2. **`close()` returns the exit code** — sketch returned None. Caller can now
   distinguish clean exit (0), abnormal (>0), kill (-1).
3. **Malformed JSON line handling** — sketch raised on bad JSON; implementation
   skips silently per pi RPC contract (stdout is JSONL but contract permits
   non-fatal noise; killing the dispatch on a bad line would be too brittle).
4. **Context manager protocol** — `__enter__` / `__exit__` added so callers can
   use `with PiWorker(...) as w:` for guaranteed cleanup.
5. **Anti-readline pin** — Python's default `for line in self.proc.stdout`
   iterator splits only on `\n`, but the test
   `test_unicode_line_separators_do_not_split_events` pins this contract
   explicitly so a future "switch to readline-equivalent" refactor would break.

## Unit-test inventory

10 tests, all pass (`python3 -m pytest tests/unit/test_pi_worker.py -v`):

| Test | What it pins |
|------|--------------|
| `test_module_import_does_not_spawn_pi` | Import side-effect: must not call pi |
| `test_prompt_yields_events_until_agent_done` | Termination on `agent.done` |
| `test_prompt_terminates_on_error_event` | Termination on `error` |
| `test_prompt_writes_request_envelope_to_stdin` | Wire-format request shape |
| `test_unicode_line_separators_do_not_split_events` | Anti-readline regression |
| `test_prompt_skips_malformed_json_lines` | Protocol-noise tolerance |
| `test_close_handles_already_exited_subprocess` | Idempotent close |
| `test_close_kills_if_wait_times_out` | Watchdog kill on hang |
| `test_context_manager_closes_on_exit` | `with`-block cleanup |
| `test_request_id_increments_per_prompt` | Request ID hygiene |

## Verification snapshot

```
$ bin/fw resolver workflows | grep cheap-research
cheap-research.yaml             worker=pi         model=claude-3-5-sonnet-latest

$ bin/fw doctor 2>&1 | grep "worker_kind: pi"
WARN  [host] pi not installed; workflows declaring worker_kind: pi will fail

$ bin/fw doctor 2>&1 | grep -E "^\s*FAIL" | wc -l
0
```

## What's deferred to Human ACs

The four steps that require pi to be installed + authenticated cannot run
inside an autonomous agent session — `pi /login` is interactive (T-1692
caveat). Each is a Human AC in `T-1701`'s task body with copy-pasteable steps:

| # | Human AC | Reason it cannot be agentic |
|---|----------|------------------------------|
| H1 | `npm install -g @mariozechner/pi-coding-agent` | Host-level install, outside PROJECT_ROOT |
| H2 | `pi /login` to Anthropic Pro | Interactive auth flow, no headless equivalent |
| H3 | Live smoke dispatch (cost=0 verified) | Requires #H1 + #H2 |
| H4 | 429 retryable extraction via free-tier provider | Requires #H1 + a 429-emitting upstream |

A `tools/t1701-pi-smoke.py` harness is referenced in #H3/#H4 steps but not
shipped in v1 — the smoke script is meaningful only after the human runs
`#H1` + `#H2`, and v2 of this work will provide it alongside the spawn-side
dispatch driver. For v1, Human ACs document the manual one-liners directly so
nothing about the wrapper's correctness depends on a script that hasn't been
exercised against a real pi session.

## Install troubleshooting (if `npm install -g` fails)

| Symptom | Fix |
|---------|-----|
| `EACCES` on global install | `npm config set prefix ~/.npm-global` and add `~/.npm-global/bin` to PATH |
| Node ≥18 required | check `node -v`; install via nvm/nodesource if older |
| `pi: command not found` after install | check `npm config get prefix` matches a directory on PATH |
| `pi /login` hangs at "waiting for browser" | open the printed URL manually in any browser |

## Architecture forward-look (out of scope for v1)

After Human ACs close, the next on-arc consumer is the **spawn-side dispatch
driver** that reads a resolver envelope, instantiates `PiWorker`, streams
events to `.context/dispatch-blobs/<id>/events.jsonl`, and writes the final
`worker_kind: pi` row to `.context/dispatches.jsonl`. T-1700's claude-p
spawn driver was deferred for the same reason; both will likely converge into
a single `lib/spawn.py` module once two consumers exist (premature
abstraction trap avoided per CLAUDE.md).
