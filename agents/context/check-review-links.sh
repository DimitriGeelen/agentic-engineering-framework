#!/bin/bash
# T-4624 (G-123): review-link allowlist on task-file Write/Edit (bash wrapper).
# The fw hook dispatcher loads .sh files; the logic lives in check-review-links.py.
exec python3 "$(dirname "$0")/check-review-links.py" "$@"
