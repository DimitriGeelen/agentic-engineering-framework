#!/usr/bin/env bash
# Thin shim — routes `fw pause` to lib/pause_cli.py.
# Origin: T-1809 (dispatch-safety slice 5).

set -e

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
export PROJECT_ROOT

pause_py="${FRAMEWORK_ROOT:-$(dirname "$(dirname "$(readlink -f "$0")")")}/lib/pause_cli.py"

if [ ! -f "$pause_py" ]; then
  echo "fw pause: lib/pause_cli.py not found at $pause_py" >&2
  exit 1
fi

exec python3 "$pause_py" "$@"
