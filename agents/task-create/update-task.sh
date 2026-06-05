#!/bin/bash
# Task Update Agent - Status transitions with auto-triggers
#
# Updates task frontmatter and triggers structural actions:
#   issues/blocked  → auto-diagnose via healing agent
#   work-completed  → set date_finished, move to completed/, generate episodic
#
# Usage:
#   ./agents/task-create/update-task.sh T-XXX --status issues
#   ./agents/task-create/update-task.sh T-XXX --status work-completed
#   ./agents/task-create/update-task.sh T-XXX --owner claude-code
#   ./agents/task-create/update-task.sh T-XXX --status blocked --reason "Waiting on API key"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"

# Colors provided by lib/colors.sh (via paths.sh chain)

# Source enumerations (single source of truth)
source "$FRAMEWORK_ROOT/lib/enums.sh"

# Per-key locking for concurrent task updates (T-587)
source "$FRAMEWORK_ROOT/lib/keylock.sh" 2>/dev/null || true

# Render-surface predicate (T-1766)
source "$FRAMEWORK_ROOT/lib/render_surface.sh" 2>/dev/null || true

# === Extracted gate functions (T-415) ===
# Each function accesses outer-scope variables: TASK_FILE, TASK_ID, SKIP_*, colors

# Gate bypass audit log (T-1142)
log_gate_bypass() {
    local flag="$1" caller="${2:-manual}"
    local log_file="$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    # T-1861: escape embedded single quotes per YAML single-quoted-scalar rule
    # (' → ''). Reason is user-controlled text; without escaping, any apostrophe
    # or single-quoted snippet inside reason breaks yaml.safe_load (audit-data
    # corruption surfaced 2026-05-15 on log line 390).
    local _esc_ts="${timestamp//\'/\'\'}"
    local _esc_task="${TASK_ID//\'/\'\'}"
    local _esc_flag="${flag//\'/\'\'}"
    local _esc_caller="${caller//\'/\'\'}"
    local _esc_reason="${REASON//\'/\'\'}"
    echo "- timestamp: '$_esc_ts'" >> "$log_file"
    echo "  task: '$_esc_task'" >> "$log_file"
    echo "  flag: '$_esc_flag'" >> "$log_file"
    echo "  caller: '$_esc_caller'" >> "$log_file"
    echo "  reason: '${_esc_reason:-}'" >> "$log_file"
}

# Human Sovereignty Gate (R-033/T-198)
# Block agent from completing human-owned tasks without human interaction.
check_human_sovereignty() {
    local current_owner
    current_owner=$({ grep "^owner:" "$TASK_FILE" 2>/dev/null || true; } | head -1 | sed 's/owner:[[:space:]]*//')
    if [ "$current_owner" = "human" ]; then
        if [ "$SKIP_SOVEREIGNTY" = true ]; then
            echo -e "${YELLOW}WARNING: Completing human-owned task (--skip-sovereignty bypass)${NC}"
            log_gate_bypass "--skip-sovereignty" "check_human_sovereignty"
        else
            echo -e "${RED}ERROR: Cannot complete human-owned task${NC}" >&2
            echo "Sovereignty gate (R-033): owner is human." >&2
            echo "The human must review and approve via Watchtower:" >&2
            # T-1156: Show Watchtower review link instead of bare commands (PL-007)
            source "$FRAMEWORK_ROOT/lib/review.sh" 2>/dev/null
            emit_review "$TASK_ID" "$TASK_FILE" >&2 2>/dev/null || true
            exit 1
        fi
    fi
}

# Acceptance Criteria Gate (P-010)
# T-193: Supports ### Agent / ### Human AC split.
# Sets PARTIAL_COMPLETE=true if human ACs remain unchecked.
check_acceptance_criteria() {
    local ac_section has_agent_header has_human_header
    local agent_acs ac_total ac_checked ac_unchecked ac_label
    local human_acs placeholder_acs placeholder_count

    ac_section=$(sed -n '/^## Acceptance Criteria/,/^## /p' "$TASK_FILE" 2>/dev/null | sed '$d')
    # Strip HTML comments — template examples contain checkbox patterns that get miscounted.
    # T-1967 (L-414 root cause): sed range matching does NOT close on the same line where
    # it opens — `/<!--/,/-->/d` on a one-line `<!-- ... -->` enters delete-mode at that
    # line and stays there until the NEXT `-->` later in the file, swallowing Agent ACs.
    # Fix: strip one-line comments first, then run the range strip for genuine multi-line.
    ac_section=$(echo "$ac_section" | sed -E 's/<!--[^>]*-->//g' | sed '/<!--/,/-->/d')
    [ -z "$ac_section" ] && return 0

    has_agent_header=$(echo "$ac_section" | grep -c '^### Agent' || true)
    has_human_header=$(echo "$ac_section" | grep -c '^### Human' || true)

    if [ "$has_agent_header" -gt 0 ]; then
        agent_acs=$(echo "$ac_section" | awk '/^### Agent/{f=1; next} /^### /{f=0} f')
        ac_total=$(echo "$agent_acs" | grep -cE '^\s*-\s*\[[ x]\]' || true)
        ac_checked=$(echo "$agent_acs" | grep -cE '^\s*-\s*\[x\]' || true)
        ac_unchecked=$((ac_total - ac_checked))
        ac_label="agent AC"

        HUMAN_AC_TOTAL=0
        HUMAN_AC_CHECKED=0
        if [ "$has_human_header" -gt 0 ]; then
            human_acs=$(echo "$ac_section" | awk '/^### Human/{f=1; next} /^### /{f=0} f')
            HUMAN_AC_TOTAL=$(echo "$human_acs" | grep -cE '^\s*-\s*\[[ x]\]' || true)
            HUMAN_AC_CHECKED=$(echo "$human_acs" | grep -cE '^\s*-\s*\[x\]' || true)
        fi
    else
        ac_total=$(echo "$ac_section" | grep -cE '^\s*-\s*\[[ x]\]' || true)
        ac_checked=$(echo "$ac_section" | grep -cE '^\s*-\s*\[x\]' || true)
        ac_unchecked=$((ac_total - ac_checked))
        ac_label="acceptance criteria"
        HUMAN_AC_TOTAL=0
        HUMAN_AC_CHECKED=0
    fi

    # Gate: unchecked ACs block completion
    if [ "$ac_total" -gt 0 ] && [ "$ac_unchecked" -gt 0 ]; then
        if [ "$SKIP_AC" = true ]; then
            echo -e "${YELLOW}WARNING: $ac_unchecked/$ac_total $ac_label unchecked (--skip-acceptance-criteria bypass)${NC}"
            log_gate_bypass "--skip-acceptance-criteria" "check_acceptance_criteria"
        else
            echo -e "${RED}ERROR: Cannot complete — $ac_unchecked/$ac_total $ac_label unchecked:${NC}" >&2
            if [ "$has_agent_header" -gt 0 ]; then
                echo "$agent_acs" | grep -E '^\s*-\s*\[ \]' | sed 's/^/  /' >&2
            else
                echo "$ac_section" | grep -E '^\s*-\s*\[ \]' | sed 's/^/  /' >&2
            fi
            echo "" >&2
            # T-1836 (T-1831 C-3): surface body-vs-checkbox drift hint.
            # Detect whether the task has a filled (non-template) ## Recommendation
            # block — strong signal that substantive content was written. When
            # present, prompt agent to tick boxes that correspond to completed work
            # rather than re-doing the work. CLAUDE.md §Progressive AC ticking is
            # the procedural rule; this message surfaces it at the point of refusal.
            local _rec_block _rec_filled=false
            _rec_block=$(sed -n '/^## Recommendation/,/^## /p' "$TASK_FILE" 2>/dev/null | sed '$d')
            if [ -n "$_rec_block" ] && echo "$_rec_block" | grep -qE '^\*\*(Recommendation|Rationale|Evidence)(:\*\*|\*\*:)'; then
                _rec_filled=true
            fi
            if [ "$_rec_filled" = true ]; then
                echo -e "${YELLOW}Hint:${NC} task body has a filled \`## Recommendation\` block — AC content likely present." >&2
                echo "  Tick the [x] boxes for each AC whose work is in place." >&2
                echo "  Re-doing the work is not the answer; this is the body-vs-checkbox drift class." >&2
                echo "  See CLAUDE.md §Verification Before Completion → Progressive AC ticking (T-1831 C-4)." >&2
                echo "" >&2
            else
                echo -e "${YELLOW}Hint:${NC} if you wrote AC content in the body but didn't tick boxes, see" >&2
                echo "  CLAUDE.md §Verification Before Completion → Progressive AC ticking (T-1831 C-4)." >&2
                echo "" >&2
            fi
            echo "Options:" >&2
            echo "  1. Check the criteria in the task file, then retry" >&2
            echo "  2. Use --skip-acceptance-criteria to bypass (logged)" >&2
            exit 1
        fi
    elif [ "$ac_total" -gt 0 ]; then
        # Placeholder detection: reject skeleton/template ACs
        placeholder_acs=""
        if [ "$has_agent_header" -gt 0 ]; then
            placeholder_acs=$(echo "$agent_acs" | grep -iE '^\s*-\s*\[x\]\s*\[(First|Second|Third|Fourth|Fifth) criterion\]' || true)
            [ -z "$placeholder_acs" ] && placeholder_acs=$(echo "$agent_acs" | grep -iE '^\s*-\s*\[x\]\s*\[Criterion [0-9]+\]' || true)
        else
            placeholder_acs=$(echo "$ac_section" | grep -iE '^\s*-\s*\[x\]\s*\[(First|Second|Third|Fourth|Fifth) criterion\]' || true)
            [ -z "$placeholder_acs" ] && placeholder_acs=$(echo "$ac_section" | grep -iE '^\s*-\s*\[x\]\s*\[Criterion [0-9]+\]' || true)
        fi

        if [ -n "$placeholder_acs" ]; then
            if [ "$SKIP_AC" = true ]; then
                echo -e "${YELLOW}WARNING: Skeleton/placeholder ACs detected (--skip-acceptance-criteria bypass)${NC}"
                log_gate_bypass "--skip-acceptance-criteria" "placeholder_detection"
            else
                placeholder_count=$(echo "$placeholder_acs" | wc -l)
                echo -e "${RED}ERROR: Cannot complete — $placeholder_count $ac_label are skeleton placeholders:${NC}" >&2
                # shellcheck disable=SC2001 # multi-line prefix — can't use ${//}
                echo "$placeholder_acs" | sed 's/^/  /' >&2
                echo "" >&2
                echo "Replace placeholder text with real, specific acceptance criteria." >&2
                echo "Options:" >&2
                echo "  1. Edit the task file with real ACs, then retry" >&2
                echo "  2. Use --skip-acceptance-criteria to bypass (logged)" >&2
                exit 1
            fi
        else
            echo -e "${GREEN}Acceptance criteria: $ac_checked/$ac_total checked ✓${NC}"
        fi
    fi

    # Report human AC status if split mode (T-193)
    if [ "$has_agent_header" -gt 0 ] && [ "$HUMAN_AC_TOTAL" -gt 0 ]; then
        local human_ac_unchecked=$((HUMAN_AC_TOTAL - HUMAN_AC_CHECKED))
        if [ "$human_ac_unchecked" -gt 0 ]; then
            echo -e "${YELLOW}Human: $HUMAN_AC_CHECKED/$HUMAN_AC_TOTAL checked (not blocking)${NC}"
            PARTIAL_COMPLETE=true
        else
            echo -e "${GREEN}Human: $HUMAN_AC_CHECKED/$HUMAN_AC_TOTAL checked ✓${NC}"
        fi
    fi
}

