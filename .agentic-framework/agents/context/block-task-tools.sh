#!/bin/bash
# Block Claude Code built-in task/todo tools — bypasses framework governance (T-1115/T-1117)
# The built-in TodoWrite/TaskCreate tools populate a parallel, ungoverned
# task list. Use bin/fw work-on to create real framework tasks instead.
echo "BLOCKED: Claude Code built-in task/todo tools are disabled in this project." >&2
echo "These tools create ungoverned items outside the framework task system." >&2
echo "Use 'bin/fw work-on \"task name\" --type build' to create a real task." >&2
echo "Or 'bin/fw task create --name \"task name\"' for more options." >&2
exit 2
