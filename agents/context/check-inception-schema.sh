#!/bin/bash
# T-2188: inception frontmatter schema validation hook (bash wrapper for Python).
# The fw hook dispatcher loads .sh files; logic lives in check-inception-schema.py.
exec python3 "$(dirname "$0")/check-inception-schema.py" "$@"