# Recommendation Gate (T-679 / T-1529 / T-1572 F6)
# Fires when ANY needs-human signal is true:
#   1. PARTIAL_COMPLETE=true (Human ACs remain — original T-679 trigger)
#   2. Frontmatter `human_signoff: required`
#   3. Frontmatter `risk: high` or `risk: medium`
#   4. Prior `## Reviewer Verdict` block declares `Needs Human: yes`
# This aligns the artefact gate with the reviewer's classification
# (lib/reviewer/static_scan.py:668). T-1565 audit F6: a task with
# `human_signoff: required` and no Human ACs in body could complete silently
# with no Recommendation written — the reviewer flagged it; the gate didn't.
# OBS-031: 19/22 awaiting-review tasks were blank because T-679 was advisory only.
# L-293: uses H2+ terminator to avoid false-positives from appended Updates entries.
check_recommendation_for_review() {
    # T-1572 F6: compute unified needs_human flag (PARTIAL_COMPLETE OR
    # frontmatter signals OR prior reviewer verdict).
    local needs_human="false"
    if [ "${PARTIAL_COMPLETE:-false}" = true ]; then
        needs_human="true"
    else
        needs_human=$(python3 - "$TASK_FILE" <<'PYNH' 2>/dev/null || echo false
import sys, re
try:
    text = open(sys.argv[1]).read()
except OSError:
    print("false"); sys.exit(0)
fm_m = re.match(r"^---\s*\n(.*?)\n---", text, re.DOTALL)
fm = fm_m.group(1) if fm_m else ""
if re.search(r"^human_signoff:\s*[\"']?required\b", fm, re.MULTILINE):
    print("true"); sys.exit(0)
if re.search(r"^risk:\s*[\"']?(high|medium)\b", fm, re.MULTILINE | re.IGNORECASE):
    print("true"); sys.exit(0)
v_m = re.search(r"^## Reviewer Verdict \(v[0-9.]+\)[^\n]*\n(.*?)(?=^#{2,} |\Z)",
                text, re.MULTILINE | re.DOTALL)
if v_m and re.search(r"^- \*\*Needs Human:\*\*\s*yes\b",
                     v_m.group(1), re.MULTILINE | re.IGNORECASE):
    print("true"); sys.exit(0)
print("false")
PYNH
)
    fi
    [ "$needs_human" = "true" ] || return 0

    local rec_state
    rec_state=$(python3 - "$TASK_FILE" <<'PYREC' 2>/dev/null || echo "error"
import sys, re
try:
    text = open(sys.argv[1]).read()
except OSError:
    print("error"); sys.exit(0)
m = re.search(r'^## Recommendation\s*$(.*?)(?=^#{2,} |\Z)', text, re.MULTILINE | re.DOTALL)
if not m:
    print("missing"); sys.exit(0)
body = re.sub(r'<!--.*?-->', '', m.group(1), flags=re.DOTALL)
if re.search(r'^\s*[-*]?\s*\*\*Recommendation:\*\*\s*\S', body, re.MULTILINE):
    print("ok")
else:
    print("empty")
PYREC
)

    case "$rec_state" in
        ok)
            echo -e "${GREEN}Recommendation: substantive ✓${NC}"
            return 0 ;;
        error)
            return 0 ;;
        missing|empty)
            if [ "$SKIP_RECOMMENDATION" = true ]; then
                echo -e "${YELLOW}WARNING: Recommendation $rec_state (--skip-recommendation bypass)${NC}"
                log_gate_bypass "--skip-recommendation" "check_recommendation_for_review"
                return 0
            fi
            echo -e "${RED}ERROR: Cannot complete — task needs human review but ## Recommendation is $rec_state.${NC}" >&2
            echo "" >&2
            echo "T-679 (CLAUDE.md): never present a blank decision to the human." >&2
            echo "Reviewers will see /review/$(basename "$TASK_FILE" .md | grep -oE '^T-[0-9]+') with no agent advisory." >&2
            echo "" >&2
            echo "Add a ## Recommendation block to $TASK_FILE with:" >&2
            echo "  **Recommendation:** GO / NO-GO / DEFER" >&2
            echo "  **Rationale:** <why — cite evidence>" >&2
            echo "  **Evidence:** <bullets — file paths, test results, metrics>" >&2
            echo "" >&2
            echo "Options:" >&2
            echo "  1. Add the Recommendation block, then retry" >&2
            echo "  2. Use --skip-recommendation to bypass (logged)" >&2
            exit 1
            ;;
    esac
}

# T-679: Auto-emit review on partial-complete transition
# Called after work-completed transition when human ACs remain.
# Also available standalone: fw task review T-XXX
auto_emit_review_if_partial() {
    if [ "${PARTIAL_COMPLETE:-false}" = true ]; then
        echo ""
        echo -e "${BOLD}Present this to the human for review:${NC}"
        if [ -f "$FRAMEWORK_ROOT/lib/review.sh" ]; then
            source "$FRAMEWORK_ROOT/lib/review.sh"
            emit_review "$TASK_ID" "$TASK_FILE"
        else
            echo "  $(_emit_user_command "task review $TASK_ID")"
        fi
    fi
}

# RCA Gate (T-1550, structural remediation for G-019)
# Fires on --status work-completed for bug-class tasks. Requires non-empty
# `## RCA` body content so root cause is captured at the source, not lost.
# Bug-class = workflow_type ∉ {inception, specification, design} AND
#             (tags match bug|bugfix|hotfix|rca|incident OR title matches
#              fix|bug|rca|broken|crash|error|regression|fail|hotfix).
# Origin: T-1549 spike showed 99% (315/317) of bug-class tasks lacked RCA —
# template + gate gap, not behavior. CLAUDE.md §"Post-Fix Root Cause Escalation"
# previously advisory only.
check_rca_for_bugfix() {
    [ "$NEW_STATUS" = "work-completed" ] || return 0

    local task_title task_type task_tags is_bug
    task_title=$(grep '^name:' "$TASK_FILE" | head -1 | sed 's/name:[[:space:]]*//' | tr -d '"')
    task_type=$(grep '^workflow_type:' "$TASK_FILE" | head -1 | sed 's/workflow_type:[[:space:]]*//' | tr -d '"' | tr -d "'")
    task_tags=$(grep '^tags:' "$TASK_FILE" | head -1 | sed 's/tags:[[:space:]]*//')

    # Non-bug workflow types never gate on RCA, regardless of title keywords
    # (T-2132: "fix request" / "feature request" tasks are not bug fixes).
    case "$task_type" in
        inception|specification|design|request|feature|enhancement|decommission) return 0 ;;
    esac

    # Explicit feature/request tags also suppress bug-class (T-2132).
    if echo "$task_tags" | grep -qiE '\b(feature|request|enhancement)\b'; then
        return 0
    fi

    # Strip request/ask/proposal/feature contexts before keyword classification
    # so "fix request", "feature request", etc. don't trip the "fix" substring
    # match (T-2132). Order matters: longer phrases first.
    local title_for_classify
    title_for_classify=$(echo "$task_title" | sed -E 's/\b(upstream )?(fix request|request to fix|ask to fix|fix proposal|proposal to fix|feature request|enhancement request|feature[^.]*fix)\b//gi')

    is_bug=false
    if echo "$task_tags" | grep -qiE '\b(bug|bugfix|hotfix|rca|incident)\b'; then
        is_bug=true
    elif echo "$title_for_classify" | grep -qiE '\b(fix|bug|rca|broken|crash|error|regression|fail|hotfix)\b'; then
        is_bug=true
    fi
    [ "$is_bug" = true ] || return 0

    local rca_state
    rca_state=$(python3 - "$TASK_FILE" <<'PYRCA' 2>/dev/null || echo "error"
import sys, re
try:
    text = open(sys.argv[1]).read()
except OSError:
    print("error"); sys.exit(0)
m = re.search(r'^## RCA\s*$(.*?)(?=^#{2,} |\Z)', text, re.MULTILINE | re.DOTALL)
if not m:
    print("missing"); sys.exit(0)
body = re.sub(r'<!--.*?-->', '', m.group(1), flags=re.DOTALL)
real = [l for l in body.splitlines() if l.strip() and not l.strip().startswith('#')]
substantive = [l for l in real if len(l) > 30]
print("ok" if substantive else "empty")
PYRCA
)

    case "$rca_state" in
        ok)
            echo -e "${GREEN}RCA: substantive ✓${NC}"
            return 0 ;;
        error)
            return 0 ;;
        missing|empty)
            if [ "$SKIP_RCA" = true ]; then
                echo -e "${YELLOW}WARNING: RCA $rca_state (--skip-rca bypass)${NC}"
                log_gate_bypass "--skip-rca" "check_rca_for_bugfix"
                return 0
            fi
            echo -e "${RED}ERROR: Cannot complete bug-class task — ## RCA section is $rca_state.${NC}" >&2
            echo "" >&2
            echo "G-019 (CLAUDE.md): bug-fixes must capture root cause, not just the patch." >&2
            echo "T-1549 spike showed 99% of bug-class tasks shipped without RCA capture." >&2
            echo "" >&2
            echo "Add a ## RCA block to $TASK_FILE with:" >&2
            echo "  **Symptom:** what was observed" >&2
            echo "  **Root cause:** why it happened (specific structural/logical gap)" >&2
            echo "  **Why structurally allowed:** what let this go undetected" >&2
            echo "  **Prevention:** what catches the next instance (test/lint/gate/doc/learning)" >&2
            echo "" >&2
            echo "Options:" >&2
            echo "  1. Add the RCA block, then retry" >&2
            echo "  2. Use --skip-rca to bypass (logged, T-1550)" >&2
            exit 1
            ;;
    esac
}

# Render-surface Human-AC Gate (T-1766, P-013)
# Fires on --status work-completed for build tasks whose components or body
# references touch a render surface (web/templates, web/static, web/blueprints,
# web/shared.py, etc.). Requires at least one Human AC prefixed with
# [REVIEW] — visual/UX correctness is inherently subjective and cannot
# be settled by curl/grep alone.
#
# Origin: T-1763, T-1764, T-1765 — three render-surface bug fixes shipped
# with zero Human ACs. Each fix verified technically (HTTP code, computed
# style, regex) but no human looked at the rendered output. The user caught
# the omission and asked for RCA + structural fix.
#
# Predicate lives in lib/render_surface.sh (single source of truth for
# RENDER_SURFACE_PATTERNS). [RUBBER-STAMP] does NOT satisfy the gate —
# rubber-stamp is mechanical; render judgment is what makes Human ACs
# load-bearing here.
check_render_surface_human_ac() {
    [ "$NEW_STATUS" = "work-completed" ] || return 0

    # Library may have failed to source (defensive — should not happen in normal flow).
    if ! declare -F task_touches_render_surface >/dev/null 2>&1; then
        return 0
    fi

    local task_type
    task_type=$(grep '^workflow_type:' "$TASK_FILE" | head -1 | sed 's/workflow_type:[[:space:]]*//' | tr -d '"' | tr -d "'")
    case "$task_type" in
        inception|specification|design|decommission) return 0 ;;
    esac
    [ "$task_type" = "build" ] || [ "$task_type" = "refactor" ] || [ "$task_type" = "test" ] || return 0

    if ! task_touches_render_surface "$TASK_FILE"; then
        return 0
    fi

    local review_state
    review_state=$(python3 - "$TASK_FILE" <<'PYREV' 2>/dev/null || echo "error"
import sys, re
try:
    text = open(sys.argv[1]).read()
except OSError:
    print("error"); sys.exit(0)
# T-1901: scan ALL `### Human` blocks (not just the first). When a task has
# a template-comment Human block + a separate ACs Human block, the prior
# `re.search` only saw the template block and returned "empty". `re.finditer`
# captures every block; we union their content before scanning for [REVIEW].
matches = list(re.finditer(r'^### Human\s*$(.*?)(?=^#{2,} |\Z)', text, re.MULTILINE | re.DOTALL))
if not matches:
    print("no_section"); sys.exit(0)
human = "\n".join(m.group(1) for m in matches)
human = re.sub(r'<!--.*?-->', '', human, flags=re.DOTALL)
review_lines = [l for l in human.splitlines() if re.match(r'\s*-\s*\[[ x]\]\s*\[REVIEW\]', l)]
if review_lines:
    print("has_review"); sys.exit(0)
ac_lines = [l for l in human.splitlines() if re.match(r'\s*-\s*\[[ x]\]', l)]
print("only_other" if ac_lines else "empty")
PYREV
)

    case "$review_state" in
        has_review)
            echo -e "${GREEN}Render-surface gate: [REVIEW] Human AC present ✓${NC}"
            return 0 ;;
        error)
            return 0 ;;
        *)
            if [ "$SKIP_RENDER_REVIEW" = true ]; then
                echo -e "${YELLOW}WARNING: render-surface task without [REVIEW] Human AC (--skip-render-review bypass)${NC}"
                log_gate_bypass "--skip-render-review" "check_render_surface_human_ac: $SKIP_RENDER_REVIEW_REASON"
                return 0
            fi
            local matched
            # T-1900: was `... | head -3 | sed`. Under set -eo pipefail, head's
            # stdin-close after 3 lines sent SIGPIPE upstream → exit 141 →
            # set -e killed the script BEFORE printing the error below.
            # awk reads to EOF and never closes its stdin early, so no SIGPIPE.
            matched=$(render_surface_files_in "$TASK_FILE" 2>/dev/null | awk 'NR<=3 { print "    - " $0 }')
            echo -e "${RED}ERROR: Cannot complete build task — touches render surface but has no [REVIEW] Human AC.${NC}" >&2
            echo "" >&2
            echo "T-1766 (P-013): Visual/UX changes need eyes, not only tests." >&2
            echo "Origin: T-1763/T-1764/T-1765 — three render fixes shipped without any human" >&2
            echo "looking at the rendered output. Subjective judgment cannot be deferred to curl/grep." >&2
            echo "" >&2
            echo "This task touches:" >&2
            echo "$matched" >&2
            echo "" >&2
            echo "Add a [REVIEW] Human AC to $TASK_FILE describing what the human should look at," >&2
            echo "for example:" >&2
            echo "  - [ ] [REVIEW] Rendered output on /review/T-XXX looks correct (no layout break, no orphan inline code)" >&2
            echo "    **Steps:** 1. Open the URL  2. Compare with the screenshot in Evidence" >&2
            echo "    **Expected:** Element renders as inline block, no wrap, no stray punctuation" >&2
            echo "    **If not:** Note the diff and reopen for follow-up" >&2
            echo "" >&2
            echo "Options:" >&2
            echo "  1. Add the [REVIEW] Human AC, then retry" >&2
            echo "  2. Use --skip-render-review \"rationale\" to bypass (logged Tier-2, T-1766)" >&2
            exit 1 ;;
    esac
}

