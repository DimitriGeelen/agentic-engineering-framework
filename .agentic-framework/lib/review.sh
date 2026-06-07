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

# Ensure _fw_cmd/_emit_user_command are available (T-1143)
[[ -z "${_FW_PATHS_LOADED:-}" ]] && source "${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/paths.sh" 2>/dev/null || true
# Requires: PROJECT_ROOT, BOLD, NC, CYAN (from colors.sh/paths.sh chain)

# Source watchtower helper for URL detection (T-1154: single source of truth)
source "${FRAMEWORK_ROOT:-.}/lib/watchtower.sh"

# T-1657: G-062 mechanism #3 — arc-parent gate.
# When `fw task review T-XXX` is invoked on a task that anchors an arc OR
# carries an explicit arc-parent tag, print the three §Arc Completion Discipline
# questions BEFORE the Watchtower URL. Non-blocking — last visible reminder.
_arc_parent_gate() {
    local task_id="$1"
    local task_file="$2"
    local arcs_dir="$PROJECT_ROOT/.context/arcs"

    # Detection 1: task_id is the anchor of an in-progress arc.
    local anchor_arc=""
    if [ -d "$arcs_dir" ]; then
        for af in "$arcs_dir"/*.yaml; do
            [ -f "$af" ] || continue
            local anchor status
            anchor=$(awk -F': ' '/^anchor_task:/ {print $2; exit}' "$af" | tr -d ' "')
            status=$(awk -F': ' '/^status:/ {print $2; exit}' "$af")
            if [ "$anchor" = "$task_id" ] && [ "$status" = "in-progress" ]; then
                anchor_arc=$(awk -F': ' '/^id:/ {print $2; exit}' "$af" | tr -d ' "')
                break
            fi
        done
    fi

    # Detection 2: explicit arc-parent tag on the task.
    local has_tag=0
    if [ -n "$task_file" ] && [ -f "$task_file" ]; then
        if grep -qE "^tags:.*arc-parent" "$task_file"; then
            has_tag=1
        fi
    fi

    if [ -z "$anchor_arc" ] && [ "$has_tag" = "0" ]; then
        return 0  # not an arc-parent — skip gate
    fi

    local label="${anchor_arc:-arc-parent}"
    cat <<BANNER
${YELLOW:-}=== ARC COMPLETION CHECK (T-1657 / G-062 mechanism #3) ===${NC:-}
This task anchors arc: ${label}
Before recommending GO, you MUST be able to answer all three:

  1. Did the integrated system run end-to-end on a fresh substrate?
     (Wire-level observation, not "tests pass" or "AC checked".)

  2. Did any silently-defaulted constants escape human review?
     (Routing thresholds, taxonomies, fallback chains, retry counts...)

  3. Does the framework that built the arc actually USE the arc?
     (Framework-side dispatch/audit/handover paths exercise the substrate.)

See CLAUDE.md §Arc Completion Discipline for the full test.
${YELLOW:-}========================================================${NC:-}

BANNER
    return 0
}

emit_review() {
    local task_id="${1:-}"
    local task_file="${2:-}"

    if [ -z "$task_id" ]; then
        return 1
    fi

    # T-1509: Treat task_file arg as a HINT, not a hard requirement. Callers
    # may pass a path that became stale (e.g. inception decide passes the
    # active/ path, but update-task.sh has since moved the file to completed/).
    # Fall back to discovery when the hint is empty OR points at a missing file.
    if [ -z "$task_file" ] || [ ! -f "$task_file" ]; then
        task_file=""
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

    # T-1657: arc-parent gate — print three-question check before the URL.
    _arc_parent_gate "$task_id" "$task_file" || true

    # Determine Watchtower URL via shared helper (T-1154: single chokepoint)
    local base_url
    base_url=$(_watchtower_url "$task_id")
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

    # T-1215 / T-1545 / T-2206 (Slice C): Block emission when inception has no
    # substantive ## Recommendation block — was a WARNING (T-1215/T-1545), now
    # a BLOCK (T-2206) per T-2204 GO. The producer-side hook (T-2205) closes the
    # Write/Edit leaf; this consumer-side gate closes the handoff-emission leaf
    # so the operator never sees a /inception/<id> link pointing at a blank
    # Recommendation card.
    #
    # Bypass: FW_ALLOW_EMPTY_RECOMMENDATION=1 (env var, T-1890 producer/consumer
    # parity — same env var name as T-2205's Write/Edit hook). Tier-2 logged.
    if [ "$workflow_type" = "inception" ]; then
        if ! declare -F audit_inception_recommendation >/dev/null 2>&1; then
            source "${FRAMEWORK_ROOT:-.}/lib/task-audit.sh" 2>/dev/null || true
        fi
        if declare -F audit_inception_recommendation >/dev/null 2>&1; then
            if ! audit_inception_recommendation "$task_file" 2>/dev/null; then
                if [ "${FW_ALLOW_EMPTY_RECOMMENDATION:-}" = "1" ]; then
                    # Bypass: log Tier-2, emit NOTE, continue.
                    _log_empty_recommendation_bypass "$task_id" "emit_review" "$task_file"
                    echo "" >&2
                    echo -e "  ${YELLOW}NOTE: Inception ${task_id} has empty ## Recommendation —${NC}" >&2
                    echo -e "  ${YELLOW}emission allowed via FW_ALLOW_EMPTY_RECOMMENDATION=1 (logged).${NC}" >&2
                    echo "" >&2
                else
                    echo "" >&2
                    echo -e "  ${RED}══════════════════════════════════════════${NC}" >&2
                    echo -e "  ${RED}BLOCKED: Inception ${task_id} has empty ## Recommendation${NC}" >&2
                    echo -e "  ${RED}══════════════════════════════════════════${NC}" >&2
                    echo "" >&2
                    echo -e "  Handoff URL refuses emission — operator would see a blank" >&2
                    echo -e "  decision form on /inception/${task_id}." >&2
                    echo "" >&2
                    echo -e "  Origin: T-679 (governance rule), T-1715/T-1716 (filing-time" >&2
                    echo -e "  gate on fw inception start), T-2204/T-2205/T-2206 (this gate)." >&2
                    echo "" >&2
                    echo -e "  To proceed, choose ONE:" >&2
                    echo "" >&2
                    echo -e "    1. Edit ${task_file}:" >&2
                    echo -e "       Replace template comment under ## Recommendation with:" >&2
                    echo -e "         **Recommendation:** GO | NO-GO | DEFER" >&2
                    echo -e "         **Rationale:** <evidence-cited reasoning>" >&2
                    echo "" >&2
                    echo -e "    2. Override (logged Tier 2):" >&2
                    echo -e "         FW_ALLOW_EMPTY_RECOMMENDATION=1 fw task review ${task_id}" >&2
                    echo "" >&2
                    return 1
                fi
            fi
        fi
    fi

    # T-2050: validate Watchtower links the agent wrote in this task body against
    # app.url_map. WARNs on unresolvable paths (/appearance vs /settings/appearance).
    # T-2139 (V1 keystone, T-2138 GO): --enforce mode adds blocking absence-of-URL
    # homework detection. Non-zero exit refuses the handoff; bypass via
    # FW_ALLOW_REVIEW_LINK_HOMEWORK=1 (logged Tier-2). The `|| true` swallow that
    # made T-2050 silent is gone — exit code now propagates.
    if [ -f "${FRAMEWORK_ROOT:-.}/lib/review_link_validator.py" ]; then
        if ! python3 "${FRAMEWORK_ROOT:-.}/lib/review_link_validator.py" "$task_file" "$base_url" --enforce; then
            echo "" >&2
            echo -e "  ${YELLOW}══════════════════════════════════════════${NC}" >&2
            echo -e "  ${YELLOW}BLOCKED: Review-handoff homework detected (T-2139)${NC}" >&2
            echo -e "  ${YELLOW}══════════════════════════════════════════${NC}" >&2
            echo "" >&2
            return 2
        fi
    fi

    echo ""
    echo -e "══════════════════════════════════════════"
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

    # T-2127 (T-2126 slice A): repeat URL below QR — on terminals <37 visible
    # rows (typical 24-30), the URL at the top scrolls off-screen while the
    # 16-row QR is still in the visible frame. Repeating it here keeps the
    # URL reachable from the bottom of the output.
    echo ""
    echo -e "  ${BOLD}Open:${NC} ${review_url}"

    # Research artifacts (T-633, T-1201: show filename only)
    local artifacts_found=false
    local tid_lower
    tid_lower=$(echo "$task_id" | tr '[:upper:]' '[:lower:]' | tr -d '-')
    for artifact in "$PROJECT_ROOT"/docs/reports/"$task_id"-*.md "$PROJECT_ROOT"/docs/reports/fw-agent-"$tid_lower"-*.md; do
        if [ -f "$artifact" ]; then
            if ! $artifacts_found; then
                echo -e "  ${BOLD}Artifacts:${NC} (in docs/reports/)"
                artifacts_found=true
            fi
            echo "    $(basename "$artifact")"
        fi
    done
    if $artifacts_found; then echo ""; fi

    echo -e "  Scan QR or open link above"
    echo ""

    # CLI alternative for inception tasks (T-973, T-1201)
    if [ "$workflow_type" = "inception" ]; then
        # Extract recommendation line for pre-filled rationale.
        # T-1492: widen pattern (indented OK, skip HTML-commented), terminate
        # pipeline with `|| true` so command-substitution exit code cannot
        # propagate under `set -euo pipefail` and abort emit_review mid-flight
        # (which previously left .reviewed-T-XXX uncreated, blocking inception decide).
        local _rec_line=""
        local _rec_raw=""
        _rec_raw=$(grep -m1 '^[[:space:]]*\*\*Recommendation:' "$task_file" 2>/dev/null \
            | grep -v '<!--' || true)
        if [ -n "$_rec_raw" ]; then
            _rec_line=$(echo "$_rec_raw" \
                | sed -e 's/^[[:space:]]*\*\*Recommendation:\*\*[[:space:]]*//' \
                      -e 's/^[[:space:]]*\*\*Recommendation:[[:space:]]*//')
        fi
        if [ -z "$_rec_line" ]; then
            echo -e "  ${YELLOW}Note: No \`**Recommendation:**\` line found in task body — using fallback rationale${NC}" >&2
            _rec_line="your rationale"
        fi
        # Truncate to fit terminal (keep under 60 chars)
        _rec_line="${_rec_line:0:58}"
        echo -e "  ${BOLD}CLI:${NC} cd $PROJECT_ROOT &&"
        echo "    $(_fw_cmd) inception decide $task_id go \\"
        echo "    --rationale \"${_rec_line}\""
        echo ""
    fi

    echo -e "══════════════════════════════════════════"
    echo ""

    # Mark task as reviewed — prerequisite gate for fw inception decide (T-973)
    mkdir -p "$PROJECT_ROOT/.context/working" 2>/dev/null
    touch "$PROJECT_ROOT/.context/working/.reviewed-${task_id}" 2>/dev/null || true
    # T-1090: Announce the marker side effect so the agent can discover the
    # T-973 unblock without having to read source. Previously the marker was
    # an invisible side effect that left agents stuck at the inception-decide
    # gate with no discoverable unblock path.
    echo -e "  ${CYAN}Review marker created:${NC} .context/working/.reviewed-${task_id}"
    echo -e "  ${CYAN}(unblocks${NC} fw inception decide ${task_id}${CYAN} — T-973 gate)${NC}"
    echo ""

    # T-2127 (T-2126 slice C): single-line footer guaranteed visible because
    # terminals scroll to end of output. Even on a 24-row terminal where the
    # header + URL + QR + everything else has scrolled off, this final line
    # is the last thing in the visible frame.
    echo -e "  → ${BOLD}Decide:${NC} ${review_url}"
    echo ""
}

