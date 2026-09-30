#!/usr/bin/env bash
# Cost ledger management for reviews and dispatches.
# Every review or dispatch records its cost, internal or paid.
#
# Usage:
#   source lib/cost.sh
#   cost_log_review --task T-XXX --backend claude-code --purpose "code-review" \
#     [--tokens 45000] [--cost 0.50]
#
# Ledger format (.context/costs/reviews.jsonl):
#   {"ts":"2026-09-30T10:23:45Z","task":"T-3580","backend":"openai",...}
#   One JSON object per line, no field order guarantee.

set -eu

# Resolve policy file - prefer project-local, fall back to framework
_resolve_backends_policy() {
    local proj_local="${PROJECT_ROOT}/policy/review-backends.yaml"
    local framework_local="${FRAMEWORK_ROOT}/policy/review-backends.yaml"

    if [[ -f "$proj_local" ]]; then
        echo "$proj_local"
    elif [[ -f "$framework_local" ]]; then
        echo "$framework_local"
    else
        echo "$proj_local"  # default, even if doesn't exist (for error messages)
    fi
}
readonly COST_BACKENDS_POLICY="$(_resolve_backends_policy)"
readonly COST_REVIEWS_LEDGER="${PROJECT_ROOT}/.context/costs/reviews.jsonl"
readonly COST_PROPOSALS_LEDGER="${PROJECT_ROOT}/.context/costs/proposals.jsonl"

# Initialize cost ledger directories
cost_init() {
    mkdir -p "$(dirname "$COST_REVIEWS_LEDGER")"
}

# Validate backend ID exists in policy file
cost_validate_backend() {
    local backend_id="$1"
    if ! grep -q "^  - id: ${backend_id}$" "$COST_BACKENDS_POLICY"; then
        echo "FATAL: Unknown backend id: $backend_id" >&2
        echo "Run 'fw review list-backends' to see valid ids" >&2
        return 1
    fi
}

# Get backend class (internal|paid) from policy
cost_get_backend_class() {
    local backend_id="$1"
    local line
    line=$(grep -A 10 "^  - id: ${backend_id}$" "$COST_BACKENDS_POLICY" | grep "cost_class:" | head -1)
    echo "${line#*: }"
}

# Get approval_required flag from policy
cost_backend_needs_approval() {
    local backend_id="$1"
    local line
    line=$(grep -A 10 "^  - id: ${backend_id}$" "$COST_BACKENDS_POLICY" | grep "approval_required:" | head -1)
    [[ "$line" =~ true ]]
}

# Log a review cost record
# Arguments:
#   --task TASK_ID
#   --backend BACKEND_ID (must exist in policy)
#   --purpose PURPOSE_STRING (e.g., "code-review", "inception-review")
#   [--tokens TOKENS] (optional, for metered backends)
#   [--cost COST_AMOUNT] (optional, for metered backends)
#   [--proposal-id PROPOSAL_ID] (optional, if this was an approved proposal)
cost_log_review() {
    local task backend purpose tokens cost proposal_id
    task="" backend="" purpose="" tokens="" cost="" proposal_id=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task="$2"; shift 2 ;;
            --backend) backend="$2"; shift 2 ;;
            --purpose) purpose="$2"; shift 2 ;;
            --tokens) tokens="$2"; shift 2 ;;
            --cost) cost="$2"; shift 2 ;;
            --proposal-id) proposal_id="$2"; shift 2 ;;
            *) echo "Unknown argument: $1" >&2; return 1 ;;
        esac
    done

    # Validation
    [[ -z "$task" ]] && { echo "Missing --task" >&2; return 1; }
    [[ -z "$backend" ]] && { echo "Missing --backend" >&2; return 1; }
    [[ -z "$purpose" ]] && { echo "Missing --purpose" >&2; return 1; }

    cost_validate_backend "$backend" || return 1

    # Build JSON record
    local ts class record
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    class=$(cost_get_backend_class "$backend")

    record=$(cat <<EOF
{
  "ts": "$ts",
  "task": "$task",
  "backend": "$backend",
  "class": "$class",
  "purpose": "$purpose"
EOF
    )

    [[ -n "$tokens" ]] && record+=$(printf ',\n  "tokens": %s' "$tokens")
    [[ -n "$cost" ]] && record+=$(printf ',\n  "cost_amount": %s' "$cost")
    [[ -n "$proposal_id" ]] && record+=$(printf ',\n  "proposal_id": "%s"' "$proposal_id")

    record+=$'\n}'

    # Append to ledger
    cost_init
    echo "$record" >> "$COST_REVIEWS_LEDGER"
}