# Inception-decision Gate (T-1626, structural remediation for G-052)
# Fires on --status work-completed for inception tasks. Requires a
# `**Decision**: GO|NO-GO|DEFER` line in the task body — i.e. the operator
# has run `fw inception decide T-XXX <go|no-go|defer>`.
#
# Origin: G-052 (2026-04-30). T-1448 inception got silently moved active->completed
# during an unrelated heartbeat-script commit. The commit-msg inception gate is
# only a BLOCK-on-commit; it does not catch the lifecycle path that finalizes
# tasks via update-task.sh. Without this gate, an inception decision queue can
# silently empty - operator visibility into pending decisions is lost.
check_inception_decision() {
    [ "$NEW_STATUS" = "work-completed" ] || return 0

    local task_type
    task_type=$(grep '^workflow_type:' "$TASK_FILE" | head -1 | sed 's/workflow_type:[[:space:]]*//' | tr -d '"' | tr -d "'")
    [ "$task_type" = "inception" ] || return 0

    if grep -qE '^\*\*Decision\*\*:[[:space:]]*(GO|NO-GO|DEFER)\b' "$TASK_FILE"; then
        echo -e "${GREEN}Inception decision: recorded \xE2\x9C\x93${NC}"
        return 0
    fi

    if [ "$SKIP_INCEPTION_DECISION" = true ]; then
        echo -e "${YELLOW}WARNING: inception decision missing (--skip-inception-decision bypass)${NC}"
        log_gate_bypass "--skip-inception-decision" "check_inception_decision"
        return 0
    fi

    echo -e "${RED}ERROR: Cannot complete inception task - no decision recorded.${NC}" >&2
    echo "" >&2
    echo "G-052 (CLAUDE.md Inception Discipline): inception tasks must produce a" >&2
    echo "go/no-go/defer decision. Silent completion empties the operator's" >&2
    echo "decision queue and loses visibility into pending exploration outcomes." >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  1. Record the decision: fw inception decide $(basename "$TASK_FILE" .md | grep -oE '^T-[0-9]+') go|no-go|defer --rationale '...'" >&2
    echo "  2. Use --skip-inception-decision to bypass (logged, T-1626)" >&2
    exit 1
}

# Inception GO-scope Trace Gate (T-1984, structural prevention for G-066)
# Fires on --status work-completed for workflow_type: inception tasks that
# have a non-empty inception_decisions: frontmatter field.
# Parses each decision's ships_in: referent and validates reachability:
#   - file path        → PROJECT_ROOT/<path> must exist
#   - module.function  → symbol grepped in lib/ / agents/ / bin/
#   - path::test_func  → file exists + function in it
#   - T-XXX            → task in .tasks/completed/
#   - deferred:T-YYYY  → task in .tasks/{active,completed}/
#
# Grandfathering: if inception_decisions: is empty/missing, gate is silent.
# Bypass parity (L-399, T-1890):
#   Direct invocation:  --skip-inception-scope-trace "rationale"
#   Indirect/git-hook:  FW_SKIP_INCEPTION_SCOPE_TRACE=1
#
# Origin: T-1983 GO — closes G-066 (T-1442/T-1443 drifted 26 days after
# inception close; no gate existed for GO-scope vs shipped deliverables).
check_inception_scope_trace() {
    [ "$NEW_STATUS" = "work-completed" ] || return 0

    local task_type
    task_type=$(grep '^workflow_type:' "$TASK_FILE" | head -1 \
        | sed 's/workflow_type:[[:space:]]*//' | tr -d '"' | tr -d "'")
    [ "$task_type" = "inception" ] || return 0

    # Grandfather: if python3 unavailable, skip silently (don't block on missing toolchain)
    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${YELLOW}WARN: python3 not found — skip inception-scope-trace check${NC}"
        return 0
    fi

    # Grandfather: if lib/inception_decisions.py unavailable, skip silently
    local lib_py="$FRAMEWORK_ROOT/lib/inception_decisions.py"
    [ -f "$lib_py" ] || return 0

    # Run reachability check via Python helper
    # Returns: "OK" or one failure per line prefixed with "FAIL:"
    local py_output failures
    py_output=$(python3 - "$TASK_FILE" "$PROJECT_ROOT" <<'PYEOF'
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
# argv[0] = "-" (stdin), argv[1] = task_file, argv[2] = project_root
# But when called via bash heredoc, sys.argv may differ. Use env instead.
import os
task_file = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("TASK_FILE", "")
project_root = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("PROJECT_ROOT", ".")

from pathlib import Path
from lib.inception_decisions import parse_inception_decisions, check_ships_in_reachable

try:
    content = Path(task_file).read_text()
except Exception as e:
    print(f"IOERR: {e}")
    sys.exit(0)

result = parse_inception_decisions(content)
if not result.decisions:
    print("OK_EMPTY")
    sys.exit(0)

failures = []
for dec in result.decisions:
    if not dec.ships_in:
        continue
    err = check_ships_in_reachable(dec.ships_in, dec.id, Path(project_root))
    if err:
        failures.append(f"FAIL:{err}")

if failures:
    for f in failures:
        print(f)
else:
    print("OK")
PYEOF
    2>&1) || true

    # Parse output
    if echo "$py_output" | grep -q "^IOERR:"; then
        echo -e "${YELLOW}WARN: inception-scope-trace: could not read task file — skipping${NC}"
        return 0
    fi

    if echo "$py_output" | grep -q "^OK"; then
        echo -e "${GREEN}Inception GO-scope trace: all decisions have reachable ships_in \xE2\x9C\x93${NC}"
        return 0
    fi

    # Collect failures
    failures=$(echo "$py_output" | grep "^FAIL:" | sed 's/^FAIL://')

    # Check overrides (L-399 parity — both flag and env-var accepted)
    if [ "$SKIP_INCEPTION_SCOPE_TRACE" = true ]; then
        echo -e "${YELLOW}WARNING: inception-scope-trace bypassed (--skip-inception-scope-trace)${NC}"
        log_gate_bypass "--skip-inception-scope-trace" "check_inception_scope_trace"
        return 0
    fi

    if [ "${FW_SKIP_INCEPTION_SCOPE_TRACE:-0}" = "1" ]; then
        echo -e "${YELLOW}WARNING: inception-scope-trace bypassed (FW_SKIP_INCEPTION_SCOPE_TRACE=1)${NC}"
        log_gate_bypass "FW_SKIP_INCEPTION_SCOPE_TRACE" "check_inception_scope_trace"
        return 0
    fi

    local task_id_short
    task_id_short=$(basename "$TASK_FILE" | grep -oE '^T-[0-9]+')

    echo -e "${RED}ERROR: INCEPTION-SCOPE-TRACE gate (T-1984, G-066) — ships_in referents unresolved.${NC}" >&2
    echo "" >&2
    echo "Inception task $task_id_short has inception_decisions: entries whose" >&2
    echo "ships_in: referents are not yet reachable. The gate fires at close time" >&2
    echo "to confirm GO-scope actually landed before the inception is archived." >&2
    echo "" >&2
    echo "Failing decision(s):" >&2
    while IFS= read -r line; do
        echo "  - $line" >&2
    done <<< "$failures"
    echo "" >&2
    echo "To resolve: ensure each decision's ships_in: referent is reachable." >&2
    echo "  - file path      → create/ship the file" >&2
    echo "  - T-XXX          → task must be in .tasks/completed/" >&2
    echo "  - deferred:T-YYY → target task must exist in .tasks/{active,completed}/" >&2
    echo "" >&2
    echo "To override (Tier-2 logged, both required per L-399):" >&2
    echo "  Direct fw task update:  --skip-inception-scope-trace \"rationale\"" >&2
    echo "  Via git commit/wrapper: FW_SKIP_INCEPTION_SCOPE_TRACE=1 <command>" >&2
    echo "  When to pick which: use --skip flag when calling fw task update directly;" >&2
    echo "  use env-var when the call goes through git commit or other wrappers." >&2
    exit 1
}

# Evolution-log Gate (T-1718, structural counter to §ACD/G-062 family)
# Fires on --status work-completed for arc-tagged build tasks IF the task
# body already contains a `## Evolution` section (template opt-in: tasks
# created before T-1718 don't have the section, aren't gated). Requires
# at least one substantive (≥30 chars, comment-stripped, non-heading) line
# in the section body.
#
# Origin: T-1717 grill Q4 — "the understanding of what we need and want
# evolves with the process of materialisation." Same shape as T-1550 RCA
# gate: advisory CLAUDE.md text → structural enforcement.
check_evolution_log() {
    [ "$NEW_STATUS" = "work-completed" ] || return 0

    local task_type
    task_type=$(grep '^workflow_type:' "$TASK_FILE" | head -1 | sed 's/workflow_type:[[:space:]]*//' | tr -d '"' | tr -d "'")

    # Only build tasks
    [ "$task_type" = "build" ] || return 0

    # Source detection helper (provides task_has_arc_membership + log helpers)
    local lib_path="$FRAMEWORK_ROOT/lib/evolution_log.sh"
    [ -f "$lib_path" ] || return 0
    # shellcheck source=/dev/null
    source "$lib_path"

    # T-1879 (T-NEW-14): Only arc-member tasks — recognize both arc_id
    # (T-1849 canonical, T-1850 migrated) AND legacy arc:<slug> tag.
    # Pre-T-1879 grep on the tags line missed 162 migrated tasks.
    task_has_arc_membership "$TASK_FILE" || return 0

    # Backward-compat: if section absent, no-op
    has_evolution_section "$TASK_FILE" || return 0

    # Section exists — must be substantive
    if has_real_evolution_log "$TASK_FILE"; then
        echo -e "${GREEN}Evolution log: substantive ✓${NC}"
        return 0
    fi

    if [ "$SKIP_EVOLUTION" = true ]; then
        echo -e "${YELLOW}WARNING: Evolution log empty/template-only (--skip-evolution bypass)${NC}"
        log_gate_bypass "--skip-evolution" "check_evolution_log"
        return 0
    fi

    echo -e "${RED}ERROR: Cannot complete arc-tagged build task — ## Evolution section is empty/template-only.${NC}" >&2
    echo "" >&2
    echo "T-1718 (CLAUDE.md / T-1717 grill Q4): arc-tagged build tasks must capture how" >&2
    echo "understanding evolved during build. Spec-vs-build drift must be visible, not silent." >&2
    echo "" >&2
    echo "Add an entry to the ## Evolution section in $TASK_FILE:" >&2
    echo "" >&2
    echo "  ### YYYY-MM-DD — [topic]" >&2
    echo "  - **What changed:** [what we learned that we didn't know at filing]" >&2
    echo "  - **Plan impact:** [what in the plan no longer fits]" >&2
    echo "  - **Triggered:** [new sub-task / pivot / scope cut, with task ID]" >&2
    echo "" >&2
    echo "At least one substantive entry (≥30 chars on at least one line) is required." >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  1. Add the Evolution entry, then retry" >&2
    echo "  2. Use --skip-evolution to bypass (logged Tier-2, T-1718)" >&2
    exit 1
}