# emit_review_batch — T-2182 / T-2181 Slice 1.
#
# Emit a markdown table of full Watchtower URLs for N tasks in one go. Lets the
# agent quote a class-correct, copy-pasteable handoff queue verbatim, instead of
# hand-typing a `/review/T-XXXX` table that drops the host:port (chat-output
# regression class — see T-2030 + T-2181 RCA).
#
# Usage: emit_review_batch T-A T-B T-C [...]
# Output: stdout — markdown table with columns | Task | Workflow | Link |
# Returns: 0 on success, 1 if no task IDs supplied.
#
# Class correctness: each URL routes to /inception/<id> for workflow_type=inception,
# /review/<id> otherwise (mirrors emit_review's branch — same source of truth).
# Unknown task IDs render with workflow=? and link=NOT-FOUND, never crash.
emit_review_batch() {
    if [ $# -lt 1 ]; then
        echo "ERROR: emit_review_batch requires ≥1 task ID" >&2
        echo "Usage: emit_review_batch T-A T-B [...]" >&2
        return 1
    fi

    # T-2206 (Slice C): pre-pass — refuse the entire batch when any inception
    # task in it has an empty ## Recommendation block, unless
    # FW_ALLOW_EMPTY_RECOMMENDATION=1. Producer/consumer parity with T-2205
    # Write/Edit hook (same env var, same intent: don't hand off blank pages).
    if ! declare -F audit_inception_recommendation >/dev/null 2>&1; then
        source "${FRAMEWORK_ROOT:-.}/lib/task-audit.sh" 2>/dev/null || true
    fi
    if declare -F audit_inception_recommendation >/dev/null 2>&1; then
        local empty_recs=""
        local tid_check
        for tid_check in "$@"; do
            local tf=""
            for f in "$PROJECT_ROOT/.tasks/active/$tid_check"*.md "$PROJECT_ROOT/.tasks/completed/$tid_check"*.md; do
                if [ -f "$f" ]; then
                    tf="$f"
                    break
                fi
            done
            [ -z "$tf" ] && continue  # NOT-FOUND handled in main loop
            local wt
            wt=$(grep -m1 'workflow_type:' "$tf" 2>/dev/null | sed 's/.*workflow_type:[[:space:]]*//' | tr -d '[:space:]')
            if [ "$wt" = "inception" ]; then
                if ! audit_inception_recommendation "$tf" 2>/dev/null; then
                    empty_recs="${empty_recs} ${tid_check}"
                fi
            fi
        done
        if [ -n "$empty_recs" ]; then
            if [ "${FW_ALLOW_EMPTY_RECOMMENDATION:-}" = "1" ]; then
                local t
                for t in $empty_recs; do
                    _log_empty_recommendation_bypass "$t" "emit_review_batch" "(batch)"
                done
                echo -e "  ${YELLOW}NOTE: batch contains inceptions with empty ## Recommendation:${empty_recs}${NC}" >&2
                echo -e "  ${YELLOW}emission allowed via FW_ALLOW_EMPTY_RECOMMENDATION=1 (logged).${NC}" >&2
            else
                echo "" >&2
                echo -e "  ${RED}══════════════════════════════════════════${NC}" >&2
                echo -e "  ${RED}BLOCKED: batch contains inceptions with empty ## Recommendation${NC}" >&2
                echo -e "  ${RED}══════════════════════════════════════════${NC}" >&2
                echo "" >&2
                echo -e "  Task(s) with empty Recommendation:${empty_recs}" >&2
                echo "" >&2
                echo -e "  Handoff table refuses emission — operator would see blank" >&2
                echo -e "  decision forms on /inception/<id> for those tasks." >&2
                echo "" >&2
                echo -e "  To proceed, choose ONE:" >&2
                echo "" >&2
                echo -e "    1. Edit each listed task's ## Recommendation block:" >&2
                echo -e "         **Recommendation:** GO | NO-GO | DEFER" >&2
                echo -e "         **Rationale:** <evidence-cited reasoning>" >&2
                echo "" >&2
                echo -e "    2. Override (logged Tier 2):" >&2
                echo -e "         FW_ALLOW_EMPTY_RECOMMENDATION=1 fw task review-batch$* " >&2
                echo "" >&2
                echo -e "  Origin: T-2204 (recommendation-completeness gate has bypass paths)," >&2
                echo -e "  T-2205 (Slice B, Write/Edit hook), T-2206 (this Slice C)." >&2
                echo "" >&2
                return 1
            fi
        fi
    fi

    local base_url
    base_url=$(_watchtower_url "$1")

    echo "| Task | Workflow | Link |"
    echo "|------|----------|------|"

    local tid
    for tid in "$@"; do
        local task_file=""
        for f in "$PROJECT_ROOT/.tasks/active/$tid"*.md "$PROJECT_ROOT/.tasks/completed/$tid"*.md; do
            if [ -f "$f" ]; then
                task_file="$f"
                break
            fi
        done
        if [ -z "$task_file" ]; then
            echo "| $tid | ? | NOT-FOUND |"
            continue
        fi

        local wtype
        wtype=$(grep -m1 'workflow_type:' "$task_file" 2>/dev/null | sed 's/.*workflow_type:[[:space:]]*//' | tr -d '[:space:]')
        local url
        if [ "$wtype" = "inception" ]; then
            url="${base_url}/inception/${tid}"
        else
            url="${base_url}/review/${tid}"
        fi
        echo "| $tid | ${wtype:-build} | $url |"
    done
}

# T-2206: log FW_ALLOW_EMPTY_RECOMMENDATION=1 bypass usage to gate-bypass-log
# (mirrors check-inception-recommendation.py log_bypass shape for parity).
_log_empty_recommendation_bypass() {
    local task_id="${1:-unknown}"
    local caller="${2:-emit_review}"
    local file_path="${3:-}"
    local log_dir="${PROJECT_ROOT:-.}/.context/working"
    mkdir -p "$log_dir" 2>/dev/null || return 0
    local log_file="$log_dir/.gate-bypass-log.yaml"
    local ts
    ts=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    {
        echo "- timestamp: '${ts}'"
        echo "  task: '${task_id}'"
        echo "  flag: 'FW_ALLOW_EMPTY_RECOMMENDATION'"
        echo "  caller: '${caller}'"
        echo "  file: '${file_path}'"
        echo "  reason: 'empty-recommendation bypass'"
    } >> "$log_file" 2>/dev/null || true
}
