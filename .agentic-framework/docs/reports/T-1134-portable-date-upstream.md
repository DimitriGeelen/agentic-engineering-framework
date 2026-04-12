# T-1134 — Upstream Portable Date Helpers from 010-termlink

## Source

Pickup P-015 from 010-termlink (patch-delivery type, rejected by pickup processor
because `patch-delivery` is not a valid envelope type — only bug-report, learning,
feature-proposal, pattern are accepted).

## Patch 1: Portable date helpers

**Problem:** Framework uses `date -d` (GNU-only) in 3 files:
- `agents/context/checkpoint.sh` — budget age calculation
- `agents/context/lib/episodic.sh` — timestamp parsing for episodic generation
- `metrics.sh` — session age calculation

On macOS (BSD date), `date -d` fails silently or errors.

**Proposed fix (from 010-termlink):**
- Add `_date_to_epoch()` and `_days_ago_epoch()` to `lib/compat.sh`
- Fallback chain: GNU date → BSD date → python3
- Replace all 6 `date -d` calls

**Assessment:** Sound approach. lib/compat.sh is already the portability layer.
The fallback chain covers Linux (GNU), macOS (BSD), and any system with python3.

## Patch 2: Episodic verification

**Problem:** `generate-episodic` can fail silently — no check that the output
file was actually created. Audit flags episodic gaps but only on cron/manual run.

**Proposed fix (from 010-termlink):**
- After `generate-episodic` in `update-task.sh`, check file exists
- Print WARNING with manual recovery command if missing
- Non-blocking (doesn't prevent task completion)

**Assessment:** Low-risk, high-value. Catches T-1132-class failures at the
point of action rather than later in audit.

## Cross-References

- T-1132 (pickup from ring20-manager): reports same episodic verification gap
- T-1133 (pickup from ring20-manager): reports same GNU date portability issue
- P-016 (010-termlink): session init concerns check (separate scope, related)
- D-004: Portability constitutional directive
