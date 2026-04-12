# T-856: TermLink Dispatch Project Context

## Research Artifact (C-001)

**Task:** T-856
**Created:** 2026-04-05
**Status:** Complete

---

## Problem (as stated)

`fw termlink dispatch` spawns Claude workers in `/tmp/tl-dispatch/<name>/`. When the worker
uses any tool, framework PreToolUse hooks fire and try to find PROJECT_ROOT by walking up
from CWD. Since CWD is `/tmp/`, hooks either fail or find the wrong project.

Evidence cited: T-842 worker fully blocked, T-835 workers succeeded (research-only).

## Investigation

### T-792 already fixed this

Commit `305038d8` (2026-04-04T21:47:00+0200) — "T-792: Fix TermLink dispatch CWD — export PROJECT_ROOT in worker run.sh" — was committed **after** T-856 was created (2026-04-04T18:23:31Z).

The fix in `agents/termlink/termlink.sh` lines 297-308:

```bash
cd "$PROJECT_DIR" || { echo "FATAL: cd $PROJECT_DIR failed" > "$WDIR/stderr.log"; exit 1; }
export PROJECT_ROOT="$PROJECT_DIR"
if [ -d "$PROJECT_DIR/.agentic-framework" ]; then
    export FRAMEWORK_ROOT="$PROJECT_DIR/.agentic-framework"
else
    export FRAMEWORK_ROOT="$PROJECT_DIR"
fi
```

This runs inside `run.sh` **before** `claude -p` is launched (line 314). Since `claude -p` inherits env vars from its parent process, hooks get the correct PROJECT_ROOT.

### Why it works

1. `run.sh` sets CWD to `$PROJECT_DIR` (line 300) — `claude -p` starts in the correct directory
2. `run.sh` exports `PROJECT_ROOT` (line 302) — `lib/paths.sh` line 33 checks `if [[ -z "${PROJECT_ROOT:-}" ]]` and skips git resolution when the var is already set
3. `run.sh` exports `FRAMEWORK_ROOT` (lines 304-308) — hooks use this to find `lib/paths.sh` and other scripts
4. `claude -p` inherits all three: CWD, PROJECT_ROOT, FRAMEWORK_ROOT

### Remaining edge case

The only potential gap: `cmd_spawn` (line 89) spawns a tmux/terminal session without specifying CWD. Then `pty inject` sends the `run.sh` command. Between spawn and inject, the terminal is in whatever default CWD tmux gives it (typically `$HOME`). But this doesn't matter because `run.sh` does the `cd` before launching claude.

### Assumption validation

| # | Assumption | Result |
|---|-----------|--------|
| A1 | TermLink needs `--working-dir` flag | ❌ Not needed — `run.sh` handles CWD |
| A2 | `fw termlink dispatch` could create session with initial `cd` | ✅ It does this (via `run.sh`) |
| A3 | Claude Code `--cwd` flag | ❌ Does not exist, but not needed |
| A4 | `.framework.yaml` symlink workaround | ❌ Not needed — env var export is cleaner |

## Recommendation

**NO-GO** — T-792 already implemented the fix. The remaining task spikes would validate what's already working code.

### Suggested action
Close T-856 as superseded by T-792. The fix is in production (`agents/termlink/termlink.sh` lines 300-308).

### Evidence
- Commit `305038d8` exports PROJECT_ROOT and FRAMEWORK_ROOT before `claude -p` launch
- `lib/paths.sh:33` respects pre-set PROJECT_ROOT (no re-resolution)
- `claude -p` inherits env vars from parent process (standard Unix behavior)
- The T-842 blocking incident occurred before T-792's fix
