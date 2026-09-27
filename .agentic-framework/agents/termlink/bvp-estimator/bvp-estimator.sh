#!/usr/bin/env bash
# bvp-estimator.sh — TermLink worker entry point (T-1922, arc-006).
#
# Thin shell wrapper around estimator.py so the worker fits the TermLink
# agent convention (`agents/<name>/<name>.sh`). Forwards all args to the
# Python implementation.
#
# Usage:
#   ./bvp-estimator.sh one T-XXX [--dry-run] [--json]
#   ./bvp-estimator.sh all [--dry-run] [--limit N] [--statuses captured started-work]
#   ./bvp-estimator.sh determinism T-XXX [--runs 3]
#   ./bvp-estimator.sh measure-a3 [--n 20] [--output PATH]
#
# Invoked via `fw bvp estimate` (lib/bvp.sh routing) for the common case.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"

export FRAMEWORK_ROOT PROJECT_ROOT

exec python3 "$SCRIPT_DIR/estimator.py" "$@"
