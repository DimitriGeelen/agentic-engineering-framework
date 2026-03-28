#!/bin/bash
# lib/enums.sh — Single source of truth for framework enumerations
#
# Reads status-transitions.yaml and compiles to O(1) associative array lookup.
# Falls back to inline definitions if YAML file or python3 unavailable.
#
# Usage: source "$FRAMEWORK_ROOT/lib/enums.sh"

# Guard against double-sourcing
[[ -n "${_FW_ENUMS_LOADED:-}" ]] && return 0
_FW_ENUMS_LOADED=1

# --- Locate YAML source ---
_ENUMS_YAML="${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/status-transitions.yaml"

# --- Compiled transition lookup (O(1) via associative array) ---
declare -A _TRANSITION_MAP 2>/dev/null || true

_enums_load_yaml() {
    # Parse YAML and populate shell variables
    local yaml_file="$1"
    [ -f "$yaml_file" ] || return 1
    command -v python3 &>/dev/null || return 1

    # Extract statuses, types, horizons, and transitions from YAML
    eval "$(python3 -c "
import yaml, sys
try:
    d = yaml.safe_load(open('$yaml_file'))
    active = d.get('statuses', {}).get('active', [])
    legacy = d.get('statuses', {}).get('legacy', [])
    types = d.get('workflow_types', [])
    horizons = d.get('horizons', [])
    transitions = d.get('transitions', [])

    print('VALID_STATUSES=\"%s\"' % ' '.join(active))
    print('LEGACY_STATUSES=\"%s\"' % ' '.join(legacy))
    print('ALL_STATUSES=\"%s\"' % ' '.join(active + legacy))
    print('VALID_TYPES=\"%s\"' % ' '.join(types))
    print('VALID_HORIZONS=\"%s\"' % ' '.join(horizons))

    # Build transition pairs for array
    pairs = []
    for t in transitions:
        pairs.append('%s:%s' % (t['from'], t['to']))
    print('VALID_TRANSITIONS=(%s)' % ' '.join('\"%s\"' % p for p in pairs))

    # Build associative array entries for O(1) lookup
    for p in pairs:
        print('_TRANSITION_MAP[\"%s\"]=1' % p)
except Exception as e:
    print('# YAML parse failed: %s' % e, file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)"
}

# Try YAML first, fall back to inline definitions
if ! _enums_load_yaml "$_ENUMS_YAML" 2>/dev/null; then
    # --- Fallback: inline definitions (identical to pre-T-588 values) ---
    VALID_STATUSES="captured started-work issues work-completed"
    LEGACY_STATUSES="refined blocked"
    ALL_STATUSES="$VALID_STATUSES $LEGACY_STATUSES"
    VALID_TYPES="specification design build test refactor decommission inception"
    VALID_HORIZONS="now next later"
    VALID_TRANSITIONS=(
        "captured:started-work"
        "started-work:captured"
        "started-work:issues"
        "started-work:work-completed"
        "issues:started-work"
        "issues:work-completed"
        "refined:started-work"
        "blocked:started-work"
    )
    # Populate transition map from fallback
    for _t in "${VALID_TRANSITIONS[@]}"; do
        _TRANSITION_MAP["$_t"]=1
    done
fi

# --- Validation functions (backward compatible API) ---

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
    local status="$1"
    [[ " $ALL_STATUSES " == *" $status "* ]]
}

is_valid_transition() {
    # O(1) lookup via associative array (compiled from YAML)
    local from="$1" to="$2"
    [[ -n "${_TRANSITION_MAP["$from:$to"]:-}" ]]
}

# --- Display helpers ---

list_valid_statuses() { echo "$VALID_STATUSES"; }
list_valid_types() { echo "$VALID_TYPES"; }
list_valid_horizons() { echo "$VALID_HORIZONS"; }

valid_transitions_for() {
    local from="$1"
    local targets=""
    for t in "${VALID_TRANSITIONS[@]}"; do
        if [[ "$t" == "$from:"* ]]; then
            targets="${targets} ${t#*:}"
        fi
    done
    echo "${targets# }"
}
