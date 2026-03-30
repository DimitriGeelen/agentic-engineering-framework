#!/bin/bash
# Shared human review output — deterministic review info at every layer (T-634)
#
# Emits: Watchtower URL, QR code, research artifacts, Human AC count.
# Called by: fw task review, update-task.sh (partial-complete), inception.sh (decide).
#
# Usage:
#   source "$FRAMEWORK_ROOT/lib/review.sh"
#   emit_review T-XXX [task_file]
#
# Requires: PROJECT_ROOT, BOLD, NC, CYAN (from colors.sh/paths.sh chain)

emit_review() {
    local task_id="${1:-}"
    local task_file="${2:-}"

    if [ -z "$task_id" ]; then
        return 1
    fi

    # Find task file if not provided
    if [ -z "$task_file" ]; then
        for f in "$PROJECT_ROOT/.tasks/active/$task_id"*.md "$PROJECT_ROOT/.tasks/completed/$task_id"*.md; do
            if [ -f "$f" ]; then
                task_file="$f"
                break
            fi
        done
    fi
    if [ -z "$task_file" ] || [ ! -f "$task_file" ]; then
        return 1
    fi

    # Determine Watchtower URL (env > running PID port+host > default)
    local base_url="${WATCHTOWER_URL:-}"
    if [ -z "$base_url" ]; then
        local wt_port="" wt_host="" wt_pid=""
        if [ -f "$PROJECT_ROOT/.context/working/watchtower.pid" ]; then
            wt_pid=$(cat "$PROJECT_ROOT/.context/working/watchtower.pid" 2>/dev/null)
            if [ -n "$wt_pid" ] && kill -0 "$wt_pid" 2>/dev/null; then
                wt_port=$(ss -tlnp 2>/dev/null | grep "pid=$wt_pid" | grep -oP ':(\d+)\s' | tr -d ': ' | head -1)
            fi
        fi
        wt_host=$(hostname -I 2>/dev/null | awk '{print $1}')
        wt_host="${wt_host:-$(hostname 2>/dev/null)}"
        wt_host="${wt_host:-localhost}"
        base_url="http://${wt_host}:${wt_port:-3000}"
    fi
    # Detect workflow type for URL routing (T-642)
    local workflow_type=""
    workflow_type=$(grep -m1 'workflow_type:' "$task_file" 2>/dev/null | sed 's/.*workflow_type:[[:space:]]*//' | tr -d '[:space:]')
    local review_url
    local review_label
    if [ "$workflow_type" = "inception" ]; then
        review_url="${base_url}/inception/${task_id}"
        review_label="Inception Review"
    else
        review_url="${base_url}/review/${task_id}"
        review_label="Human AC Review"
    fi

    # Count Human ACs
    local human_total=0 human_checked=0 in_human=false
    while IFS= read -r line; do
        if echo "$line" | grep -q '### Human'; then
            in_human=true; continue
        fi
        if $in_human && echo "$line" | grep -qE '^### |^## '; then
            break
        fi
        if $in_human && echo "$line" | grep -qE '^\- \[[ xX]\]'; then
            human_total=$((human_total + 1))
            if echo "$line" | grep -qE '^\- \[[xX]\]'; then
                human_checked=$((human_checked + 1))
            fi
        fi
    done < "$task_file"

    echo ""
    echo -e "══════════════════════════════════════════════════"
    echo -e "  ${BOLD}${review_label}: $task_id${NC}"
    echo -e "  ${CYAN}${human_checked}/${human_total} checked${NC}"
    echo -e ""
    echo "  ${review_url}"
    echo -e ""

    # QR code (if python3 qrcode available)
    python3 -c "
import sys
try:
    import qrcode
    qr = qrcode.QRCode(border=1, box_size=1)
    qr.add_data('$review_url')
    qr.make()
    qr.print_ascii(invert=True)
except ImportError:
    print('  (install python3-qrcode for QR code)')
" 2>/dev/null

    # Research artifacts (T-633)
    local artifacts_found=false
    local tid_lower
    tid_lower=$(echo "$task_id" | tr '[:upper:]' '[:lower:]' | tr -d '-')
    for artifact in "$PROJECT_ROOT"/docs/reports/"$task_id"-*.md "$PROJECT_ROOT"/docs/reports/fw-agent-"$tid_lower"-*.md; do
        if [ -f "$artifact" ]; then
            if ! $artifacts_found; then
                echo -e "  ${BOLD}Research Artifacts:${NC}"
                artifacts_found=true
            fi
            local rel_path="${artifact#"$PROJECT_ROOT"/}"
            echo "  ${base_url}/file/${rel_path}"
        fi
    done
    if $artifacts_found; then echo ""; fi

    echo -e "  Click the link or scan QR to review Human ACs"
    echo -e "══════════════════════════════════════════════════"
    echo ""
}
