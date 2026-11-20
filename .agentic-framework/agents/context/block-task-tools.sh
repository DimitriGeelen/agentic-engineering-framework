#!/bin/bash
# Block Claude Code built-in task/todo tools — bypasses framework governance (T-1115/T-1117)
# The built-in TodoWrite/TaskCreate tools populate a parallel, ungoverned
# task list. Use fw work-on to create real framework tasks instead.

# Context-aware fw path (G-033/T-1182)
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$FRAMEWORK_ROOT/lib/paths.sh" 2>/dev/null || true
_fw() { _emit_user_command "$1" 2>/dev/null || printf 'bin/fw %s\n' "$1"; }  # printed-command builder (T-5304)

echo "BLOCKED: Claude Code built-in task/todo tools are disabled in this project." >&2
echo "These tools create ungoverned items outside the framework task system." >&2
echo "Use: $(_fw 'work-on "task name" --type build')  to create a real task." >&2
echo "Or:  $(_fw 'task create --name "task name"')  for more options." >&2
exit 2
