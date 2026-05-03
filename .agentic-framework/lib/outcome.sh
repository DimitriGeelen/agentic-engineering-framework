#!/usr/bin/env bash
# Thin shim — routes `fw outcome` to lib/outcome.py.
# Origin: T-1697 (production port of T-1690 inception spike, with append-only design pivot).
set -e

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
export PROJECT_ROOT

outcome_py="${FRAMEWORK_ROOT:-$(dirname "$(dirname "$(readlink -f "$0")")")}/lib/outcome.py"

if [ ! -f "$outcome_py" ]; then
  echo "fw outcome: lib/outcome.py not found at $outcome_py" >&2
  exit 1
fi

exec python3 "$outcome_py" "$@"
