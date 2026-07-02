# RESOLVED by T-2495 (2026-07-02)

**Original issue:** update-task.sh derives sys.path from __file__ inside stdin heredoc, causing ModuleNotFoundError in `fw inception decide` finalization.

**Resolution:** T-2495 applied the exact fix recommended in this pickup - prefer FRAMEWORK_ROOT env over __file__ chain in the Python heredoc at agents/task-create/update-task.sh line ~578.

**Verified:** Fix is in place and working as of 2026-07-02.

---

# Original pickup content:

# BUG + FIX: update-task.sh derives sys.path from __file__ inside a `python3 -` stdin heredoc

**Source:** /opt/termlink (vendored AEF consumer), T-2304 | **Priority:** P1 (breaks `fw inception decide` finalization) | **Date:** 2026-07-02

## Symptom
`fw inception decide <T-XXX> go` records the GO but then crashes finalization with:
```
ModuleNotFoundError: No module named 'lib.inception_decisions'
```
The decision is written but the task is left STUCK at `started-work` in `active/`
(never promoted to `work-completed`). Recovery required a manual `fw inception sweep`.

## Root cause
`agents/task-create/update-task.sh` (~line 578) runs its inception-scope-trace
Python via a stdin heredoc: `py_output=$(python3 - "$TASK_FILE" "$PROJECT_ROOT" <<'PYEOF'`.
When Python reads a script from stdin, `__file__ == "<stdin>"`. The block then does:
```python
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
```
`os.path.abspath("<stdin>")` resolves against CWD and the triple-dirname chain climbs
to `/`, so the framework root (which contains `lib/`) never lands on `sys.path` and
`from lib.inception_decisions import …` fails. The sibling
`agents/context/check-inception-decisions.py` is NOT affected — it runs as a real
file and uses `Path(__file__).resolve().parent` correctly.

## Fix (verified in the /opt/termlink vendored copy — `import-ok`)
Pass the framework root via an explicit env var (`FRAMEWORK_ROOT`, already exported by
`fw`) and prefer it; fall back to the `__file__` chain only when run as a real file.

### Before (buggy), update-task.sh ~line 578:
```bash
    py_output=$(python3 - "$TASK_FILE" "$PROJECT_ROOT" <<'PYEOF'
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
```

### After (fixed):
```bash
    py_output=$(FRAMEWORK_ROOT="$FRAMEWORK_ROOT" python3 - "$TASK_FILE" "$PROJECT_ROOT" <<'PYEOF'
import sys, os
# T-2304: when this runs via `python3 -` (stdin heredoc), __file__ == "<stdin>",
# so the abspath/dirname chain climbs to "/" and `lib.inception_decisions` never
# lands on sys.path (ModuleNotFoundError). Prefer the explicit FRAMEWORK_ROOT env
# (which contains lib/); fall back to the __file__ chain only when run as a real file.
sys.path.insert(0, os.environ.get("FRAMEWORK_ROOT") or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
```
Only two lines change: (1) prefix `FRAMEWORK_ROOT="$FRAMEWORK_ROOT"` on the `python3 -`
invocation, (2) replace the `sys.path.insert(...)` line with the env-preferring form.

## Regression proof (run from the AEF repo root after applying)
```bash
FRAMEWORK_ROOT=. python3 -c 'import sys,os; sys.path.insert(0, os.environ["FRAMEWORK_ROOT"]); import lib.inception_decisions; print("import-ok")'
```
Expected: `import-ok` (no ModuleNotFoundError).

## General learning (registered as PL-233 in /opt/termlink)
Never derive `sys.path` from `__file__` inside a `python3 -` stdin heredoc — `__file__`
is the literal `"<stdin>"`. Pass the root via env/argv and `sys.path.insert` that.

## Note for AEF maintainer
Please apply under an AEF task + commit to master (or the current feature branch as
appropriate). The /opt/termlink `.agentic-framework/` vendored copy already carries the
fix on-disk (it is gitignored there), so consumers stay unblocked until the next vendor sync.