# Disposition-completeness gate (T-2190, T-2186 Slice 4)
# Inception tasks must dispose every declared question in the ## Open Questions
# body section. Each question gets answered / dissolved / deferred with cited
# evidence — never a bare checkbox. Refuses on under-disposed inceptions.
#
# Bypass family per T-1890 producer/consumer parity:
#   --skip-disposition-gate "rationale"  (direct CLI invocations)
#   FW_SKIP_DISPOSITION_GATE=1           (git/wrapper / env-only callers)
# Both logged Tier-2 to .context/working/.gate-bypass-log.yaml.
check_disposition_gate() {
    # Only fires on inception tasks
    local wf
    wf=$(grep -E "^workflow_type:" "$TASK_FILE" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'")
    if [ "$wf" != "inception" ]; then
        return 0
    fi

    # Backward-compat: if ## Open Questions section absent, no-op (grandfathered)
    if ! grep -qE "^## Open Questions" "$TASK_FILE"; then
        return 0
    fi

    # Extract the Open Questions section between '## Open Questions' and the next '## '
    local oq
    oq=$(awk '/^## Open Questions/{flag=1;next} /^## /{flag=0} flag' "$TASK_FILE")

    # Find IW-N (or any question marker) lines; for each, look for a sibling
    # "disposition:" and "rationale:" within the same block.
    # A "block" = lines from one question marker to the next (or section end).
    local missing=0 missing_list=""
    local current_q="" has_disposition=false has_rationale=false

    while IFS= read -r line; do
        # Match question markers (T-2218 RC5 fix): anchored to start-of-line marker
        # forms only. The previous unanchored `IW-[0-9]+` branch matched IW-N
        # mentions in prose (e.g. rationale text "depends on IW-1's answer"),
        # causing a false flush of the prior question's disposition/rationale.
        #   Valid: "- **IW-1: text**", "- IW-1: text", "### IW-1 title"
        #   Plus the legacy Q-N list-item form (unchanged).
        if echo "$line" | grep -qE "(^[[:space:]]*-[[:space:]]*\*?\*?IW-[0-9]+|^###[[:space:]]+IW-[0-9]+|^[[:space:]]*-[[:space:]]*Q-?[0-9]+)"; then
            # Flush previous question's verdict
            if [ -n "$current_q" ] && { [ "$has_disposition" = false ] || [ "$has_rationale" = false ]; }; then
                missing=$((missing + 1))
                missing_list="$missing_list\n    - $current_q (disposition=$has_disposition rationale=$has_rationale)"
            fi
            current_q=$(echo "$line" | grep -oE "IW-[0-9]+|Q-?[0-9]+" | head -1)
            has_disposition=false
            has_rationale=false
            continue
        fi
        # Match dispositions
        if echo "$line" | grep -qE "disposition:[[:space:]]*(answered|deferred|dissolved)"; then
            has_disposition=true
        fi
        if echo "$line" | grep -qE "rationale:[[:space:]]*.+"; then
            has_rationale=true
        fi
    done <<< "$oq"

    # Flush the last question
    if [ -n "$current_q" ] && { [ "$has_disposition" = false ] || [ "$has_rationale" = false ]; }; then
        missing=$((missing + 1))
        missing_list="$missing_list\n    - $current_q (disposition=$has_disposition rationale=$has_rationale)"
    fi

    if [ "$missing" -eq 0 ]; then
        echo -e "${GREEN}Disposition gate: all Open Questions disposed ✓${NC}"
        return 0
    fi

    if [ "$SKIP_DISPOSITION_GATE" = true ]; then
        echo -e "${YELLOW}WARNING: $missing Open Question(s) under-disposed (--skip-disposition-gate / FW_SKIP_DISPOSITION_GATE bypass)${NC}"
        log_gate_bypass "--skip-disposition-gate" "check_disposition_gate"
        return 0
    fi

    echo -e "${RED}ERROR: Cannot complete inception — $missing Open Question(s) under-disposed.${NC}" >&2
    echo "" >&2
    echo "T-2190 (T-2186 Slice 4): every IW-N question in ## Open Questions must carry" >&2
    echo "  disposition: answered|deferred|dissolved" >&2
    echo "  rationale: <evidence>" >&2
    echo "Never binary. See 050-Inceptions.md §Disposition Gate." >&2
    echo "" >&2
    echo "Missing:" >&2
    echo -e "$missing_list" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  1. Add disposition + rationale lines per missing question" >&2
    echo "  2. --skip-disposition-gate \"rationale\"  (direct, logged Tier-2)" >&2
    echo "  3. FW_SKIP_DISPOSITION_GATE=1 <command>  (env-var, logged Tier-2)" >&2
    exit 1
}

# Task-pair §ACD Gate (P-012, T-1762, structural remediation for G-066)
# Fires on --status work-completed for build tasks whose `related_tasks`
# chain references an inception with `**Recommendation:** GO` AND that
# inception has an explicit `**Decomposition (follow-up build tasks
# after GO):**` heading enumerating promised follow-ups.
#
# For each promised deliverable, checks via lib/task_pair_acd.py whether
# any task in the related_tasks chain has a title matching the
# deliverable. Refuses on missing != [].
#
# Conservative on purpose: silent on inceptions without the explicit
# Decomposition heading (single-deliverable inceptions, T-1713 itself,
# T-1715 etc.). Forward-only — historic completed builds are never
# re-checked.
#
# Origin: T-1442/T-1443 closed work-completed clean while 2/3 GO scope
# items silently dropped. T-1711 registered G-066. T-1713 inception GO'd
# the per-task gate but build was never filed (the very pattern G-066
# documents, recurring on its own deliverable). T-1762 closes the loop.
check_task_pair_acd() {
    [ "$NEW_STATUS" = "work-completed" ] || return 0

    # Load library if not already sourced
    if ! type extract_deliverables >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        source "$FRAMEWORK_ROOT/lib/task_pair_acd.sh" 2>/dev/null || return 0
    fi

    local task_type
    task_type=$(grep '^workflow_type:' "$TASK_FILE" | head -1 \
        | sed 's/workflow_type:[[:space:]]*//' | tr -d '"' | tr -d "'")

    # Only build tasks gate on this. Inceptions/specs/designs are the
    # things being checked AGAINST, not checked themselves.
    [ "$task_type" = "build" ] || return 0

    local task_id
    task_id=$(basename "$TASK_FILE" | grep -oE '^T-[0-9]+')
    [ -z "$task_id" ] && return 0

    # Read related_tasks (YAML list, possibly multi-line)
    local related_ids
    related_ids=$(python3 - "$TASK_FILE" <<'PYRELATED' 2>/dev/null || true
import re, sys
with open(sys.argv[1]) as f:
    head = f.read(4000)
m = re.search(r'^related_tasks:\s*(\[[^\]]*\]|\n(?:\s+-\s+\S+\n?)+)',
              head, re.MULTILINE)
if m:
    for tid in re.findall(r'T-\d+', m.group(1)):
        print(tid)
PYRELATED
)
    [ -z "$related_ids" ] && return 0

    # Find an inception in related_tasks with GO + Decomposition heading.
    # Skip on first match — there should be at most one parent inception.
    local inception_id="" inception_file
    while IFS= read -r tid; do
        [ -z "$tid" ] && continue
        inception_file=$(find "$PROJECT_ROOT/.tasks" -maxdepth 2 \
            -name "${tid}-*.md" -type f 2>/dev/null | head -1)
        [ -z "$inception_file" ] && continue
        # Only inceptions with GO + Decomposition produce non-empty deliverables
        local deliverables
        deliverables=$(python3 "$FRAMEWORK_ROOT/lib/task_pair_acd.py" \
            extract "$inception_file" 2>/dev/null || true)
        if [ -n "$deliverables" ]; then
            inception_id="$tid"
            break
        fi
    done <<< "$related_ids"

    [ -z "$inception_id" ] && return 0

    # Run the verify pass.
    #
    # NOTE: `set -e` is in effect for this script. A plain command-substitution
    # assignment (`var=$(cmd)`) to a variable that was declared `local` on
    # a previous line is a REGULAR assignment, so set -e triggers exit on a
    # non-zero exit of `cmd` — silently bypassing the error-reporting block
    # below. Origin bug: gate fired exit-4 in production but no stderr ever
    # reached the user; observed on T-1762 itself when the gate refused its
    # own transition. Fix: capture exit code via `|| rc=$?` idiom so set -e
    # does not see a failing command.
    local verify_json="" verify_rc=0
    verify_json=$(python3 "$FRAMEWORK_ROOT/lib/task_pair_acd.py" verify \
        "$inception_id" "$task_id" "$PROJECT_ROOT" 2>/dev/null) || verify_rc=$?

    if [ "$verify_rc" -eq 0 ]; then
        echo -e "${GREEN}Task-pair §ACD: all promised deliverables shipped ✓ (P-012, vs $inception_id)${NC}"
        return 0
    fi

    if [ "$verify_rc" -ne 4 ]; then
        # 2/3/etc — gate no-op (no Recommendation, not GO)
        return 0
    fi

    # Missing detected
    if [ -n "$SCOPE_REDUCTION_ACK" ]; then
        echo -e "${YELLOW}WARNING: Task-pair §ACD: missing deliverables (--scope-reduction-acknowledged bypass)${NC}"
        log_gate_bypass "--scope-reduction-acknowledged" "check_task_pair_acd: $SCOPE_REDUCTION_ACK"
        return 0
    fi

    echo -e "${RED}ERROR: Task-pair §ACD gate (P-012): inception $inception_id promised deliverables that did not ship.${NC}" >&2
    echo "" >&2
    echo "G-066 (CLAUDE.md): substrate-vs-deliverable conflation at task-pair level." >&2
    echo "Inception's '## Recommendation' enumerates follow-up build tasks under" >&2
    echo "'**Decomposition (follow-up build tasks after GO):**' but at least one" >&2
    echo "promised item has no shipped counterpart in related_tasks chain." >&2
    echo "" >&2
    echo "Verify report:" >&2
    echo "$verify_json" | sed 's/^/  /' >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  1. File the missing build task(s) and link via related_tasks, then retry" >&2
    echo "  2. Update inception Decomposition list to reflect a real scope reduction, then retry" >&2
    echo "  3. Use --scope-reduction-acknowledged \"<rationale>\" to acknowledge and bypass (logged, T-1762)" >&2
    exit 1
}

# Verification Gate (P-011)
# Runs shell commands from ## Verification section before allowing work-completed.
run_verification_commands() {
    local verify_section verify_cmds verify_total verify_pass verify_fail verify_failures
    local cmd display_cmd exit_code

    verify_section=$(sed -n '/^## Verification/,/^## /p' "$TASK_FILE" 2>/dev/null | sed '$d')
    verify_section=$(echo "$verify_section" | tail -n +2)
    # Strip HTML comment blocks
    verify_section=$(echo "$verify_section" | python3 -c "
import sys, re
text = sys.stdin.read()
text = re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)
print(text)
" 2>/dev/null || echo "$verify_section")
    verify_cmds=$(echo "$verify_section" | grep -vE '^\s*$|^\s*#|^\s*```' || true)

    [ -z "$verify_cmds" ] && return 0

    verify_total=$(echo "$verify_cmds" | wc -l)
    verify_pass=0
    verify_fail=0
    verify_failures=""

    echo ""
    echo -e "${CYAN}=== Verification Gate (P-011) ===${NC}"
    echo "Running $verify_total verification command(s)..."
    echo ""

    while IFS= read -r cmd; do
        cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        [ -z "$cmd" ] && continue

        display_cmd="$cmd"
        if [ ${#display_cmd} -gt 80 ]; then
            display_cmd="${display_cmd:0:77}..."
        fi

        # Run in subshell with framework path derivatives unset so child
        # processes re-derive TASKS_DIR/CONTEXT_DIR from their own PROJECT_ROOT.
        # Prevents bats tests from inheriting the parent's stale TASKS_DIR (T-739).
        # T-1317: cd to PROJECT_ROOT first so relative paths in verification
        # commands resolve consistently regardless of caller CWD (Watchtower
        # launches from FRAMEWORK_ROOT, CLI from PROJECT_ROOT).
        # T-1493: close inherited keylock FDs in the subshell so daemons
        # spawned by the verification command (.NET VBCSCompiler, gradle,
        # etc.) cannot inherit the lock FD and block future fw task ops.
        local _close_locks_cmd
        _close_locks_cmd=$(type keylock_subshell_close_cmd >/dev/null 2>&1 && keylock_subshell_close_cmd || true)
        if (unset TASKS_DIR CONTEXT_DIR _FW_PATHS_LOADED; eval "$_close_locks_cmd"; cd "$PROJECT_ROOT" && eval "$cmd") > /tmp/verify-$$.out 2>&1; then
            echo -e "  ${GREEN}PASS${NC}: $display_cmd"
            verify_pass=$((verify_pass + 1))
        else
            exit_code=$?
            echo -e "  ${RED}FAIL${NC}: $display_cmd (exit $exit_code)"
            head -5 /tmp/verify-$$.out 2>/dev/null | sed 's/^/    /'
            verify_fail=$((verify_fail + 1))
            verify_failures="${verify_failures}\n  - $display_cmd (exit $exit_code)"
        fi
        rm -f /tmp/verify-$$.out
    done <<< "$verify_cmds"

    echo ""
    if [ "$verify_fail" -gt 0 ]; then
        if [ "$SKIP_VERIFICATION" = true ]; then
            echo -e "${YELLOW}WARNING: $verify_fail/$verify_total verification(s) failed (--skip-verification bypass)${NC}"
            log_gate_bypass "--skip-verification" "run_verification_commands"
        else
            echo -e "${RED}ERROR: Cannot complete — $verify_fail/$verify_total verification(s) failed:${NC}" >&2
            echo -e "$verify_failures" >&2
            echo "" >&2
            echo "Options:" >&2
            echo "  1. Fix the issues and retry" >&2
            echo "  2. Update ## Verification commands if they are wrong" >&2
            echo "  3. Use --skip-verification to bypass (logged)" >&2
            exit 1
        fi
    else
        echo -e "${GREEN}Verification: $verify_pass/$verify_total passed ✓${NC}"
    fi
}

# Check for help before positional args
case "${1:-}" in
    -h|--help) set -- "--help" ;; # normalize
esac

# Parse arguments
TASK_ID=""
NEW_STATUS=""
NEW_OWNER=""
NEW_TAGS=""
ADD_TAGS=""
NEW_HORIZON=""
NEW_TYPE=""
REASON=""
FORCE=false
SKIP_SOVEREIGNTY=false
SKIP_AC=false
SKIP_VERIFICATION=false
SKIP_HUMAN_OWNERSHIP=false
SKIP_RECOMMENDATION=false
SKIP_RCA=false
SKIP_EVOLUTION=false
# T-2190: disposition-completeness gate (--skip-disposition-gate / FW_SKIP_DISPOSITION_GATE=1)
SKIP_DISPOSITION_GATE=false
if [ "${FW_SKIP_DISPOSITION_GATE:-0}" = "1" ]; then
    SKIP_DISPOSITION_GATE=true
fi
SKIP_INCEPTION_DECISION=false
SKIP_INCEPTION_SCOPE_TRACE=false
SKIP_RENDER_REVIEW=false
SKIP_RENDER_REVIEW_REASON=""
SCOPE_REDUCTION_ACK=""  # T-1762/P-012: --scope-reduction-acknowledged "rationale"

while [[ $# -gt 0 ]]; do
    case $1 in
        --status|-s) NEW_STATUS="$2"; shift 2 ;;
        --owner|-o) NEW_OWNER="$2"; shift 2 ;;
        --tags) NEW_TAGS="$2"; shift 2 ;;
        --add-tag) ADD_TAGS="$2"; shift 2 ;;
        --horizon) NEW_HORIZON="$2"; shift 2 ;;
        --type|-t) NEW_TYPE="$2"; shift 2 ;;
        --reason|-r) REASON="$2"; shift 2 ;;
        --skip-sovereignty) SKIP_SOVEREIGNTY=true; shift ;;
        --skip-acceptance-criteria) SKIP_AC=true; shift ;;
        --skip-verification) SKIP_VERIFICATION=true; shift ;;
        --skip-human-ownership) SKIP_HUMAN_OWNERSHIP=true; shift ;;
        --skip-recommendation) SKIP_RECOMMENDATION=true; shift ;;
        --skip-rca) SKIP_RCA=true; shift ;;
        --skip-evolution) SKIP_EVOLUTION=true; shift ;;
        --skip-disposition-gate)
            SKIP_DISPOSITION_GATE=true
            if [ -n "${2:-}" ] && [[ "${2:-}" != --* ]]; then
                REASON="${REASON:-$2}"
                shift
            fi
            shift ;;
        --skip-inception-decision) SKIP_INCEPTION_DECISION=true; shift ;;
        --skip-inception-scope-trace)
            SKIP_INCEPTION_SCOPE_TRACE=true
            if [ -n "${2:-}" ] && [[ "${2:-}" != --* ]]; then
                REASON="${REASON:-$2}"
                shift
            fi
            shift ;;
        --skip-render-review)
            SKIP_RENDER_REVIEW=true
            SKIP_RENDER_REVIEW_REASON="${2:-no rationale}"
            shift 2 ;;
        --scope-reduction-acknowledged)
            SCOPE_REDUCTION_ACK="$2"
            if [ -z "$SCOPE_REDUCTION_ACK" ]; then
                echo "ERROR: --scope-reduction-acknowledged requires a rationale string" >&2
                exit 1
            fi
            shift 2 ;;
        --force|-f)
            echo -e "${YELLOW}DEPRECATED: --force will be removed. Use narrow flags instead:${NC}" >&2
            echo "  --skip-sovereignty          Bypass human ownership completion gate (R-033)" >&2
            echo "  --skip-acceptance-criteria   Bypass AC gate (P-010)" >&2
            echo "  --skip-verification          Bypass verification gate (P-011)" >&2
            echo "  --skip-recommendation        Bypass recommendation gate (T-679)" >&2
            echo "  --skip-rca                   Bypass RCA gate for bug-class (T-1550, G-019)" >&2
            echo "  --skip-evolution             Bypass Evolution-log gate for arc-tagged builds (T-1718)" >&2
            echo "  --skip-inception-decision    Bypass inception decision gate (T-1626, G-052)" >&2
            echo "  --skip-inception-scope-trace \"...\"  Bypass GO-scope trace gate (T-1984, G-066)" >&2
            echo "  --skip-render-review \"...\" Bypass render-surface Human AC gate (T-1766)" >&2
            echo "  --scope-reduction-acknowledged \"...\"   Bypass task-pair §ACD gate (P-012, T-1762, G-066)" >&2
            echo "  --skip-human-ownership       Bypass human ownership reassignment" >&2
            FORCE=true; SKIP_SOVEREIGNTY=true; SKIP_AC=true; SKIP_VERIFICATION=true; SKIP_HUMAN_OWNERSHIP=true; SKIP_RECOMMENDATION=true; SKIP_RCA=true; SKIP_EVOLUTION=true; SKIP_INCEPTION_DECISION=true; SKIP_INCEPTION_SCOPE_TRACE=true; SKIP_RENDER_REVIEW=true; SKIP_RENDER_REVIEW_REASON="--force bypass"; SCOPE_REDUCTION_ACK="--force bypass"
            shift ;;
        -h|--help)
            echo "Usage: update-task.sh T-XXX [options]"
            echo ""
            echo "Options:"
            echo "  --status, -s  New status ($VALID_STATUSES)"
            echo "  --owner, -o   New owner"
            echo "  --type, -t    Workflow type ($VALID_TYPES)"
            echo "  --tags        Replace tags (comma-separated)"
            echo "  --add-tag     Add tag(s) to existing (comma-separated)"
            echo "  --horizon     Priority horizon: now, next, later"
            echo "  --reason, -r  Reason for status change (logged in Updates)"
            echo "  --skip-sovereignty          Bypass human ownership completion gate (R-033)"
            echo "  --skip-acceptance-criteria   Bypass AC gate (P-010)"
            echo "  --skip-verification          Bypass verification gate (P-011)"
            echo "  --skip-recommendation        Bypass recommendation gate (T-679)"
            echo "  --skip-rca                   Bypass RCA gate for bug-class (T-1550, G-019)"
            echo "  --skip-evolution             Bypass Evolution-log gate for arc-tagged builds (T-1718)"
            echo "  --skip-inception-decision    Bypass inception decision gate (T-1626, G-052)"
            echo "  --skip-inception-scope-trace \"...\"  Bypass GO-scope trace gate (T-1984, G-066)"
            echo "  --scope-reduction-acknowledged \"...\"   Bypass task-pair §ACD gate (P-012, T-1762, G-066)"
            echo "  --skip-human-ownership       Bypass human ownership reassignment"
            echo "  --force, -f   (DEPRECATED) Sets all --skip-* flags"
            echo "  -h, --help    Show this help"
            echo ""
            echo "Auto-triggers:"
            echo "  issues           → healing agent diagnose"
            echo "  work-completed   → AC gate + verification gate, date_finished, move to completed/, episodic generation"
            exit 0
            ;;
        T-*) TASK_ID="$1"; shift ;;
        --switch-focus) shift ;;  # T-1890: focus-drift hook sentinel; consumed silently
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

