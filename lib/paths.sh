#!/bin/bash
# lib/paths.sh — Centralized path resolution for the Agentic Engineering Framework
#
# Provides FRAMEWORK_ROOT, PROJECT_ROOT, and common directory variables.
# Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern
# duplicated across 25+ agent scripts.
#
# Usage (from any agent script):
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/paths.sh"
#
# Or if FRAMEWORK_ROOT is already known:
#   source "$FRAMEWORK_ROOT/lib/paths.sh"
#
# After sourcing, these variables are set:
#   FRAMEWORK_ROOT — Absolute path to the framework repo root
#   PROJECT_ROOT   — Absolute path to the project root (may differ in shared-tooling mode)
#   TASKS_DIR      — $PROJECT_ROOT/.tasks
#   CONTEXT_DIR    — $PROJECT_ROOT/.context
#
# Also sources lib/compat.sh for cross-platform helpers (_sed_i).

# Guard against double-sourcing
[[ -n "${_FW_PATHS_LOADED:-}" ]] && return 0
_FW_PATHS_LOADED=1

# Resolve FRAMEWORK_ROOT from this file's location (lib/paths.sh → repo root)
if [[ -z "${FRAMEWORK_ROOT:-}" ]]; then
    FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Resolve PROJECT_ROOT from git toplevel — framework/ is typically a subdirectory,
# not the project root. Fall back to FRAMEWORK_ROOT for standalone installs.
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT="$(git -C "$FRAMEWORK_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$FRAMEWORK_ROOT")"
fi

# Common directories
TASKS_DIR="${TASKS_DIR:-$PROJECT_ROOT/.tasks}"
CONTEXT_DIR="${CONTEXT_DIR:-$PROJECT_ROOT/.context}"

# Export for subprocesses
export FRAMEWORK_ROOT PROJECT_ROOT TASKS_DIR CONTEXT_DIR

# Source cross-platform compat helpers (_sed_i)
source "$FRAMEWORK_ROOT/lib/compat.sh" 2>/dev/null || {
    # Inline fallback if compat.sh is missing (should not happen in normal installs)
    _sed_i() {
        local expr="$1" file="$2"
        local tmp
        tmp=$(mktemp "${file}.XXXXXX") && sed "$expr" "$file" > "$tmp" && mv "$tmp" "$file"
    }
}

# Source error output helpers (die, warn, error, info, success, block)
source "$FRAMEWORK_ROOT/lib/errors.sh" 2>/dev/null || true
