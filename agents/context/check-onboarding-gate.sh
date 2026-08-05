#!/bin/bash
# T-2815: agent-unresolvable onboarding-task invariant hook (bash wrapper for Python).
# The fw hook dispatcher (bin/fw:5489) loads .sh files; the actual logic
# lives in check-onboarding-gate.py to keep parsing clean.
exec python3 "$(dirname "$0")/check-onboarding-gate.py" "$@"