# Validate task ID
if [ -z "$TASK_ID" ]; then
    error "Task ID required"
    die "Usage: fw task update T-XXX --status <status>"
fi

# Find task file
TASK_FILE=""
TASK_FILE=$(find "$TASKS_DIR/active" -maxdepth 1 -name "${TASK_ID}-*.md" -type f 2>/dev/null | head -1)
if [ -z "$TASK_FILE" ]; then
    TASK_FILE=$(find "$TASKS_DIR/completed" -maxdepth 1 -name "${TASK_ID}-*.md" -type f 2>/dev/null | head -1)
fi

if [ -z "$TASK_FILE" ] || [ ! -f "$TASK_FILE" ]; then
    echo -e "${RED}ERROR: Task $TASK_ID not found${NC}" >&2
    exit 1
fi

# Acquire per-task lock to prevent concurrent modifications (T-587)
if type keylock_acquire &>/dev/null; then
    keylock_acquire "$TASK_ID"
    trap 'keylock_release "$TASK_ID" 2>/dev/null' EXIT
fi

# Read current state
OLD_STATUS=$({ grep "^status:" "$TASK_FILE" 2>/dev/null || true; } | head -1 | sed 's/status:[[:space:]]*//')
TASK_NAME=$({ grep "^name:" "$TASK_FILE" 2>/dev/null || true; } | head -1 | sed 's/name:[[:space:]]*//')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo -e "${CYAN}=== Task Update ===${NC}"
echo "Task:    $TASK_ID ($TASK_NAME)"
echo "File:    $TASK_FILE"

# Track what changed
CHANGES=()

