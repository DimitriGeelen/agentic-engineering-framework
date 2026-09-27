#!/bin/bash
# T-1731: Human-AC tick guard hook (bash wrapper for the Python implementation).
# The fw hook dispatcher (bin/fw:4759) loads .sh files; the actual logic lives
# in check-human-ac-tick.py for clean diff parsing.
exec python3 "$(dirname "$0")/check-human-ac-tick.py" "$@"
