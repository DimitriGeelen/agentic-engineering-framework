# T-792: TermLink Dispatch CWD Resolution

## Problem

`fw termlink dispatch` workers start in `/tmp/tl-dispatch/<name>/`. Framework hooks resolve PROJECT_ROOT from CWD. Wrong CWD → wrong project → cascading failures.

**Evidence:** T-842 test-suite worker (meta.json shows project=/opt/999-Agentic-Engineering-Framework) resolved PROJECT_ROOT to `/opt/openclaw-evaluation`. Three cascading failures: wrong project boundary, stale budget gate (critical at 37%), dispatch counter at 11.

## Spike A: How does `fw termlink dispatch` currently set CWD?

**Finding:** `termlink.sh:297-322` — `run.sh` does `cd "$PROJECT_DIR"` before `claude -p`. The `PROJECT_DIR` variable comes from `--project` flag or `$(pwd)`. The cd happens BEFORE claude starts, so claude's CWD should be correct.

**Problem:** Despite `cd` working for claude's CWD, hooks resolve PROJECT_ROOT via `lib/paths.sh` line 33-34:
```bash
PROJECT_ROOT="$(git -C "$FRAMEWORK_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$FRAMEWORK_ROOT")"
```
FRAMEWORK_ROOT is derived from the hook script's location (bin/fw → repo root). This should resolve correctly from CWD. The mystery is why the worker got openclaw instead.

**Hypothesis:** The TermLink session may inherit environment from the parent claude session, including stale FRAMEWORK_ROOT or PROJECT_ROOT values. OR the `cd` command failed silently and claude started in the TermLink session's default CWD.

## Spike B: Does `PROJECT_ROOT=X claude -p` propagate to hooks?

**Finding:** Yes. `lib/paths.sh` line 33 checks `[[ -z "${PROJECT_ROOT:-}" ]]` — if PROJECT_ROOT is already set in the environment, it's used directly without git resolution.

**This is the fix.** Setting `PROJECT_ROOT` in `run.sh` before launching claude will propagate to all hooks via environment inheritance. No hook changes needed.

## Spike C: Recommended fix

In `termlink.sh:297-322` (`run.sh` template), add:
```bash
export PROJECT_ROOT="$PROJECT_DIR"
export FRAMEWORK_ROOT="$PROJECT_DIR"  # for framework repo itself
```

Before the `claude -p` call. This ensures hooks skip git resolution entirely.

For consumer projects where FRAMEWORK_ROOT ≠ PROJECT_ROOT:
```bash
export PROJECT_ROOT="$PROJECT_DIR"
if [ -d "$PROJECT_DIR/.agentic-framework" ]; then
    export FRAMEWORK_ROOT="$PROJECT_DIR/.agentic-framework"
fi
```

## Recommendation

**GO** — Framework-side fix, no TermLink binary changes needed.

1. Set `PROJECT_ROOT` and `FRAMEWORK_ROOT` env vars in `run.sh` before launching `claude -p`
2. Add `|| exit 1` after `cd "$PROJECT_DIR"` to fail fast if cd fails
3. Clear stale env vars (`unset DISPATCH_DIR` etc.) that might leak from parent

**Rationale:** The env var approach is:
- Zero-cost (no new dependencies)
- Works for both framework repo and consumer projects
- Already supported by `lib/paths.sh` (the guard is there)
- Survives any future changes to git resolution logic

**Risk:** Low — env vars are the standard mechanism for this. The guard in paths.sh has been there since the beginning.
