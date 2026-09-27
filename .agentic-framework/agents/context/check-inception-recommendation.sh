#!/bin/bash
# T-2205: PreToolUse Write/Edit hook — refuse save when inception task has
# template-only ## Recommendation block under $CLAUDECODE=1.
#
# Bash wrapper that exec's the Python implementation (same pattern as
# check-arc-id.sh / check-inception-decisions.sh).
exec python3 "$(dirname "$0")/check-inception-recommendation.py" "$@"
