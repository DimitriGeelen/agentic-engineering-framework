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
#
# T-1822: vendored .agentic-framework/ has its own .git after `fw vendor` clones
# from upstream, so `git -C $FRAMEWORK_ROOT rev-parse --show-toplevel` returns
# the vendored copy itself, not the consumer root. Detect the vendored case
# (basename .agentic-framework AND parent has .framework.yaml) and prefer the
# outer consumer root.
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    if [[ "$(basename "$FRAMEWORK_ROOT")" = ".agentic-framework" ]] \
       && [[ -f "$(dirname "$FRAMEWORK_ROOT")/.framework.yaml" ]]; then
        PROJECT_ROOT="$(dirname "$FRAMEWORK_ROOT")"
    else
        PROJECT_ROOT="$(git -C "$FRAMEWORK_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$FRAMEWORK_ROOT")"
    fi
fi

# T-2289 (OBS-053 3-incident class): re-derive TASKS_DIR/CONTEXT_DIR when
# they were inherited from a different PROJECT_ROOT. Symptom: shell A exports
# TASKS_DIR=/project-A/.tasks via `fw context init`; a subprocess in project B
# with `PROJECT_ROOT=/project-B fw …` inherits the stale /project-A/.tasks and
# writes go to the wrong project. The `:-` default below silently keeps the
# inherited value when non-empty.
#
# Fix: the `_FW_PATHS_DERIVED_BY` sentinel records the PROJECT_ROOT that
# originally derived the path vars. When it's present AND differs from the
# current PROJECT_ROOT, the inherited paths are stale — unset them so the
# `:-` defaults below re-derive from PROJECT_ROOT.
#
# Test-fixture invariant: when `TASKS_DIR` is set in the SAME shell as
# `PROJECT_ROOT` with no prior derivation, `_FW_PATHS_DERIVED_BY` is empty,
# the unset block is skipped, and the explicit `TASKS_DIR` survives intact
# (this is what tests/unit/create_task.bats:18 relies on).
if [[ -n "${_FW_PATHS_DERIVED_BY:-}" ]] && [[ "$_FW_PATHS_DERIVED_BY" != "$PROJECT_ROOT" ]]; then
    unset TASKS_DIR CONTEXT_DIR
fi

# Common directories
TASKS_DIR="${TASKS_DIR:-$PROJECT_ROOT/.tasks}"
CONTEXT_DIR="${CONTEXT_DIR:-$PROJECT_ROOT/.context}"

# T-2289: record which PROJECT_ROOT derived the path vars, so subprocess
# invocations under a different PROJECT_ROOT can detect the env-leak above.
_FW_PATHS_DERIVED_BY="$PROJECT_ROOT"
export _FW_PATHS_DERIVED_BY

# Context-aware fw command path (T-1102/T-1143)
# Returns the right form for copy-pasteable commands shown to users:
#   - Framework repo: bin/fw
#   - Consumer with shim: fw
#   - Consumer without shim: .agentic-framework/bin/fw
_fw_cmd() {
    if [ "$PROJECT_ROOT" = "$FRAMEWORK_ROOT" ]; then
        echo "bin/fw"
    elif command -v fw &>/dev/null; then
        echo "fw"
    else
        echo ".agentic-framework/bin/fw"
    fi
}

# Emit a full copy-pasteable command with cd prefix (T-609/T-1102)
# Usage: _emit_user_command "inception decide T-XXX go"
_emit_user_command() {
    echo "cd $PROJECT_ROOT && $(_fw_cmd) $1"
}

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

# Source task lookup helpers (find_task_file, task_exists, get_task_name)
source "$FRAMEWORK_ROOT/lib/tasks.sh" 2>/dev/null || true

# Source YAML field extraction (get_yaml_field)
source "$FRAMEWORK_ROOT/lib/yaml.sh" 2>/dev/null || true
