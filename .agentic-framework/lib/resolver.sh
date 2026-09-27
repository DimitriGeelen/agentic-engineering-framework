#!/usr/bin/env bash
# Thin shim — routes `fw resolver` to lib/resolver.py.
# Origin: T-1696 (production port of T-1689 inception spike).
# Per D-073: single Python module + thin shell shim — no script-level logic
# beyond PROJECT_ROOT export and argv passthrough.

set -e

# FRAMEWORK_ROOT is set by bin/fw before sourcing libs.
# PROJECT_ROOT defaults to caller's cwd if not pre-set; the python module
# reads it from the environment.
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
export PROJECT_ROOT

resolver_py="${FRAMEWORK_ROOT:-$(dirname "$(dirname "$(readlink -f "$0")")")}/lib/resolver.py"

if [ ! -f "$resolver_py" ]; then
  echo "fw resolver: lib/resolver.py not found at $resolver_py" >&2
  exit 1
fi

exec python3 "$resolver_py" "$@"
