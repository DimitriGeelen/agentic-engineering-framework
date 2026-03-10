#!/bin/bash
# lib/enums.sh — Single source of truth for framework enumerations
#
# Defines valid statuses, workflow types, horizons, and validation functions.
# Replaces hardcoded lists in create-task.sh, update-task.sh, audit.sh, metrics.sh.
#
# Usage: source "$FRAMEWORK_ROOT/lib/enums.sh"

# Guard against double-sourcing
[[ -n "${_FW_ENUMS_LOADED:-}" ]] && return 0
_FW_ENUMS_LOADED=1

# --- Active statuses (current workflow) ---
VALID_STATUSES="captured started-work issues work-completed"

# --- Legacy statuses (accepted on read, not settable via update-task) ---
LEGACY_STATUSES="refined blocked"

# --- All recognized statuses (for audit/metrics) ---
ALL_STATUSES="$VALID_STATUSES $LEGACY_STATUSES"

# --- Workflow types ---
VALID_TYPES="specification design build test refactor decommission inception"

# --- Horizons ---
VALID_HORIZONS="now next later"

# --- Status transitions (from:to) ---
# Used by update-task.sh to validate state machine
VALID_TRANSITIONS=(
    "captured:started-work"
    "started-work:captured"
    "started-work:issues"
    "started-work:work-completed"
    "issues:started-work"
    "issues:work-completed"
    "refined:started-work"     # Legacy compat
    "blocked:started-work"     # Legacy compat
)

# --- Validation functions ---

is_valid_status() {
    local status="$1"
    [[ " $VALID_STATUSES " == *" $status "* ]]
}

is_valid_type() {
    local type="$1"
    [[ " $VALID_TYPES " == *" $type "* ]]
}

is_valid_horizon() {
    local horizon="$1"
    [[ " $VALID_HORIZONS " == *" $horizon "* ]]
}

is_recognized_status() {
    # Accepts both active and legacy statuses (for audit/metrics)
    local status="$1"
    [[ " $ALL_STATUSES " == *" $status "* ]]
}

is_valid_transition() {
    local from="$1" to="$2"
    local pair="$from:$to"
    for t in "${VALID_TRANSITIONS[@]}"; do
        [[ "$t" == "$pair" ]] && return 0
    done
    return 1
}

# --- Display helpers ---

list_valid_statuses() { echo "$VALID_STATUSES"; }
list_valid_types() { echo "$VALID_TYPES"; }
list_valid_horizons() { echo "$VALID_HORIZONS"; }

valid_transitions_for() {
    # List valid target statuses for a given current status
    local from="$1"
    local targets=""
    for t in "${VALID_TRANSITIONS[@]}"; do
        if [[ "$t" == "$from:"* ]]; then
            targets="${targets} ${t#*:}"
        fi
    done
    echo "${targets# }"
}
