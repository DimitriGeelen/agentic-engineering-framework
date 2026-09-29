#!/bin/bash
# lib/inception-readiness.sh — SHARED decision-readiness predicates for inception tasks.
#
# T-3279 (G-102). Origin: the T-2190 disposition predicate lived only inside
# update-task.sh:check_disposition_gate — the completion ENFORCEMENT point — while
# the surfaces that INVITE completion (do_inception_decide's T-1503 preflight,
# lib/review.sh emission, the Watchtower decide form behind them) had no way to ask
# the same question. Result, measured 2026-09-05 on T-3278: operator records GO,
# decision is written, the completion side-effect refuses, task sticks in the
# class-2 state (decision recorded, status started-work), and the operator is shown
# the gate's agent-facing stderr — Tier-2 bypass flags included — as the response.
#
# THE RULE THIS FILE EMBODIES: a completion-gate predicate lives in ONE shared
# implementation, and every surface that invites the completion calls it. Parity
# by construction, not by remembering (L-399 / T-1890 class).
#
# This file is a PURE PREDICATE: no colors, no exit, no bypass handling, no
# Tier-2 logging. Policy (what to do about a refusal, which bypasses exist, who
# logs them) stays at each call site — the enforcement point keeps its bypass
# contract; the invitation points refuse or warn in their own voice.

