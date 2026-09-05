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
