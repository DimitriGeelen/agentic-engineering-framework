#!/bin/bash
# lib/task_pair_acd.sh
#
# Task-pair §ACD gate (P-012). G-066 prong 2 — detect substrate-vs-
# deliverable conflation at work-completed time. Mirror of T-1668/T-1671's
# arc-level gate at the per-task level.
#
# Built from T-1713 GO decision (2026-05-04). T-1713 itself shipped the
# pattern G-066 documents: inception with GO scope, no build task ever
# filed, gate never wired. T-1762 closes that loop.
#
# Public functions:
#
#   extract_deliverables <inception_task_file>
#       Print one promised deliverable per line from the inception's
#       `## Recommendation` -> `**Decomposition (follow-up build tasks
#       after GO):**` block. Conservative: only fires on the explicit
#       Decomposition heading. Single-deliverable inceptions (no heading)
#       return empty list. Strips HTML comments.
#
#       Exit codes:
#         0 — parsed (any number of items, including 0)
#         2 — no `## Recommendation` block
#         3 — Recommendation present but not GO (NO-GO/DEFER skipped)
#
#   verify_deliverables_shipped <inception_task_id> <build_task_id>
#       Compare promised deliverables against shipped artefacts.
#       Output: JSON {inception, build, promised[], shipped[], missing[]}.
#
#       Exit codes:
#         0 — all shipped or empty promised
#         2 — inception not found / no Recommendation
#         3 — inception not GO (gate no-op)
#         4 — missing != []
#
# Guard against double-sourcing
[[ -n "${_FW_TASK_PAIR_ACD_LOADED:-}" ]] && return 0
_FW_TASK_PAIR_ACD_LOADED=1

# Resolve the framework root for the lib (caller may not set it).
_TPACD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_TPACD_FW_ROOT="$(dirname "$_TPACD_LIB_DIR")"

extract_deliverables() {
    local task_file="$1"
    [ -f "$task_file" ] || return 2
    python3 "$_TPACD_LIB_DIR/task_pair_acd.py" extract "$task_file"
}

verify_deliverables_shipped() {
    local inception_id="$1"
    local build_id="$2"
    local framework_root="${FRAMEWORK_ROOT:-$_TPACD_FW_ROOT}"
    python3 "$_TPACD_LIB_DIR/task_pair_acd.py" verify "$inception_id" "$build_id" "$framework_root"
}