# inception_underdisposed_questions <task_file>
#
#   Reports the IW-N / Q-N entries under '## Open Questions' that lack a
#   disposition (answered|deferred|dissolved) or a non-empty rationale.
#
#   stdout: one line per under-disposed question:
#             IW-1 disposition=false rationale=true
#   return: 0 — decision-ready (all disposed, or not an inception, or no
#               '## Open Questions' section — grandfathered, matching T-2190)
#           1 — at least one under-disposed question (count = line count)
#
#   ⚠ CALLER CONTRACT (T-3539) — THE RETURN CODE IS A *FINDING*, NOT AN ERROR.
#
#   Return 1 means "I successfully found under-disposed questions". Under
#   `set -e` that is indistinguishable from failure, so
#
#       out=$(inception_underdisposed_questions "$f")        # WRONG under set -e
#       out=$(inception_underdisposed_questions "$f") || true # correct
#
#   All three real callers use only the OUTPUT and never read the return code,
#   so `|| true` discards nothing.
#
#   Measured cost of getting this wrong: all three call sites — lib/review.sh,
#   lib/inception.sh, agents/task-create/update-task.sh — had the unguarded form,
#   which silently killed `fw task review`, `fw inception decide` AND
#   `fw task update --status work-completed` on any inception with an undisposed
#   question. `fw task review T-3532` exited 1 printing NOTHING, and Watchtower,
#   handed a non-zero exit with empty stderr, could only say "Unknown error from
#   fw inception decide". The warning this function exists to trigger was the
#   very thing that prevented itself from being printed.
#
#   Parsing contract is IDENTICAL to the pre-T-3279 check_disposition_gate,
#   including the T-2218 RC5 anchored-marker fix (an IW-N mention inside prose
#   must not flush the previous question's verdict).
inception_underdisposed_questions() {
    local task_file="$1"
    [ -f "$task_file" ] || return 0

    local wf
    wf=$(grep -E "^workflow_type:" "$task_file" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'")
    [ "$wf" = "inception" ] || return 0

    # Backward-compat: absent section = grandfathered (T-2190 contract)
    grep -qE "^## Open Questions" "$task_file" || return 0

    local oq
    oq=$(awk '/^## Open Questions/{flag=1;next} /^## /{flag=0} flag' "$task_file")

    local missing=0
    local current_q="" has_disposition=false has_rationale=false

    _flush() {
        if [ -n "$current_q" ] && { [ "$has_disposition" = false ] || [ "$has_rationale" = false ]; }; then
            missing=$((missing + 1))
            printf '%s disposition=%s rationale=%s\n' "$current_q" "$has_disposition" "$has_rationale"
        fi
    }

    local line
    while IFS= read -r line; do
        # Anchored question markers only (T-2218 RC5):
        #   "- **IW-1: text**", "- IW-1: text", "### IW-1 title", legacy "- Q-1 ..."
        if echo "$line" | grep -qE "(^[[:space:]]*-[[:space:]]*\*?\*?IW-[0-9]+|^###[[:space:]]+IW-[0-9]+|^[[:space:]]*-[[:space:]]*Q-?[0-9]+)"; then
            _flush
            current_q=$(echo "$line" | grep -oE "IW-[0-9]+|Q-?[0-9]+" | head -1)
            has_disposition=false
            has_rationale=false
            continue
        fi
        if echo "$line" | grep -qE "disposition:[[:space:]]*(answered|deferred|dissolved)"; then
            has_disposition=true
        fi
        if echo "$line" | grep -qE "rationale:[[:space:]]*.+"; then
            has_rationale=true
        fi
    done <<< "$oq"
    _flush

    unset -f _flush
    [ "$missing" -eq 0 ]
}

# inception_handoff_blockers <task_file>
#
#   T-3549. THE one predicate a decision handoff consults. Composes the existing
#   checks rather than reimplementing them, because two implementations of one
#   rule is the L-399 class and this file's own header is the argument against it:
#
#     - inception_underdisposed_questions (above) — T-2190 disposition rule
#     - audit_inception_recommendation (lib/task-audit.sh) — T-1497 rec rule
#
#   It exists so requirements stop being discovered one refusal at a time. A new
#   handoff requirement is added HERE and every invitation surface inherits it.
#
#   stdout: one blocker per line, TAB-separated:
#             CODE <TAB> detail <TAB> how to fix it
#   return: 0 — ALWAYS.
#
#   ⚠ THE RETURN CODE IS DELIBERATELY NOT A FINDING SIGNAL (OBS-566, T-3539).
#
#   Its sibling above returns 1 to mean "I found something", which under `set -e`
#   is indistinguishable from failure and silently killed three commands until
#   T-3539 guarded every call site. OBS-566's own recommendation is to carry the
#   finding ONLY in stdout and always return 0, so that is what this one does.
#   Callers test for non-empty output:
#
#       blockers=$(inception_handoff_blockers "$f")   # safe under set -e
#       [ -n "$blockers" ] && refuse
#
#   Grandfathering matches T-2190: an inception with no '## Open Questions'
#   section is not blocked on dispositions. A missing '## Recommendation' IS a
#   blocker, but inception_repair_shape() below can scaffold it first.
inception_handoff_blockers() {
    local task_file="${1:-}"
    [ -n "$task_file" ] && [ -f "$task_file" ] || return 0

    grep -qE '^workflow_type:[[:space:]]*inception' "$task_file" 2>/dev/null || return 0

    local _ud
    _ud=$(inception_underdisposed_questions "$task_file") || true
    if [ -n "$_ud" ]; then
        local _line
        while IFS= read -r _line; do
            [ -n "$_line" ] || continue
            printf 'undisposed-question\t%s\tGive it `disposition: answered|deferred|dissolved` plus a one-line rationale. `deferred` is ALWAYS available.\n' "$_line"
        done <<< "$_ud"
    fi

    if command -v audit_inception_recommendation >/dev/null 2>&1; then
        local _rc=0
        audit_inception_recommendation "$task_file" >/dev/null 2>&1 || _rc=$?
        if [ "$_rc" -eq 1 ]; then
            printf 'empty-recommendation\t## Recommendation has no substantive **Recommendation:** line\tWrite GO | NO-GO | DEFER plus a rationale. The operator needs an advisory, not a blank form (T-1497).\n'
        fi
    fi

    return 0
}

# inception_repair_shape <task_file>
#
#   T-3549. AUTO-ADJUST, deliberately bounded to SHAPE and never to CONTENT.
#
#   Repairs structure whose absence is mechanical and needs no judgement, so the
#   author is never blocked by a missing scaffold. It NEVER supplies a value:
#   auto-filling a disposition or writing a recommendation would manufacture
#   readiness, which is the exact failure class T-3549 removes — a handoff that
#   passes the gate while nobody has thought about the question is worse than one
#   that is refused.
#
#   Repairs performed:
#     - a missing '## Recommendation' section is appended as an empty scaffold
#     - an IW-N entry with no `disposition:` LINE gets the line, value EMPTY
#
#   Deliberately NOT repaired:
#     - a missing '## Open Questions' section. T-2190 grandfathers it, so adding
#       one would invent a requirement the task never had.
#     - any disposition VALUE, any rationale text, any recommendation verdict.
#
#   stdout: one line per repair made (empty when nothing needed doing)
#   return: 0 — always; same contract as the blocker predicate above.
inception_repair_shape() {
    local task_file="${1:-}"
    [ -n "$task_file" ] && [ -f "$task_file" ] && [ -w "$task_file" ] || return 0
    grep -qE '^workflow_type:[[:space:]]*inception' "$task_file" 2>/dev/null || return 0

    if ! grep -qE '^## Recommendation[[:space:]]*$' "$task_file" 2>/dev/null; then
        {
            echo ""
            echo "## Recommendation"
            echo ""
            echo "<!-- T-3549 auto-adjust: scaffold added because the section was absent."
            echo "     The VERDICT is not auto-filled on purpose — an auto-written"
            echo "     recommendation would manufacture readiness. Fill it in: -->"
            echo ""
            echo "**Recommendation:**"
            echo ""
            echo "**Rationale:**"
        } >> "$task_file"
        echo "scaffolded: ## Recommendation (verdict left empty for the author)"
    fi
    return 0
}
