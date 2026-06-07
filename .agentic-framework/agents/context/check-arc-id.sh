#!/bin/bash
# T-1849: arc_id task-frontmatter validation hook (bash wrapper for Python).
# The fw hook dispatcher (bin/fw:5489) loads .sh files; the actual logic
# lives in check-arc-id.py to keep YAML parsing + arc resolution clean.
exec python3 "$(dirname "$0")/check-arc-id.py" "$@"
