#!/bin/bash
# Continuous-run counters (T-3169, arc-012 S3).
#
# `.continuous-mode.yaml` carries TWO ceilings, counted in different units:
#
#   current_iteration / max_iterations  — SESSIONS. Advanced by SessionStart
#       (agents/context/inject-next-directive.py). Bounds how many context
#       windows one run may consume.
#   tasks_completed   / max_tasks       — TASKS. Advanced here, on the
#       work-completed transition. Bounds how much WORK one run may do.
#
# They are not interchangeable and neither substitutes for the other. Before
# T-3164 the two were the same number by accident, because a session could only
# take one turn and the run advanced a window per unit of work; `max_iterations: 5`
# therefore meant "five units of work" AND "five 285K windows" at once. With a Stop
# hook driving turns inside one window, many tasks now fit in a single session, and
# the session counter can no longer see any of them. The operator reasons in tasks;
# the budget is spent in sessions. Both get a ceiling.
#
# Part of: Agentic Engineering Framework — arc-012 (continuous-run)

# fw_continuous_note_task_completed <task_id> [project_root]
#
# Increment tasks_completed when the loop is ARMED, once per task id. No-op — and
# silent — when continuous mode is off, when the state file is missing or
# unreadable, or when python3/pyyaml are unavailable. This runs on the completion
# path of every task in the project, so it must never fail a close.
fw_continuous_note_task_completed() {
    local task_id="$1"
    local root="${2:-${PROJECT_ROOT:-$(pwd)}}"
    local state="${root}/.context/working/.continuous-mode.yaml"

    [ -n "$task_id" ] || return 0
    [ -f "$state" ] || return 0
    command -v python3 >/dev/null 2>&1 || return 0

    python3 - "$state" "$task_id" <<'PY' 2>/dev/null || true
import sys

try:
    import yaml
except ImportError:
    raise SystemExit(0)

state_path, task_id = sys.argv[1], sys.argv[2]

try:
    with open(state_path) as f:
        state = yaml.safe_load(f)
except Exception:
    raise SystemExit(0)

if not isinstance(state, dict):
    raise SystemExit(0)

# Disarmed means disarmed: an ordinary session's completions are not loop progress,
# and counting them would make every close look like the loop doing work.
if state.get("enabled") is not True:
    raise SystemExit(0)

seen = state.get("completed_task_ids")
if not isinstance(seen, list):
    seen = []

# Idempotent per task id. `fw task update --status work-completed` is re-runnable
# (partial-complete tasks come back through it after the human ticks their ACs),
# and a ceiling that double-counts one task would end a run early for no reason.
if task_id in seen:
    raise SystemExit(0)

seen.append(task_id)
state["completed_task_ids"] = seen

try:
    count = int(state.get("tasks_completed") or 0)
except (TypeError, ValueError):
    count = 0
state["tasks_completed"] = count + 1

tmp = state_path + ".tmp"
with open(tmp, "w") as f:
    yaml.safe_dump(state, f, default_flow_style=False, sort_keys=False)

import os
os.replace(tmp, state_path)
PY
}
