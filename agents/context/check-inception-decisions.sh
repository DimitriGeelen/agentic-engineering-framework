#!/bin/bash
# T-1984: inception_decisions / unlocks_inception_decision validation hook (bash wrapper).
# The fw hook dispatcher (bin/fw:5639) loads .sh files; actual logic in check-inception-decisions.py.
exec python3 "$(dirname "$0")/check-inception-decisions.py" "$@"
