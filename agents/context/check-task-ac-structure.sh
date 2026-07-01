#!/bin/bash
# T-2420: task AC structure validation hook (bash wrapper).
# The fw hook dispatcher (bin/fw) loads .sh files; actual logic in check-task-ac-structure.py.
exec python3 "$(dirname "$0")/check-task-ac-structure.py" "$@"
