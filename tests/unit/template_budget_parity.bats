#!/usr/bin/env bats
#
# T-3155 — the consumer CLAUDE.md template must not contradict the budget gate.
#
# Origin: 001-CashWeb ran `fw upgrade` and lost their T-085 fix, which had expressed
# the context-budget ladder as percentages of CONTEXT_WINDOW. The template replaced it
# with hard-coded 120K/150K/170K — numbers from a 200K-window era — so every consumer
# was handed a CLAUDE.md telling it to hand over at 170K while its own budget-gate.sh
# blocked at 285K. Net value of that upgrade: zero, plus one regression.
#
# THE POINT OF THIS FILE. These tests read the percentages out of BOTH sources and
# compare them. They deliberately do NOT assert a literal 75/85/95, because a hardcoded
# expectation in the test drifts in exactly the same way the template did — it would
# re-create the defect one level up and look green while doing it.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    GATE="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
    TEMPLATE="$FRAMEWORK_ROOT/lib/templates/claude-project.md"
}

# Percentages the gate actually computes, in ladder order (warn, urgent, critical).
_gate_percentages() {
    grep -oE 'CONTEXT_WINDOW \* [0-9]+ / 100' "$GATE" \
        | grep -oE '\* [0-9]+ ' \
        | grep -oE '[0-9]+'
}

# Percentages the template states, deduplicated, ascending.
_template_percentages() {
    grep -oE '\*\*[0-9]+%\*\*' "$TEMPLATE" \
        | grep -oE '[0-9]+' \
        | sort -n -u
}

@test "T-3155: the gate's percentages are recoverable at all (instrument check)" {
    # If this fails, every other test in this file is measuring nothing. An empty
    # extraction and a matching extraction are indistinguishable downstream, which is
    # the exact failure class this task exists to close.
    run _gate_percentages
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [ "$(echo "$output" | wc -l)" -eq 3 ]
}

@test "T-3155: the template's percentages are recoverable at all (instrument check)" {
    run _template_percentages
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [ "$(echo "$output" | wc -l)" -eq 3 ]
}

@test "T-3155: template percentages equal the gate's, read from both sources" {
    local gate tmpl
    gate=$(_gate_percentages | sort -n -u | tr '\n' ' ')
    tmpl=$(_template_percentages | tr '\n' ' ')
    [ "$gate" = "$tmpl" ]
}

@test "T-3155: no stale absolute token literals remain in the template" {
    # The absolutes are the mechanism of the drift: they are correct only for one
    # value of FW_CONTEXT_WINDOW and go silently wrong when it moves.
    run grep -nE '120K|150K|170K' "$TEMPLATE"
    [ "$status" -ne 0 ]
}

@test "T-3155 [control]: a template with the OLD percentages fails the parity check" {
    # Proves the comparison discriminates. Without this, a parity test that always
    # passed — because both extractions returned empty, say — would be indistinguishable
    # from one that genuinely matched.
    local fake="$BATS_TEST_TMPDIR/stale-template.md"
    cp "$TEMPLATE" "$fake"
    sed -i 's/\*\*75%\*\*/**60%**/; s/\*\*85%\*\*/**75%**/; s/\*\*95%\*\*/**85%**/' "$fake"

    local gate tmpl
    gate=$(_gate_percentages | sort -n -u | tr '\n' ' ')
    tmpl=$(grep -oE '\*\*[0-9]+%\*\*' "$fake" | grep -oE '[0-9]+' | sort -n -u | tr '\n' ' ')

    # The stale template must NOT match the gate — that is the defect, reproduced.
    [ "$gate" != "$tmpl" ]
    # And the stale set must be the pre-T-3155 one, so we know the fixture really is
    # the regression and not merely different.
    [ "$tmpl" = "60 75 85 " ]
}

@test "T-3155: the template names FW_CONTEXT_WINDOW as the source of the numbers" {
    # Percentages without their base are still ambiguous to a consumer.
    grep -q 'FW_CONTEXT_WINDOW' "$TEMPLATE"
}
