#!/usr/bin/env bats
# T-3000: the SIGPIPE hint block in .tasks/templates/default.md must lead with the
# form that is correct at any output size.
#
# The block ships into the `## Verification` section of every generated task file,
# and it accreted chronologically — each task appended its correction below the
# previous one. By T-2743 it read as a sequence of "here is the rule / actually
# that is wrong / actually that is wrong too", with the conditionally-safe
# capture-then-grep form arriving first, labelled "Safe pattern", carrying L-387's
# origin citation, and the correction that inverts it 20 lines further down behind
# a hint about a different thing.
#
# An agent reading top-down copies the first labelled form. That is not a
# hypothesis: T-2996's first repair adopted it verbatim and P-011 refused the task
# with rc=141 against this repo's 608KB log. In a consumer with a shorter history
# nothing would have caught it — the same goes-red-later shape as the defect being
# repaired. Reported by the 001-CashWeb consumer session.
#
# What is pinned here is ORDER and LABELLING, not content. Every rule in the block
# is true; the defect was which one an agent meets first. A future correction
# appended to the bottom is fine — one that re-promotes the bounded form to the
# top, or re-labels it as unconditionally safe, is what this catches.

setup() {
    FW_ROOT="${BATS_TEST_DIRNAME}/../.."
    TPL="$FW_ROOT/.tasks/templates/default.md"
    [ -f "$TPL" ] || skip "template not found: $TPL"
}

# Line number of the first match, or empty. Whole-file: the block is all comments,
# so there is no executable/prose split to make here (contrast T-2996, where the
# seed's explanatory comment about a pattern tripped a scan for the pattern).
_lineno() { grep -n -- "$1" "$TPL" | head -1 | cut -d: -f1; }

@test "T-3000: the file-redirect form appears before the capture-then-grep form" {
    local redirect capture
    redirect=$(_lineno '> /tmp/.out 2>&1 && grep -q')
    capture=$(_lineno 'out=$(cmd 2>&1); grep -q "PATTERN" <<<"$out"')   # T-4921/T-4922: here-string

    [ -n "$redirect" ] || { echo "file-redirect form absent from template" >&2; return 1; }
    [ -n "$capture" ]  || { echo "capture-then-grep form absent from template" >&2; return 1; }

    [ "$redirect" -lt "$capture" ] || {
        echo "capture-then-grep (line $capture) precedes file-redirect (line $redirect)" >&2
        echo "the conditionally-safe form must not be the one an agent meets first" >&2
        return 1; }
}

@test "T-3000: the block does not label a conditionally-safe form 'Safe pattern'" {
    # The exact label that made the wrong form authoritative. Its absence is the
    # point: nothing in the block may assert unconditional safety for a shape that
    # inverts above the 65536-byte pipe buffer.
    run grep -c 'Safe pattern' "$TPL"
    [ "$output" = "0" ] || {
        echo "'Safe pattern' still labels a form in the template" >&2; return 1; }
}

@test "T-4922: the retraction of echo|grep -q is adjacent to the capture form that replaced it" {
    # T-3000 pinned a 64 KB bound next to `echo "$out" | grep -q`. T-4921 (832 T-1340)
    # showed the bound is false for multi-line values — a builtin writes per line, so
    # grep -q can exit early at ANY size — and the same pipe made gates fail open
    # (T-4920, T-4921). The capture form is now a here-string; what must sit next to it
    # is the retraction of the old form. Same adjacency rule as T-3000 (max 12 lines):
    # a correction 20 lines away reads as a new hint, not a retraction.
    local capture warn gap
    capture=$(_lineno 'out=$(cmd 2>&1); grep -q "PATTERN" <<<"$out"')
    warn=$(_lineno 'Do NOT write `echo "$out" | grep -q PAT`')

    [ -n "$capture" ] || { echo "the here-string capture form is absent" >&2; return 1; }
    [ -n "$warn" ] || { echo "the retraction of echo|grep -q is no longer stated" >&2; return 1; }
    [ "$warn" -gt "$capture" ] || { echo "retraction at $warn precedes the form at $capture" >&2; return 1; }

    gap=$(( warn - capture ))
    [ "$gap" -le 12 ] || {
        echo "retraction is $gap lines below the form it qualifies (max 12)" >&2; return 1; }
}

@test "T-3000: every rule the block accumulated is still stated" {
    # The restructure reorders and compresses; it must not drop a rule. Each of
    # these was learned the expensive way by a different task.
    local missing="" pat
    for pat in \
        'set -eo pipefail' \
        'SIGPIPE' \
        'not safe "below 64 KB"' \
        'grep -q "PATTERN" <<<"$out"' \
        'FW_ALLOW_UNJUDGED_TEST_RUN=1' \
        'DOES NOT REHEARSE THE GATE'
    do
        grep -qF -- "$pat" "$TPL" || missing="$missing
  $pat"
    done
    [ -z "$missing" ] || { echo "rules dropped from the block:$missing" >&2; return 1; }
}

@test "T-3000: every origin citation survives, so each rule stays traceable" {
    local missing="" id
    for id in L-387 T-2090 T-2743 T-2738; do
        grep -qF -- "$id" "$TPL" || missing="$missing $id"
    done
    [ -z "$missing" ] || { echo "citations dropped:$missing" >&2; return 1; }
}
