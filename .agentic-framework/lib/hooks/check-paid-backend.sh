#!/usr/bin/env bash
# PreToolUse hook: check-paid-backend
# Blocks direct bash invocation of paid review backends without an approved proposal.
# T-3583: OpenRouter requires approval before dispatch.
#
# Routes:
# 1. OpenRouter URL or CLI → block, suggest fw review propose
# 2. OpenRouter already approved → allow
# 3. Other backends → allow with reminder to log cost

set -e

# Exit cleanly if not in a project (no governance to enforce)
if [ ! -d ".tasks" ] && [ ! -f ".framework.yaml" ]; then
    exit 0
fi

PROJECT_ROOT="${PROJECT_ROOT:-.}"
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-.}"

tool_input="${1:-.}"
[[ -z "$tool_input" ]] && exit 0

# Check for OpenRouter references (URLs, API keys, direct references)
if echo "$tool_input" | grep -qi "openrouter\|openrouter.ai"; then
    # This looks like an OpenRouter invocation.
    # Check if there's an approved proposal for this task.

    active_task=$(cat "$PROJECT_ROOT/.context/working/focus.yaml" 2>/dev/null | grep "^task:" | awk '{print $2}' || echo "")

    if [[ -z "$active_task" ]]; then
        echo "Cannot verify OpenRouter approval without active task context." >&2
        echo "Use: fw work-on T-XXX first, or fw review propose --backend openrouter --task T-XXX --why '...'" >&2
        exit 1
    fi

    # Check if there's an approved proposal for this task
    proposals_ledger="$PROJECT_ROOT/.context/costs/proposals.jsonl"

    if [[ ! -f "$proposals_ledger" ]]; then
        echo "OpenRouter dispatch requires approval. No proposals found." >&2
        echo "Use: fw review propose --backend openrouter --task $active_task --why 'value/risk explanation' --estimate-cost N" >&2
        exit 1
    fi

    # Look for an approved proposal for openrouter on this task
    approved=$(grep "\"task\": \"$active_task\"" "$proposals_ledger" | grep "\"backend\": \"openrouter\"" | grep "\"status\": \"approved\"" | tail -1 || echo "")

    if [[ -z "$approved" ]]; then
        echo "OpenRouter dispatch for $active_task requires approval." >&2
        echo "Use: fw review propose --backend openrouter --task $active_task --why 'value/risk explanation' --estimate-cost N" >&2
        exit 1
    fi
fi

# All other backends are internal subscription harnesses (allowed).
# Remind to log cost if the command is not wrapped.
exit 0