# Update status
if [ -n "$NEW_STATUS" ]; then
    # Validate status
    if ! is_valid_status "$NEW_STATUS"; then
        error "Invalid status '$NEW_STATUS'"
        die "Valid: $VALID_STATUSES"
    fi

    if [ "$OLD_STATUS" = "$NEW_STATUS" ]; then
        if [ "$OLD_STATUS" = "work-completed" ] && [ "$(dirname "$TASK_FILE")" = "$TASKS_DIR/active" ]; then
            # T-193: Partial-complete re-run — check if human ACs now satisfied
            echo -e "${CYAN}Re-checking partial-complete status...${NC}"
            AC_SECTION=$(sed -n '/^## Acceptance Criteria/,/^## /p' "$TASK_FILE" 2>/dev/null | sed '$d')
            # Strip HTML comments — template examples contain checkbox patterns.
            # T-1967: two-step strip (one-line first, then range) — see line ~87.
            AC_SECTION=$(echo "$AC_SECTION" | sed -E 's/<!--[^>]*-->//g' | sed '/<!--/,/-->/d')
            ALL_TOTAL=$(echo "$AC_SECTION" | grep -cE '^\s*-\s*\[[ x]\]' || true)
            ALL_CHECKED=$(echo "$AC_SECTION" | grep -cE '^\s*-\s*\[x\]' || true)
            ALL_UNCHECKED=$((ALL_TOTAL - ALL_CHECKED))

            # T-1559: SKIP_AC must bypass the recheck too. The auth flag is the
            # marker of authorization — semantically equivalent on both branches.
            # Without this guard, partial-complete tasks become un-archivable
            # except by hand-editing checkboxes (P-016 evidence: 20 tasks closed
            # via that workaround in a single session).
            if [ "$ALL_UNCHECKED" -eq 0 ] || [ "$SKIP_AC" = true ]; then
                if [ "$ALL_UNCHECKED" -eq 0 ]; then
                    echo -e "${GREEN}All ACs checked (including human) ✓${NC}"
                else
                    echo -e "${YELLOW}WARNING: $ALL_UNCHECKED/$ALL_TOTAL ACs unchecked (--skip-acceptance-criteria bypass)${NC}"
                    log_gate_bypass "--skip-acceptance-criteria" "partial_complete_recheck"
                fi
                DEST="$TASKS_DIR/completed/$(basename "$TASK_FILE")"
                # T-1523: use `git mv` when tracked so both rename sides land
                # in the index together — avoids leaving the active/* deletion
                # as an unstaged working-tree change that pollutes subsequent
                # commits and requires a cleanup follow-up.
                _t1863_orig="$TASK_FILE"
                if git -C "$PROJECT_ROOT" ls-files --error-unmatch "$TASK_FILE" >/dev/null 2>&1; then
                    git -C "$PROJECT_ROOT" mv "$TASK_FILE" "$DEST" 2>/dev/null \
                        || mv "$TASK_FILE" "$DEST"
                else
                    mv "$TASK_FILE" "$DEST"
                fi
                TASK_FILE="$DEST"
                # T-1863: post-move sanity — if source still exists, the move
                # is incomplete and we'd land in a G-052 orphan state. Refuse
                # so the agent fixes it before --status work-completed commits.
                if [ -e "$_t1863_orig" ] && [ "$_t1863_orig" != "$DEST" ]; then
                    echo -e "${RED}ERROR: post-move orphan detected (T-1863)${NC}" >&2
                    echo "  Source still exists: $_t1863_orig" >&2
                    echo "  Destination:         $DEST" >&2
                    echo "  Both versions would create a G-052 duplicate-task-ID violation." >&2
                    echo "  Fix: git rm '$_t1863_orig' (the destination is canonical)" >&2
                    exit 1
                fi
                echo -e "${GREEN}Moved to completed/${NC}"

                # Generate episodic if not already present
                if [ ! -f "$CONTEXT_DIR/episodic/$TASK_ID.yaml" ]; then
                    echo ""
                    echo -e "${YELLOW}=== Auto-trigger: Episodic Generation ===${NC}"
                    CONTEXT_AGENT="$FRAMEWORK_ROOT/agents/context/context.sh"
                    if [ -x "$CONTEXT_AGENT" ]; then
                        PROJECT_ROOT="$PROJECT_ROOT" "$CONTEXT_AGENT" generate-episodic "$TASK_ID" || true
                        # Verify episodic was created (T-1169: silent failure detection)
                        EPISODIC_FILE="$CONTEXT_DIR/episodic/$TASK_ID.yaml"
                        if [ ! -f "$EPISODIC_FILE" ]; then
                            echo -e "  ${YELLOW}WARNING: Episodic not created for $TASK_ID — generation may have failed silently${NC}" >&2
                            echo -e "  Run manually: $(_emit_user_command "context generate-episodic $TASK_ID")" >&2
                        fi
                    fi
                fi

                # T-1697: outcome back-prop into dispatch-outcomes.jsonl (best-effort).
                # Skips verification because the P-011 gate already ran the same
                # commands above; --skip-verification just counts AC ticks. Failure
                # of this hook never blocks task completion (decoupled by design).
                FW_BIN="$FRAMEWORK_ROOT/bin/fw"
                if [ -x "$FW_BIN" ] && [ -f "$PROJECT_ROOT/.context/dispatches.jsonl" ]; then
                    PROJECT_ROOT="$PROJECT_ROOT" "$FW_BIN" outcome backprop "$TASK_ID" --skip-verification >/dev/null 2>&1 || true
                fi
            else
                echo -e "${YELLOW}Still $ALL_UNCHECKED/$ALL_TOTAL ACs unchecked — task stays in active/${NC}"
                echo "Check human ACs in the task file, then re-run this command."
            fi
        else
            echo -e "${YELLOW}Status already '$NEW_STATUS' — no change${NC}"
        fi
    else
        # Validate transition using centralized state machine (lib/enums.sh)
        if ! is_valid_transition "$OLD_STATUS" "$NEW_STATUS"; then
            echo -e "${RED}ERROR: Invalid transition '$OLD_STATUS' → '$NEW_STATUS'${NC}" >&2
            echo "Valid transitions:" >&2
            for from_status in $VALID_STATUSES; do
                targets="$(valid_transitions_for "$from_status")"
                [[ -n "$targets" ]] && echo "  $from_status → ${targets// / | }" >&2
            done
            exit 1
        fi

        # === Template Placeholder Warning (T-137) ===
        # Warn when starting work if AC section still has placeholder text
        if [ "$NEW_STATUS" = "started-work" ]; then
            if grep -q '<!-- Replace with specific' "$TASK_FILE" 2>/dev/null; then
                echo ""
                echo -e "${YELLOW}WARNING: Acceptance Criteria still has placeholder text${NC}"
                echo "  Fill in real criteria before completing this task."
                echo "  The completion gate (P-010) will check them."
                echo ""
            fi
        fi

        # === L-387 SIGPIPE Advisory at started-work (T-2059) ===
        # Non-blocking heuristic: warn if the task's ## Verification block
        # already contains a `<streaming-cmd> | grep -q "..."` shape. P-011
        # runs verification under set -eo pipefail; SIGPIPE on grep early-match
        # makes the upstream exit 141 → pipefail fails the verification even
        # though the pattern was present. Captured 7+ times (T-1716, T-1838,
        # T-1862, T-1863, T-2008, T-1701, T-1707). The safer form is documented
        # in CLAUDE.md and policy/anti-patterns.yaml#l387-sigpipe-risk.
        #
        # Bypass: FW_SKIP_L387_ADVISORY=1 (advisory anyway — does NOT block).
        # Skipping is logged Tier-2 only for tracking adoption; not punitive.
        if [ "$NEW_STATUS" = "started-work" ] && [ -z "${FW_SKIP_L387_ADVISORY:-}" ]; then
            if command -v python3 >/dev/null 2>&1; then
                _l387_findings=$(python3 - "$TASK_FILE" 2>/dev/null <<'PY' || true
import sys
from pathlib import Path
ROOT = Path(__file__).resolve()
# Walk up from script dir to find lib/reviewer
for parent in [Path(sys.argv[0]).resolve()] + list(Path(sys.argv[0]).resolve().parents):
    if (parent / "lib" / "reviewer" / "static_scan.py").exists():
        sys.path.insert(0, str(parent))
        break
else:
    sys.exit(0)
try:
    from lib.reviewer import static_scan as ss
except Exception:
    sys.exit(0)
tf = sys.argv[1]
try:
    text = Path(tf).read_text()
except Exception:
    sys.exit(0)
verif = ss.extract_section(text, "Verification") or ""
if not verif:
    sys.exit(0)
findings = ss.detect_l387_sigpipe_risk(verif)
for f in findings:
    print(f"  - {f.location}: {f.evidence}")
PY
                )
                if [ -n "$_l387_findings" ]; then
                    echo ""
                    echo -e "${YELLOW}ADVISORY (L-387 SIGPIPE risk): Verification contains pipe-to-grep-q shape${NC}"
                    echo "$_l387_findings"
                    echo "  Safe pattern: out=\$(cmd 2>&1); echo \"\$out\" | grep -q \"PATTERN\""
                    echo "  Or:           cmd > /tmp/.out 2>&1; grep -q \"PATTERN\" /tmp/.out"
                    echo "  Suppress (does not block):  FW_SKIP_L387_ADVISORY=1 bin/fw task update ..."
                    echo "  Reviewer pattern: l387-sigpipe-risk (policy/anti-patterns.yaml)"
                    echo ""
                fi
            fi
        fi

        # === BVP Estimator Trigger (T-1922) ===
        # On transition to started-work ("ready"), fire the BVP estimator
        # in the background. Heuristic engine is ~10ms so the update latency
        # impact is negligible, but we background it anyway in case a future
        # v2-LLM engine lands and goes over the budget. Failures are silent —
        # the estimator's output is advisory; a missing proposed score does
        # not block any downstream gate.
        if [ "$NEW_STATUS" = "started-work" ] && [ -n "$TASK_ID" ]; then
            if [ -x "$FRAMEWORK_ROOT/agents/termlink/bvp-estimator/bvp-estimator.sh" ]; then
                (
                    PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
                    "$FRAMEWORK_ROOT/agents/termlink/bvp-estimator/bvp-estimator.sh" \
                        one "$TASK_ID" >/dev/null 2>&1
                ) &
                disown 2>/dev/null || true
            fi
        fi

        # === Concurrent Started-Work Advisory (T-554) ===
        # Warn when starting work if other tasks are already started-work.
        # Advisory only — does not block. Helps maintain single-task focus.
        if [ "$NEW_STATUS" = "started-work" ]; then
            _other_started=""
            _other_count=0
            for _tf in "$PROJECT_ROOT"/.tasks/active/T-*.md; do
                [ -f "$_tf" ] || continue
                [ "$_tf" = "$TASK_FILE" ] && continue
                if grep -q "^status: started-work" "$_tf" 2>/dev/null; then
                    _other_count=$((_other_count + 1))
                    if [ "$_other_count" -le 5 ]; then
                        _tid=$({ grep "^id:" "$_tf" 2>/dev/null || true; } | head -1 | awk '{print $2}')
                        _other_started="${_other_started}  ${_tid}\n"
                    fi
                fi
            done
            if [ "$_other_count" -gt 0 ]; then
                echo ""
                echo -e "${YELLOW}CONCURRENT TASKS: ${_other_count} other task(s) already in started-work${NC}"
                echo -e "$_other_started"
                if [ "$_other_count" -gt 5 ]; then
                    echo "  ... and $((_other_count - 5)) more"
                fi
                echo "  Consider pausing tasks you're not actively working on:"
                echo "    $(_emit_user_command "task update T-XXX --status captured")"
                echo ""
            fi
        fi

        # === Human Sovereignty Gate (R-033/T-198) ===
        if [ "$NEW_STATUS" = "work-completed" ]; then
            check_human_sovereignty
        fi

        # === Acceptance Criteria Gate (P-010) ===
        PARTIAL_COMPLETE=false
        if [ "$NEW_STATUS" = "work-completed" ]; then
            check_acceptance_criteria
        fi

        # === Verification Gate (P-011) ===
        if [ "$NEW_STATUS" = "work-completed" ]; then
            run_verification_commands
        fi

        # === Recommendation Gate (T-679 / T-1529) ===
        # Only fires when PARTIAL_COMPLETE=true (Human ACs remain).
        # Reviewers see /review/T-XXX — it must surface an agent advisory.
        if [ "$NEW_STATUS" = "work-completed" ]; then
            check_recommendation_for_review
        fi

        # === RCA Gate (T-1550, G-019 structural remediation) ===
        # Bug-class tasks must capture root cause before completion.
        if [ "$NEW_STATUS" = "work-completed" ]; then
            check_rca_for_bugfix
        fi

        # === Disposition Gate (T-2190, T-2186 Slice 4) ===
        # Inception tasks with ## Open Questions must dispose every question.
        if [ "$NEW_STATUS" = "work-completed" ]; then
            check_disposition_gate
        fi

        # === Render-surface Human-AC Gate (T-1766, P-013) ===
        # Build/refactor/test tasks touching web render surfaces must
        # carry at least one [REVIEW] Human AC — visual verification
        # cannot be automated.
        if [ "$NEW_STATUS" = "work-completed" ]; then
            check_render_surface_human_ac
        fi

        # === Inception-decision Gate (T-1626, G-052 structural remediation) ===
        # Inception tasks must record a go/no-go/defer decision before completion.
        if [ "$NEW_STATUS" = "work-completed" ]; then
            check_inception_decision
        fi

        # === Inception GO-scope Trace Gate (T-1984, G-066 prevention) ===
        # Inception tasks with inception_decisions: populated must have all
        # ships_in: referents reachable before the inception archives.
        if [ "$NEW_STATUS" = "work-completed" ]; then
            check_inception_scope_trace
        fi

        # === Evolution-log Gate (T-1718, T-1717 grill Q4 remediation) ===
        # Arc-tagged build tasks with a ## Evolution section must capture
        # spec-vs-build drift before completion. Backward-compat: tasks
        # without the section aren't gated.
        if [ "$NEW_STATUS" = "work-completed" ]; then
            check_evolution_log
        fi

        # === Task-pair §ACD Gate (P-012, T-1762, G-066 prong 2) ===
        # Build tasks completing under an inception that explicitly
        # enumerated follow-up build tasks must show the full set shipped.
        # Conservative: silent on inceptions without `**Decomposition
        # (follow-up build tasks after GO):**` heading.
        if [ "$NEW_STATUS" = "work-completed" ]; then
            check_task_pair_acd
        fi

        # === Reviewer Static-Scan (T-1443 v1.0) ===
        # Non-blocking measurement pass: catalogues anti-patterns and writes
        # verdict to task body. Skipped if FW_REVIEWER_DISABLED=1 or python3
        # missing. v1.1+ adds escalation; v1.2+ adds blocking on configured tasks.
        if [ "$NEW_STATUS" = "work-completed" ] && [ "${FW_REVIEWER_DISABLED:-0}" != "1" ]; then
            if command -v python3 >/dev/null 2>&1 && [ -f "$FRAMEWORK_ROOT/lib/reviewer/static_scan.py" ]; then
                echo ""
                echo "Reviewer static-scan (T-1443 v1.0, non-blocking)..."
                # Capture exit but never propagate — v1.0 is measurement only
                _task_id_short=$(basename "$TASK_FILE" | grep -oE '^T-[0-9]+')
                ( cd "$FRAMEWORK_ROOT" && \
                    PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
                    python3 -m lib.reviewer.static_scan "$_task_id_short" 2>&1 | sed 's/^/  /' ) || true
            fi
        fi

        _sed_i "s/^status:.*/status: $NEW_STATUS/" "$TASK_FILE"
        echo "Status:  $OLD_STATUS → $NEW_STATUS"
        CHANGES+=("status: $OLD_STATUS → $NEW_STATUS")

        # === Invariant: started-work → horizon: now (T-1068) ===
        # Starting work means it's active NOW. Auto-promote horizon.
        if [ "$NEW_STATUS" = "started-work" ] && [ -z "$NEW_HORIZON" ]; then
            _current_horizon=$({ grep "^horizon:" "$TASK_FILE" 2>/dev/null || true; } | head -1 | sed 's/horizon:[[:space:]]*//' || true)
            if [ -n "$_current_horizon" ] && [ "$_current_horizon" != "now" ]; then
                _sed_i "s/^horizon:.*/horizon: now/" "$TASK_FILE"
                echo -e "${CYAN}Horizon: $_current_horizon → now (auto-sync: started-work implies now)${NC}"
                CHANGES+=("horizon: $_current_horizon → now (auto-sync)")
            fi
        fi
    fi
fi

# Update owner
if [ -n "$NEW_OWNER" ]; then
    OLD_OWNER=$({ grep "^owner:" "$TASK_FILE" 2>/dev/null || true; } | head -1 | sed 's/owner:[[:space:]]*//')
    # T-198/R-033: Owner protection — owner: human is sticky
    if [ "$OLD_OWNER" = "human" ] && [ "$NEW_OWNER" != "human" ]; then
        if [ "$SKIP_HUMAN_OWNERSHIP" = true ]; then
            echo -e "${YELLOW}WARNING: Overriding human ownership (--skip-human-ownership bypass)${NC}"
            log_gate_bypass "--skip-human-ownership" "owner_change"
        else
            echo -e "${RED}ERROR: Cannot change owner from 'human' — human ownership is protected (R-033)${NC}" >&2
            echo "Only the human can reassign human-owned tasks." >&2
            echo "Use --skip-human-ownership to bypass (logged)." >&2
            exit 1
        fi
    fi
    _sed_i "s/^owner:.*/owner: $NEW_OWNER/" "$TASK_FILE"
    echo "Owner:   $OLD_OWNER → $NEW_OWNER"
    CHANGES+=("owner: $OLD_OWNER → $NEW_OWNER")
fi

# Update workflow type
if [ -n "$NEW_TYPE" ]; then
    if ! is_valid_type "$NEW_TYPE"; then
        echo -e "${RED}ERROR: Invalid workflow type '$NEW_TYPE'${NC}" >&2
        echo "Valid types: $VALID_TYPES" >&2
        exit 1
    fi
    OLD_TYPE=$({ grep "^workflow_type:" "$TASK_FILE" 2>/dev/null || true; } | head -1 | sed 's/workflow_type:[[:space:]]*//')
    _sed_i "s/^workflow_type:.*/workflow_type: $NEW_TYPE/" "$TASK_FILE"
    echo "Type:    ${OLD_TYPE:-unset} → $NEW_TYPE"
    CHANGES+=("workflow_type: ${OLD_TYPE:-unset} → $NEW_TYPE")
fi

# Update horizon
if [ -n "$NEW_HORIZON" ]; then
    # T-2160 (arc-009 horizon-axis-hardening, Slice 1): explicit guard against
    # --horizon past. 'past' is a derived render-time value (computed from file
    # location in .tasks/completed/) per T-2159 Q1=(b). It has no write-path:
    # storing past in YAML would let task be horizon: past + status: started-work
    # — the exact coherence failure §ACD warns about (status and horizon
    # contradict each other on "is work done"). Storage enum stays now/next/later.
    if [ "$NEW_HORIZON" = "past" ]; then
        echo -e "${RED}ERROR: '--horizon past' rejected — past is a derived render-time value, not settable${NC}" >&2
        echo "  Past is computed from file location: .tasks/completed/ → renders as past." >&2
        echo "  Storage enum is now/next/later. To mark a task done: --status work-completed" >&2
        echo "  (Per T-2159 inception Q1=(b); arc-009 horizon-axis-hardening.)" >&2
        exit 1
    fi
    if ! is_valid_horizon "$NEW_HORIZON"; then
        echo -e "${RED}ERROR: Invalid horizon '$NEW_HORIZON'${NC}" >&2
        echo "Valid horizons: $VALID_HORIZONS" >&2
        exit 1
    fi
    OLD_HORIZON=$({ grep "^horizon:" "$TASK_FILE" 2>/dev/null || true; } | head -1 | sed 's/horizon:[[:space:]]*//' || true)
    if [ -n "$OLD_HORIZON" ]; then
        _sed_i "s/^horizon:.*/horizon: $NEW_HORIZON/" "$TASK_FILE"
    else
        # Add horizon field after status line (for tasks created before this field existed)
        _sed_i "/^status:.*/a\\
