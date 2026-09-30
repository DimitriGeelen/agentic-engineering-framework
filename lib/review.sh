#!/usr/bin/env bash
# Review cost and proposal management
# Routes subcommands: cost, propose, list-backends, list-proposals, approve

set -eu

source "${FW_LIB_DIR}/cost.sh"

review_main() {
    local subcmd="${1:-}"
    
    case "$subcmd" in
        cost)
            shift
            review_cost_cmd "$@"
            ;;
        propose)
            shift
            review_propose_cmd "$@"
            ;;
        list-backends)
            review_list_backends
            ;;
        list-proposals)
            review_list_proposals
            ;;
        approve)
            shift
            review_approve_cmd "$@"
            ;;
        *)
            review_help
            ;;
    esac
}

review_help() {
    cat <<'HELP'
Usage: fw review <subcommand> [options]

Subcommands:
  cost log --task T-XXX --backend ID --purpose STRING [--tokens N] [--cost AMOUNT]
           Log a review cost record to the ledger
  
  cost report [START_DATE] [END_DATE]
              Report cost by backend and class (default: last 7 days)

  propose --task T-XXX --backend ID --why REASON [--estimate-tokens N] [--estimate-cost N]
          Propose a paid-backend review and wait for approval
  
  list-backends
          Show configured review backends and their cost classes

  list-proposals
          Show pending and approved proposals

  approve --proposal-id ID
          Approve a pending proposal (operator-only)

HELP
}

review_cost_cmd() {
    local subcmd="${1:-}"
    shift || true
    
    case "$subcmd" in
        log)
            cost_log_review "$@"
            ;;
        report)
            cost_report_by_backend "$@"
            ;;
        *)
            echo "Unknown cost subcommand: $subcmd" >&2
            echo "Try: fw review cost log / fw review cost report" >&2
            return 1
            ;;
    esac
}

review_propose_cmd() {
    local task backend why estimate_tokens estimate_cost proposal_id
    task="" backend="" why="" estimate_tokens="" estimate_cost=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task="$2"; shift 2 ;;
            --backend) backend="$2"; shift 2 ;;
            --why) why="$2"; shift 2 ;;
            --estimate-tokens) estimate_tokens="$2"; shift 2 ;;
            --estimate-cost) estimate_cost="$2"; shift 2 ;;
            *) echo "Unknown argument: $1" >&2; return 1 ;;
        esac
    done
    
    if [[ -z "$task" ]] || [[ -z "$backend" ]] || [[ -z "$why" ]]; then
        echo "Missing required arguments. Use: fw review propose --task T-XXX --backend ID --why REASON" >&2
        return 1
    fi
    
    cost_validate_backend "$backend" || return 1
    cost_backend_needs_approval "$backend" || {
        echo "Backend $backend does not require approval (not paid-class)" >&2
        return 1
    }
    
    # Log the proposal
    proposal_id=$(cost_log_proposal \
        --task "$task" \
        --backend "$backend" \
        --why "$why" \
        ${estimate_tokens:+--estimate-tokens "$estimate_tokens"} \
        ${estimate_cost:+--estimate-cost "$estimate_cost"})
    
    echo "Proposal created: $proposal_id"
    echo "Task: $task"
    echo "Backend: $backend"
    echo "Why: $why"
    echo ""
    echo "Awaiting approval. Check status with: fw review list-proposals"
}

review_approve_cmd() {
    local proposal_id
    proposal_id="${1:-}"
    
    if [[ -z "$proposal_id" ]]; then
        echo "Usage: fw review approve --proposal-id ID" >&2
        return 1
    fi
    
    cost_approve_proposal "$proposal_id"
    echo "Proposal $proposal_id approved."
}

review_list_backends() {
    local backend_yaml
    backend_yaml="$FRAMEWORK_ROOT/policy/review-backends.yaml"
    
    if [[ ! -f "$backend_yaml" ]]; then
        echo "Backend policy file not found: $backend_yaml" >&2
        return 1
    fi
    
    echo "Available Review Backends:"
    echo "=========================="
    echo ""

    # Parse YAML backends using grep and awk
    awk '
    /^  - id:/ {
        if (id != "") print id " | " name " | " class;
        id = $NF;
        gsub(/"/, "", id);
        name = "";
        class = "";
        next
    }
    /^    name:/ {
        name = $NF;
        gsub(/"/, "", name);
        next
    }
    /^    cost_class:/ {
        class = $NF;
        gsub(/"/, "", class);
        next
    }
    END {
        if (id != "") print id " | " name " | " class;
    }
    ' "$backend_yaml" | column -t -s "|"
}

review_list_proposals() {
    local ledger
    ledger="$PROJECT_ROOT/.context/costs/proposals.jsonl"
    
    if [[ ! -f "$ledger" ]]; then
        echo "No proposals yet."
        return 0
    fi
    
    echo "Proposals:"
    echo "=========="
    echo ""
    
    # Show pending proposals
    echo "Pending:"
    grep '"status": "pending"' "$ledger" | \
    jq -r '"[\(.id)] \(.backend) for \(.task): \(.why)"' || true
    
    echo ""
    echo "Approved:"
    grep '"status": "approved"' "$ledger" | \
    jq -r '"[\(.id)] \(.backend) for \(.task)"' || true
}

# If this script is being run directly (not sourced), call review_main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    review_main "$@"
fi
