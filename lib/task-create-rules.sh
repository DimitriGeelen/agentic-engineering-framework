#!/usr/bin/env bash
# lib/task-create-rules.sh — the rules a new task must pass (T-5221, slice 2 of T-5212).
#
# Lifted out of agents/task-create/create-task.sh so `fw task create` and
# `fw task create-batch` validate by ONE rule set. Messages are byte-identical to the ones
# create-task printed inline; each function prints to stderr and RETURNS 1 instead of
# exiting, so the batch can check every entry before it refuses.
#
# Needs lib/enums.sh (is_valid_type/horizon/owner) and lib/errors.sh (error); sources them
# when the caller has not.
#
# Public:
#   task_rule_name NAME                      T-555 template-placeholder names
#   task_rule_fields NAME TYPE HORIZON OWNER type, horizon (T-2160), owner (T-2674),
#                                            recursive audit-warn names (T-100202)

[ -n "${_FW_TASK_CREATE_RULES_LOADED:-}" ] && return 0
_FW_TASK_CREATE_RULES_LOADED=1

_FW_TCR_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -F error >/dev/null 2>&1 || source "$_FW_TCR_LIB/errors.sh"
declare -F is_valid_type >/dev/null 2>&1 || source "$_FW_TCR_LIB/enums.sh"

# T-555: Reject template placeholder names
task_rule_name() {
    local name="$1" lower
    lower=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    case "$lower" in
        "task name"|"name"|"description"|"first criterion"|"second criterion"|\
        "task"|"my task"|"new task"|"test task"|"todo"|"fix bug"|"implement feature"|\
        "criterion"|"placeholder"|"example task"|"untitled")
            echo "ERROR: '$name' looks like a template placeholder, not a real task name." >&2
            echo "" >&2
            echo "  Provide a specific, descriptive name. Examples:" >&2
            echo "    --name \"Fix login timeout on slow connections\"" >&2
            echo "    --name \"Add retry logic to API client\"" >&2
            echo "    --name \"Inception: Evaluate caching strategy\"" >&2
            echo "" >&2
            return 1
            ;;
    esac
    return 0
}

task_rule_fields() {
    local name="$1" wtype="$2" horizon="$3" owner="$4"

    # Validate workflow type
    if ! is_valid_type "$wtype"; then
        error "Invalid workflow type '$wtype'"
        error "Valid types: $VALID_TYPES"
        return 1
    fi

    # Validate horizon
    # T-2160 (arc-009 Slice 1): explicit guard against --horizon past at creation too.
    if [ "$horizon" = "past" ]; then
        error "'--horizon past' rejected — past is a derived render-time value, not settable"
        error "  Past is computed from file location: .tasks/completed/ → renders as past."
        error "  Storage enum is now/next/later. Per T-2159 Q1=(b); arc-009."
        return 1
    fi
    if ! is_valid_horizon "$horizon"; then
        error "Invalid horizon '$horizon'"
        error "Valid horizons: $VALID_HORIZONS"
        return 1
    fi

    # Validate owner (T-2674, closes the residual G-040 creation-side hole: the
    # predicate existed since T-1180 but was never called here — any --owner string
    # was written verbatim while Watchtower's dropdowns whitelist the enum).
    if ! is_valid_owner "$owner"; then
        error "Invalid owner '$owner'"
        error "Valid owners: $VALID_OWNERS (enum source: status-transitions.yaml)"
        return 1
    fi

    # T-100202 AC4 (recursion guard): refuse names carrying the self-feeding
    # audit-emitter signature — a WARN task named after another WARN task, e.g.
    # "Audit WARN — Task T-2488-audit-warn--task-t-2462-…". The emitter itself is
    # removed from HEAD (audit emits observations via `fw note`, hash-deduped),
    # but this gate makes the recursion class structurally impossible for ANY
    # future emitter path, not just the removed one.
    if printf '%s' "$name" | grep -qiE 'audit[ -]?warn.*audit[ -]?warn'; then
        error "Recursive audit-warn task name refused (T-100202)"
        error "  A task about an audit-warn task re-audits its own emission and inflates"
        error "  the ID space unboundedly (origin: T-99971 seed, 2026-07-03)."
        error "  Capture the finding as an observation instead: fw note \"<finding>\" (hash-deduped, no ID minted)"
        return 1
    fi
    return 0
}
