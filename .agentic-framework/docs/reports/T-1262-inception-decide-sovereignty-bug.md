# T-1262 — Watchtower inception decide blocked by CLAUDECODE inheritance

**Status:** Design note for build task T-1262. Root cause diagnosed in T-1260 Spike A.

---

## Symptom

After T-1259 shipped (commit `4589bc60`) adding a CLAUDECODE guard to `fw inception decide`, Watchtower's `/inception/T-XXX/decide` POST endpoint began failing silently for any project whose Watchtower instance was started from a Claude Code session.

## Root cause

`web/subprocess_utils.py:51` (pre-fix) passed the full parent environment to the fw subprocess:
```python
env={**os.environ, "PROJECT_ROOT": str(PROJECT_ROOT)},
```

When Flask runs under `fw serve` started inside a Claude Code terminal, `CLAUDECODE=1` is in `os.environ` and gets inherited. The T-1259 guard at `lib/inception.sh:204` sees `CLAUDECODE=1` and blocks — even though the request originated from a human clicking a button in Watchtower (the canonical human-decision surface per T-679).

## Fix (two layers)

### Layer 1 — explicit flag pass-through

`web/blueprints/inception.py` passes `--from-watchtower` to `fw inception decide`. `lib/inception.sh` parses the flag and exempts it from the CLAUDECODE guard:

```bash
if [ "${CLAUDECODE:-}" = "1" ] && [ "$i_am_human" = false ] && [ "$from_watchtower" = false ]; then
    # block agent invocation
fi
```

### Layer 2 — env strip (defence in depth)

`web/subprocess_utils.py:run_fw_command` now strips `CLAUDECODE` from the subprocess environment:
```python
subprocess_env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
subprocess_env["PROJECT_ROOT"] = str(PROJECT_ROOT)
```

Even if a future caller forgets `--from-watchtower`, the subprocess never sees `CLAUDECODE=1`.

## Decision block idempotency (bonus fix)

While fixing the CLAUDECODE path, T-1260 Spike D identified a related bug: the Decision block writer in `lib/inception.sh` was non-idempotent. Repeated Watchtower clicks (e.g., when the first call failed silently) accumulated duplicate `## Decision` sections in the task file. T-002 had 3+ such duplicates.

Fix: the writer now detects subsequent `## Decision` sections and swallows them, keeping only one — the one with the latest decision content. This also auto-heals legacy tasks with accumulated duplicates on next decide.

## Alternatives considered

**Option 2 — separate CLI command (`fw inception record-human-decision`):** rejected per task file decisions section. Adds friction to the one-click UX, contradicts T-679 which standardises on the `fw task review` surface.

**Option 3 — identity propagation via cookie:** out of scope. Would require flask-login adoption and session-aware subprocess invocation. Tracked separately as a future inception.

## Test coverage

- `tests/unit/lib_inception.bats` — new test: `CLAUDECODE=1 with --from-watchtower bypasses guard (T-1262)`
- Existing T-1259 tests still pass (3 CLAUDECODE tests at positions 13, 14, 15)
- Baseline: 15/15 inception unit tests passing at T-1259 completion

## Related

- **T-1259** — introduced the CLAUDECODE guard (shipped the regression)
- **T-1260** — Spike A identified the regression + Spike D the duplicate-block bug
- **T-679** — established Watchtower-as-human-surface convention
- **T-1223** — prior fix in inception decide flow (captured → started-work auto-transition)
