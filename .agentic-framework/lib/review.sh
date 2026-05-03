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

    # T-1215 / T-1545: Warn if inception task has no substantive ## Recommendation.
    #
    # T-1545 origin: prior implementation used sed|grep -v|...|head -1 which,
    # on a fully-empty Recommendation section, exited non-zero (every grep -v
    # filtered every line). Under `set -e -o pipefail` (set in bin/fw) the
    # regular variable assignment propagated that failure and aborted
    # emit_review silently — exit 1, empty stdout/stderr, no review marker.
    #
    # Fix: delegate to audit_inception_recommendation (awk-based, pipefail-safe,
    # handles multi-line HTML-comment placeholders that the old line-anchored
    # `^<!--` detector missed in pickup-template skeletons).
    if [ "$workflow_type" = "inception" ]; then
        if ! declare -F audit_inception_recommendation >/dev/null 2>&1; then
            source "${FRAMEWORK_ROOT:-.}/lib/task-audit.sh" 2>/dev/null || true
        fi
        if declare -F audit_inception_recommendation >/dev/null 2>&1; then
            if ! audit_inception_recommendation "$task_file" 2>/dev/null; then
                echo "" >&2
                echo -e "  ${YELLOW}WARNING: No substantive ## Recommendation written yet${NC}" >&2
                echo -e "  ${YELLOW}The human will see a bare decision card on /approvals.${NC}" >&2
                echo -e "  ${YELLOW}Write a recommendation before presenting for review.${NC}" >&2
                echo "" >&2
            fi
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
}