horizon: $NEW_HORIZON" "$TASK_FILE"
    fi
    echo "Horizon: ${OLD_HORIZON:-unset} → $NEW_HORIZON"
    CHANGES+=("horizon: ${OLD_HORIZON:-unset} → $NEW_HORIZON")

    # === Invariant: horizon next/later + started-work → captured (T-1068) ===
    # Shelving a task means you stopped working on it. Auto-demote status.
    #
    # T-1589 exception: if shipping evidence is present (all Agent ACs checked
    # AND a `## Recommendation` block exists), the task is past started-work —
    # it's awaiting human review, not shelved. Demoting to captured masks
    # shipped work from the review queue (origin: T-1064/1065/1066 + T-334/
    # T-464/T-544/T-967 — 7 tasks invisibly stuck in captured during one sweep).
    if [ "$NEW_HORIZON" != "now" ] && [ -z "$NEW_STATUS" ]; then
        _current_status=$({ grep "^status:" "$TASK_FILE" 2>/dev/null || true; } | head -1 | sed 's/status:[[:space:]]*//' || true)
        if [ "$_current_status" = "started-work" ]; then
            # grep -c prints count even when 0 (just with non-zero exit). The
            # `|| echo 0` fallback caused a "0\n0" value when no matches existed,
            # breaking the equality check. Use a single command, ignore exit.
            _has_rec=$(grep -c "^\*\*Recommendation:\*\*" "$TASK_FILE" 2>/dev/null) || _has_rec=0
            _agent_unchecked=$(awk '/^### Agent/,/^### Human|^## /' "$TASK_FILE" 2>/dev/null | grep -c '^- \[ \]') || _agent_unchecked=0
            # T-1865: a DEFER Recommendation is NOT shipping evidence — it's an
            # explicit "park this" verdict. Demoting started-work → captured
            # is the right behaviour. Only GO/NO-GO Recommendations indicate
            # awaiting-review state that the T-1589 exception protects.
            _rec_is_defer=$(grep -c "^\*\*Recommendation:\*\*.*DEFER" "$TASK_FILE" 2>/dev/null) || _rec_is_defer=0
            if [ "$_has_rec" -ge 1 ] && [ "$_agent_unchecked" = "0" ] && [ "$_rec_is_defer" -eq 0 ]; then
                echo -e "${CYAN}Status:  preserved at started-work (T-1589: shipping evidence — Recommendation + all Agent ACs checked)${NC}"
                CHANGES+=("status: preserved at started-work (T-1589 shipping evidence)")
            else
                _sed_i "s/^status:.*/status: captured/" "$TASK_FILE"
                echo -e "${CYAN}Status:  started-work → captured (auto-sync: horizon $NEW_HORIZON implies not active)${NC}"
                CHANGES+=("status: started-work → captured (auto-sync)")
            fi
        fi
    fi
fi

# Update tags (replace or add)
if [ -n "$NEW_TAGS" ] || [ -n "$ADD_TAGS" ]; then
    if grep -q "^tags:" "$TASK_FILE"; then
        if [ -n "$NEW_TAGS" ]; then
            # Replace all tags
            IFS=',' read -ra tag_items <<< "$NEW_TAGS"
            tag_yaml="["
            first=true
            for t in "${tag_items[@]}"; do
                t=$(echo "$t" | xargs)
                [ -z "$t" ] && continue
                if [ "$first" = true ]; then tag_yaml="${tag_yaml}${t}"; first=false
                else tag_yaml="${tag_yaml}, ${t}"; fi
            done
            tag_yaml="${tag_yaml}]"
            _sed_i "s/^tags:.*/tags: $tag_yaml/" "$TASK_FILE"
            echo "Tags:    → $tag_yaml"
            CHANGES+=("tags: → $tag_yaml")
        elif [ -n "$ADD_TAGS" ]; then
            # Add to existing tags via python (safer YAML manipulation)
            python3 -c "
import re, sys
tag_input = sys.argv[1]
new_tags = [t.strip() for t in tag_input.split(',') if t.strip()]
with open(sys.argv[2]) as f:
    content = f.read()
m = re.search(r'^tags:\s*\[([^\]]*)\]', content, re.MULTILINE)
if m:
    existing = [t.strip() for t in m.group(1).split(',') if t.strip()]
    combined = list(dict.fromkeys(existing + new_tags))
    new_line = 'tags: [' + ', '.join(combined) + ']'
    content = content[:m.start()] + new_line + content[m.end():]
else:
    # No tags line — add after owner
    content = re.sub(r'^(owner:.*)', r'\1\ntags: [' + ', '.join(new_tags) + ']', content, count=1, flags=re.MULTILINE)
with open(sys.argv[2], 'w') as f:
    f.write(content)
" "$ADD_TAGS" "$TASK_FILE"
            echo "Tags:    +$ADD_TAGS"
            CHANGES+=("tags: +$ADD_TAGS")
        fi
    else
        # No tags field exists — add it
        IFS=',' read -ra tag_items <<< "${NEW_TAGS:-$ADD_TAGS}"
        tag_yaml="["
        first=true
        for t in "${tag_items[@]}"; do
            t=$(echo "$t" | xargs)
            [ -z "$t" ] && continue
            if [ "$first" = true ]; then tag_yaml="${tag_yaml}${t}"; first=false
            else tag_yaml="${tag_yaml}, ${t}"; fi
        done
        tag_yaml="${tag_yaml}]"
        _sed_i "/^owner:.*/a\\
tags: $tag_yaml" "$TASK_FILE"
        echo "Tags:    $tag_yaml (added)"
        CHANGES+=("tags: $tag_yaml (added)")
    fi
fi

# Update last_update timestamp
_sed_i "s/^last_update:.*/last_update: $TIMESTAMP/" "$TASK_FILE"

