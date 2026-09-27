#!/bin/bash
# T-2517: active/completed same-id task duplicate write-time guard (T-2121 prong 1).
# The fw hook dispatcher (bin/fw) loads .sh files; the actual logic lives in
# check-active-completed-dup.py to keep the file-glob + YAML-adjacent parsing clean.
exec python3 "$(dirname "$0")/check-active-completed-dup.py" "$@"