# Log a proposal for a paid-class backend
# Arguments:
#   --task TASK_ID
#   --backend BACKEND_ID (must be paid-class)
#   --why WHY_STRING (rationale for the proposal)
#   [--estimate-tokens TOKENS] (optional, estimated token count)
#   [--estimate-cost COST_AMOUNT] (optional, estimated cost)
# Returns: proposal ID
cost_log_proposal() {
    local task backend why tokens cost proposal_id
    task="" backend="" why="" tokens="" cost=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task="$2"; shift 2 ;;
            --backend) backend="$2"; shift 2 ;;
            --why) why="$2"; shift 2 ;;
            --estimate-tokens) tokens="$2"; shift 2 ;;
            --estimate-cost) cost="$2"; shift 2 ;;
            *) echo "Unknown argument: $1" >&2; return 1 ;;
        esac
    done

    # Validation
    [[ -z "$task" ]] && { echo "Missing --task" >&2; return 1; }
    [[ -z "$backend" ]] && { echo "Missing --backend" >&2; return 1; }
    [[ -z "$why" ]] && { echo "Missing --why" >&2; return 1; }

    cost_validate_backend "$backend" || return 1
    cost_backend_needs_approval "$backend" || {
        echo "Backend $backend does not require approval (not paid-class)" >&2
        return 1
    }

    # Generate proposal ID
    proposal_id="RP-$(date +%s)-$(od -An -N2 -tx1 /dev/urandom | tr -d ' ')"

    # Build JSON record
    local ts class record
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    class=$(cost_get_backend_class "$backend")

    record=$(cat <<EOF
{
  "id": "$proposal_id",
  "ts": "$ts",
  "task": "$task",
  "backend": "$backend",
  "class": "$class",
  "why": "$why",
  "status": "pending"
EOF
    )

    [[ -n "$tokens" ]] && record+=$(printf ',\n  "estimate_tokens": %s' "$tokens")
    [[ -n "$cost" ]] && record+=$(printf ',\n  "estimate_cost": %s' "$cost")

    record+=$'\n}'

    # Append to ledger
    cost_init
    echo "$record" >> "$COST_PROPOSALS_LEDGER"

    echo "$proposal_id"
}

# Check if a proposal is approved
# Returns 0 if approved, 1 if not found or pending
cost_proposal_is_approved() {
    local proposal_id="$1"
    local line

    [[ -f "$COST_PROPOSALS_LEDGER" ]] || return 1

    line=$(grep "\"id\": \"$proposal_id\"" "$COST_PROPOSALS_LEDGER" | tail -1) || return 1
    [[ "$line" =~ status.*approved ]]
}

# Approve a proposal (operator-only, normally via Watchtower)
cost_approve_proposal() {
    local proposal_id="$1"
    local update_ts approval_ts

    update_ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    approval_ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update the proposal status (append new record with approved status)
    local update_record
    update_record=$(cat <<EOF
{
  "id": "$proposal_id",
  "ts": "$update_ts",
  "status": "approved",
  "approved_ts": "$approval_ts"
}
EOF
    )

    echo "$update_record" >> "$COST_PROPOSALS_LEDGER"
}

# List pending proposals
cost_list_pending_proposals() {
    [[ -f "$COST_PROPOSALS_LEDGER" ]] || return 0

    grep '"status": "pending"' "$COST_PROPOSALS_LEDGER" || true
}

# Report cost by backend and class for a time window
cost_report_by_backend() {
    local start_date end_date
    start_date="${1:-$(date -u -d '7 days ago' +%Y-%m-%d)}"
    end_date="${2:-$(date -u +%Y-%m-%d)}"

    [[ -f "$COST_REVIEWS_LEDGER" ]] || return 0

    # Print header
    printf "%-12s %-15s %-8s %10s\n" "BACKEND" "CLASS" "COUNT" "TOTAL_COST"
    printf "%s\n" "$(printf '%.0s-' {1..50})"

    # Group by backend and class
    grep -E "\"ts\": \"${start_date}|${end_date}" "$COST_REVIEWS_LEDGER" | \
        jq -r '[.backend, .class] | @tsv' | sort | uniq -c | while read count line; do
        printf "%-12s %-15s %8d\n" $(echo "$line" | tr '\t' ' ')
    done
}