# Append update entry
if [ ${#CHANGES[@]} -gt 0 ]; then
    {
        echo ""
        echo "### $TIMESTAMP — status-update [task-update-agent]"
        for change in "${CHANGES[@]}"; do
            echo "- **Change:** $change"
        done
        if [ -n "$REASON" ]; then
            echo "- **Reason:** $REASON"
        fi
    } >> "$TASK_FILE"
fi

# === AUTO-TRIGGERS ===

# Trigger 1: issues/blocked → healing diagnosis
if [ -n "$NEW_STATUS" ] && [ "$OLD_STATUS" != "$NEW_STATUS" ]; then
    if [ "$NEW_STATUS" = "issues" ] || [ "$NEW_STATUS" = "blocked" ]; then
        echo ""
        echo -e "${YELLOW}=== Auto-trigger: Healing Diagnosis ===${NC}"

        HEALING_AGENT="$FRAMEWORK_ROOT/agents/healing/healing.sh"
        if [ -x "$HEALING_AGENT" ]; then
            PROJECT_ROOT="$PROJECT_ROOT" "$HEALING_AGENT" diagnose "$TASK_ID" || true
        else
            echo -e "${YELLOW}Healing agent not found at $HEALING_AGENT${NC}"
            echo "Run manually: $(_emit_user_command "healing diagnose $TASK_ID")"
        fi
    fi
fi

# Trigger 2: work-completed → finalize
if [ -n "$NEW_STATUS" ] && [ "$NEW_STATUS" = "work-completed" ] && [ "$OLD_STATUS" != "work-completed" ]; then
    # Set date_finished
    _sed_i "s/^date_finished:.*/date_finished: $TIMESTAMP/" "$TASK_FILE"
    echo ""
    echo -e "${GREEN}date_finished set to $TIMESTAMP${NC}"

    # Move to completed/ (or partial-complete: stay in active/)
    if [ "${PARTIAL_COMPLETE:-false}" = true ]; then
        # T-193: Agent done but human ACs pending — stay in active/
        _sed_i "s/^owner:.*/owner: human/" "$TASK_FILE"
        HUMAN_AC_UNCHECKED_REMAINING=$((HUMAN_AC_TOTAL - HUMAN_AC_CHECKED))
        echo -e "${YELLOW}Partial-complete: $HUMAN_AC_UNCHECKED_REMAINING human AC(s) pending verification${NC}"
        echo -e "${YELLOW}Task stays in active/ — owner set to human${NC}"
        echo "Human review required — see Watchtower link below."

        # T-634: Auto-emit review (URL + QR + artifacts) on partial-complete
        if [ -f "$FRAMEWORK_ROOT/lib/review.sh" ]; then
            source "$FRAMEWORK_ROOT/lib/review.sh"
            emit_review "$TASK_ID" "$TASK_FILE"
        fi

        # T-709: Push notification — human review needed
        if [ -f "$FRAMEWORK_ROOT/lib/notify.sh" ]; then
            source "$FRAMEWORK_ROOT/lib/notify.sh"
            fw_notify "Review Needed: $TASK_ID" "$TASK_NAME" "manual" "framework"
        fi

        # T-325: Check human AC quality — warn if Steps blocks are missing
        HUMAN_AC_SECTION=$(sed -n '/^### Human/,/^## \|^### [^H]/p' "$TASK_FILE" 2>/dev/null | head -n -1)
        HUMAN_AC_COUNT=$(echo "$HUMAN_AC_SECTION" | grep -cE '^\s*-\s*\[[ x]\]' || true)
        HUMAN_AC_WITH_STEPS=$(echo "$HUMAN_AC_SECTION" | grep -cE '^\s+\*\*Steps:\*\*' || true)
        if [ "$HUMAN_AC_COUNT" -gt 0 ] && [ "$HUMAN_AC_WITH_STEPS" -lt "$HUMAN_AC_COUNT" ]; then
            MISSING=$((HUMAN_AC_COUNT - HUMAN_AC_WITH_STEPS))
            echo ""
            echo -e "${YELLOW}Human AC quality: $MISSING of $HUMAN_AC_COUNT criteria lack Steps/Expected blocks.${NC}"
            echo -e "${YELLOW}  Tip: Add Steps: with numbered instructions so the reviewer can act immediately.${NC}"
            echo -e "${YELLOW}  See CLAUDE.md 'Human AC Format Requirements' for the required format.${NC}"
        fi
    else
        DEST="$TASKS_DIR/completed/$(basename "$TASK_FILE")"
        if [ "$(dirname "$TASK_FILE")" != "$TASKS_DIR/completed" ]; then
            # T-1523: git mv when tracked so both rename sides stage atomically
            _t1863_orig="$TASK_FILE"
            if git -C "$PROJECT_ROOT" ls-files --error-unmatch "$TASK_FILE" >/dev/null 2>&1; then
                git -C "$PROJECT_ROOT" mv "$TASK_FILE" "$DEST" 2>/dev/null \
                    || mv "$TASK_FILE" "$DEST"
            else
                mv "$TASK_FILE" "$DEST"
            fi
            TASK_FILE="$DEST"
            # T-1863: post-move orphan check — same rationale as the T-193
            # re-run path above. Refuse rather than land in G-052 silently.
            if [ -e "$_t1863_orig" ] && [ "$_t1863_orig" != "$DEST" ]; then
                echo -e "${RED}ERROR: post-move orphan detected (T-1863)${NC}" >&2
                echo "  Source still exists: $_t1863_orig" >&2
                echo "  Destination:         $DEST" >&2
                echo "  Both versions would create a G-052 duplicate-task-ID violation." >&2
                echo "  Fix: git rm '$_t1863_orig' (the destination is canonical)" >&2
                exit 1
            fi
            echo -e "${GREEN}Moved to completed/${NC}"

            # T-2163 (arc-009 horizon-axis-hardening, Slice 4): null the stored
            # horizon now that the file is in .tasks/completed/. Render derives
            # `past` from _location (T-2160 Q1=(b)) so the stored value is
            # behaviorally irrelevant — but a non-null value here is a YAML lie
            # that CTL-030 (T-2162) would catch. Plug the source: write `null`
            # in the same atomic move so no drift is ever introduced.
            # Partial-complete branch does NOT touch this — that file stays in
            # active/ and renders via the stored horizon.
            _sed_i "s/^horizon:.*/horizon: null/" "$TASK_FILE"

            # T-709: Push notification — task completed
            if [ -f "$FRAMEWORK_ROOT/lib/notify.sh" ]; then
                source "$FRAMEWORK_ROOT/lib/notify.sh"
                fw_notify "Task Complete: $TASK_ID" "$TASK_NAME" "manual" "framework"
            fi
        fi
    fi

    # === Clear focus if this was the focused task (T-354) ===
    # Only for full completion (not partial-complete — human still needs focus)
    if [ "${PARTIAL_COMPLETE:-false}" = false ]; then
        FOCUS_FILE="$CONTEXT_DIR/working/focus.yaml"
        if [ -f "$FOCUS_FILE" ]; then
            FOCUSED_TASK=$(grep "^current_task:" "$FOCUS_FILE" | sed 's/current_task:[[:space:]]*//')
            if [ "$FOCUSED_TASK" = "$TASK_ID" ]; then
                _sed_i "s/^current_task:.*/current_task: null/" "$FOCUS_FILE"
                echo -e "${YELLOW}Focus cleared (task completed). Set new focus: $(_fw_cmd) work-on T-XXX${NC}"
            fi
        fi
    fi

    # === Onboarding completion check (T-535) ===
    # If the completed task was tagged onboarding, check if all onboarding tasks are done.
    # If so, write the marker file so the PreToolUse gate fast-paths.
    if head -20 "$TASK_FILE" | grep -q '^tags:.*onboarding' 2>/dev/null; then
        ONBOARDING_MARKER="$PROJECT_ROOT/.context/working/.onboarding-complete"
        if [ ! -f "$ONBOARDING_MARKER" ]; then
            all_done=true
            for otf in "$TASKS_DIR/active"/T-*.md; do
                [ -f "$otf" ] || continue
                if head -20 "$otf" | grep -q '^tags:.*onboarding' 2>/dev/null; then
                    otf_status=$({ grep "^status:" "$otf" 2>/dev/null || true; } | head -1 | sed 's/status:[[:space:]]*//')
                    if [ "$otf_status" != "work-completed" ]; then
                        all_done=false
                        break
                    fi
                fi
            done
            if [ "$all_done" = true ]; then
                mkdir -p "$(dirname "$ONBOARDING_MARKER")"
                echo "completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$ONBOARDING_MARKER"
                echo -e "${GREEN}All onboarding tasks complete! Onboarding gate disabled.${NC}"
            fi
        fi
    fi

    # === Auto-populate components field (T-224) ===
    # Resolve git diff paths to component IDs via .fabric/components/*.yaml location field
    FABRIC_DIR="$PROJECT_ROOT/.fabric/components"
    if [ -d "$FABRIC_DIR" ]; then
        # Build location→id lookup from component cards
        # Build location→id lookup (temp file, POSIX-safe — no declare -A)
        LOC_TO_ID_FILE=$(mktemp)
        for card in "$FABRIC_DIR"/*.yaml; do
            [ -f "$card" ] || continue
            c_loc=$(grep "^location:" "$card" 2>/dev/null | sed 's/^location:[[:space:]]*//' | head -1)
            c_id=$(grep "^id:" "$card" 2>/dev/null | sed 's/^id:[[:space:]]*//' | head -1)
            if [ -n "$c_loc" ] && [ -n "$c_id" ]; then
                echo "${c_loc}=${c_id}" >> "$LOC_TO_ID_FILE"
            fi
        done

        # Get all files changed in commits for this task
        TASK_COMMITS=$(git log --all --oneline --grep="$TASK_ID" 2>/dev/null | awk '{print $1}')
        RESOLVED_COMPONENTS=""
        if [ -n "$TASK_COMMITS" ]; then
            # T-1374: `|| true` — root commits have no parent; `git diff ${c}~1` exits 128,
            # and under pipefail+set -e that kills the script before the Episodic block.
            ALL_PATHS=$(for c in $TASK_COMMITS; do git diff --name-only "${c}~1" "$c" 2>/dev/null || true; done | sort -u)
            for path in $ALL_PATHS; do
                # Skip metadata paths
                case "$path" in
                    .context/*|.tasks/*|.fabric/*|docs/*) continue ;;
                esac
                # T-1374 (G-054 root cause): `|| true` prevents the pipeline's grep-no-match
                # exit 1 (under pipefail) from killing the script via set -e, which otherwise
                # aborted before the Episodic Generation block ran.
                comp_id=$({ grep "^${path}=" "$LOC_TO_ID_FILE" 2>/dev/null || true; } | head -1 | cut -d= -f2- || true)
                if [ -n "$comp_id" ]; then
                    RESOLVED_COMPONENTS="${RESOLVED_COMPONENTS:+$RESOLVED_COMPONENTS, }${comp_id}"
                fi
            done
        fi

        # Update components field if we found any
        # T-1469: python multi-line replace — sed-based replace left orphan
        # `  - item` continuation lines from block-style components, producing
        # invalid YAML (caused Watchtower scanner crash, T-1468 cleanup).
        if [ -n "$RESOLVED_COMPONENTS" ]; then
            python3 -c "
import re, sys
resolved = sys.argv[1]
path = sys.argv[2]
with open(path) as f:
    content = f.read()
# Match 'components:' line plus any continuation lines that follow.
# Two continuation shapes (T-2067, T-1469):
#   - block-style: '  - item'  (lines starting whitespace + '-')
#   - flow-style:  '  item]'    (indented continuation of a wrapped flow list)
# A continuation is any indented line that isn't itself a YAML key (no
# '<word>:' at start). Stops at the next YAML key or blank line. Without
# the flow-style branch, a pre-existing wrapped list left an orphan
# closing-bracket continuation that produced invalid YAML — Watchtower
# /review/T-XXX rendered the not-found page because parse_frontmatter failed.
# 4 corpus victims repaired in 1e0c98b4 (T-2018, T-2059, T-2060, T-2061).
# NOTE (T-2068): never embed the double-quote character (ASCII 0x22) in
# this comment block. The surrounding python3 -c uses that character as
# its bash string delimiter; an inline occurrence here prematurely
# terminates the bash string at runtime and shifts argv positions.
# Use single quotes or rephrase. bash -n does NOT catch this (syntax is
# valid at parse time, only breaks at expansion).
pattern = re.compile(
    r'^components:[^\n]*\n'              # the components: line
    r'(?:[ \t]+(?!\w+:)[^\n]*\n)*',       # indented continuation lines (not starting a new key)
    re.MULTILINE,
)
new_block = 'components: [' + resolved + ']\n'
if pattern.search(content):
    content = pattern.sub(new_block, content, count=1)
else:
    # No components line — add after tags
    content = re.sub(r'^(tags:[^\n]*\n)', r'\1' + new_block, content, count=1, flags=re.MULTILINE)
with open(path, 'w') as f:
    f.write(content)
" "$RESOLVED_COMPONENTS" "$TASK_FILE"
            COMP_COUNT=$(echo "$RESOLVED_COMPONENTS" | tr ',' '\n' | wc -l)
            echo -e "${GREEN}Components: $COMP_COUNT resolved from git history${NC}"
        fi
        rm -f "$LOC_TO_ID_FILE"
    fi

    # === Auto-capture decisions from task file (T-236) ===
    # Extract decisions from ## Decisions section and record to context fabric
    CONTEXT_AGENT="$FRAMEWORK_ROOT/agents/context/context.sh"
    if [ -x "$CONTEXT_AGENT" ] && [ -f "$TASK_FILE" ]; then
        # Extract "Chose:" lines from Decisions section as decision summaries
        IN_DECISIONS=false
        DECISION_COUNT=0
        while IFS= read -r line; do
            if echo "$line" | grep -q '^## Decisions'; then
                IN_DECISIONS=true
                continue
            fi
            if echo "$line" | grep -q '^## ' && [ "$IN_DECISIONS" = true ]; then
                break
            fi
            if [ "$IN_DECISIONS" = true ]; then
                # Match "**Chose:**" or "**Decision**:" patterns
                DECISION_TEXT=""
                # shellcheck disable=SC2001 # complex regex — can't use ${//}
                if echo "$line" | grep -qE '\*\*Chose:\*\*'; then
                    DECISION_TEXT=$(echo "$line" | sed 's/.*\*\*Chose:\*\*[[:space:]]*//')
                elif echo "$line" | grep -qE '\*\*Decision\*\*:'; then
                    DECISION_TEXT=$(echo "$line" | sed 's/.*\*\*Decision\*\*:[[:space:]]*//')
                fi
                # Filter out template placeholders
                case "$DECISION_TEXT" in
                    *"[what was decided]"*|*"[topic]"*|*"[rationale]"*|*"TODO"*) DECISION_TEXT="" ;;
                esac
                if [ -n "$DECISION_TEXT" ] && [ ${#DECISION_TEXT} -gt 5 ]; then
                    if PROJECT_ROOT="$PROJECT_ROOT" "$CONTEXT_AGENT" add-decision "$DECISION_TEXT" --task "$TASK_ID" --rationale "Auto-captured from task file on completion" 2>/dev/null; then
                        DECISION_COUNT=$((DECISION_COUNT + 1))
                    fi
                fi
            fi
        done < "$TASK_FILE"
        if [ "$DECISION_COUNT" -gt 0 ]; then
            echo -e "${GREEN}Auto-captured $DECISION_COUNT decision(s) from task file${NC}"
        fi
    fi

    # Generate episodic summary — but NOT for partial-complete tasks (T-1160/T-1103)
    # Partial-complete means human ACs are unchecked; the task stays in active/.
    # Generating episodic now creates premature memory of unfinalized work.
    # The human-finalization path (line ~388) handles episodic generation on final completion.
    if [ "${PARTIAL_COMPLETE:-false}" = false ]; then
        echo ""
        echo -e "${YELLOW}=== Auto-trigger: Episodic Generation ===${NC}"

        CONTEXT_AGENT="$FRAMEWORK_ROOT/agents/context/context.sh"
        if [ -x "$CONTEXT_AGENT" ]; then
            # T-1371 (G-054): Capture stdout/stderr/exit-code to diagnose silent failures.
            # Log every invocation (not only on failure) so the forensic context (PROJECT_ROOT,
            # CONTEXT_DIR, env) is captured when the next silent failure occurs.
            #
            # T-1860: per-task log file + append. Previous single rolling log was
            # truncated on every invocation — the moment a silent failure occurred,
            # the failing run's context was already overwritten by the next task's
            # successful run. Per-task files isolate forensics; append preserves
            # re-run history within a task. Discovered when T-1859 backfilled
            # T-1829/T-1830/T-1831 episodics and the diagnostic log was unrecoverable.
            EPISODIC_LOG="$CONTEXT_DIR/working/episodic-gen/$TASK_ID.log"
            mkdir -p "$(dirname "$EPISODIC_LOG")" 2>/dev/null || true
            {
                echo "=== episodic-gen invocation: $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
                echo "task_id: $TASK_ID"
                echo "FRAMEWORK_ROOT: $FRAMEWORK_ROOT"
                echo "PROJECT_ROOT: $PROJECT_ROOT"
                echo "CONTEXT_DIR: $CONTEXT_DIR"
                echo "CONTEXT_AGENT: $CONTEXT_AGENT"
                echo "cwd: $(pwd)"
                echo "--- context.sh output ---"
            } >> "$EPISODIC_LOG" 2>&1
            set +e
            PROJECT_ROOT="$PROJECT_ROOT" "$CONTEXT_AGENT" generate-episodic "$TASK_ID" >> "$EPISODIC_LOG" 2>&1
            EPISODIC_EXIT=$?
            set -e
            echo "--- exit code: $EPISODIC_EXIT ---" >> "$EPISODIC_LOG"
            cat "$EPISODIC_LOG"
            # Verify episodic was created (T-1169: silent failure detection)
            EPISODIC_FILE="$CONTEXT_DIR/episodic/$TASK_ID.yaml"
            if [ ! -f "$EPISODIC_FILE" ]; then
                echo -e "  ${YELLOW}WARNING: Episodic not created for $TASK_ID — generation may have failed silently${NC}" >&2
                echo -e "  Log: $EPISODIC_LOG (exit=$EPISODIC_EXIT)" >&2
                echo -e "  Run manually: $(_emit_user_command "context generate-episodic $TASK_ID")" >&2
            fi
        else
            echo -e "${YELLOW}Context agent not found${NC}"
            echo "Run manually: $(_emit_user_command "context generate-episodic $TASK_ID")"
        fi
    fi

    # T-1697/T-1698: outcome back-prop into dispatch-outcomes.jsonl (best-effort).
    # T-1697 added this hook to the partial-complete re-run branch only (line ~605);
    # fresh first-time completions go through this Trigger 2 path and need the same
    # hook here. Both branches must stay in sync. Failure of the hook never blocks
    # task completion (decoupled by design). T-1698 RCA captures the duplicate-branch
    # design and the verification gap that allowed T-1697 to ship half-wired.
    if [ "${PARTIAL_COMPLETE:-false}" = false ]; then
        FW_BIN="$FRAMEWORK_ROOT/bin/fw"
        if [ -x "$FW_BIN" ] && [ -f "$PROJECT_ROOT/.context/dispatches.jsonl" ]; then
            PROJECT_ROOT="$PROJECT_ROOT" "$FW_BIN" outcome backprop "$TASK_ID" --skip-verification >/dev/null 2>&1 || true
        fi
    fi

    # === Learning capture check for bugfix tasks (T-692, G-016, T-1192) ===
    # 0% of bugfix tasks captured learnings (G-016 threshold: 35%).
    # Enhanced prompt: pre-filled command, guidance questions, visual box.
    TASK_NAME_RAW=$({ grep "^name:" "$TASK_FILE" 2>/dev/null || true; } | head -1 | sed 's/^name:[[:space:]]*"*//;s/"*$//')
    TASK_TYPE_RAW=$({ grep "^workflow_type:" "$TASK_FILE" 2>/dev/null || true; } | head -1 | sed 's/^workflow_type:[[:space:]]*//')
    _is_bugfix=false
    # Detect by name pattern (fix/bugfix/hotfix anywhere, or "RCA" or "G-0" gap reference)
    if echo "$TASK_NAME_RAW" | grep -qiE '\bfix\b|\bbugfix\b|\bhotfix\b|\bRCA\b|\bG-[0-9]'; then
        _is_bugfix=true
    fi
    # Detect by commit messages referencing "fix" in recent commits for this task
    if [ "$_is_bugfix" = false ] && [ "$TASK_TYPE_RAW" = "build" ] || [ "$TASK_TYPE_RAW" = "refactor" ]; then
        if git log --oneline -10 2>/dev/null | grep -qi "$TASK_ID.*fix\|fix.*$TASK_ID"; then
            _is_bugfix=true
        fi
    fi
    if [ "$_is_bugfix" = true ]; then
        LEARNINGS_FILE="$CONTEXT_DIR/project/learnings.yaml"
        HAS_LEARNING=false
        if [ -f "$LEARNINGS_FILE" ] && grep -q "$TASK_ID" "$LEARNINGS_FILE" 2>/dev/null; then
            HAS_LEARNING=true
        fi
        if [ "$HAS_LEARNING" = false ]; then
            echo ""
            echo -e "${YELLOW}────────────────────────────────────────────${NC}"
            echo -e "${YELLOW}  LEARNING PROMPT — This looks like a bugfix task${NC}"
            echo -e "${YELLOW}  No learning entry references $TASK_ID.${NC}"
            echo -e "${YELLOW}  Consider: $(_emit_user_command "fix-learned $TASK_ID \"what was learned\"")${NC}"
            echo -e "${YELLOW}  Ask: Would a future agent benefit from knowing about this fix?${NC}"
            echo -e "${YELLOW}────────────────────────────────────────────${NC}"
        fi
    fi
fi

echo ""
echo -e "${GREEN}=== Update Complete ===${NC}"
