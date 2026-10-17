#!/usr/bin/env bats
#
# T-3155 — the consumer CLAUDE.md template must not contradict the budget gate.
# T-4226 — the template states the ladder as absolute used-token figures, so the
# parity check now reads those figures and compares them with lib/budget_ladder.py.
#
# Origin: 001-CashWeb ran `fw upgrade` and lost their T-085 fix, which had expressed
# the context-budget ladder as percentages of CONTEXT_WINDOW. The template replaced it
# with hard-coded 120K/150K/170K — numbers from a 200K-window era — so every consumer
# was handed a CLAUDE.md telling it to hand over at 170K while its own budget-gate.sh
# blocked at 285K. Net value of that upgrade: zero, plus one regression.
#
# THE POINT OF THIS FILE. The template's numbers must be the ladder's numbers, read
# from both sources and compared. They deliberately do NOT assert literal figures
# for the ladder, because a hardcoded expectation in the test drifts in exactly the
# same way the template did. The only literal here is the stale fixture (the control).

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    GATE="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
    CHECKPOINT="$FRAMEWORK_ROOT/agents/context/checkpoint.sh"
    LADDER="$FRAMEWORK_ROOT/lib/budget_ladder.py"
    TEMPLATE="$FRAMEWORK_ROOT/lib/templates/claude-project.md"
}

# The Amber / Red / Stop figures the ladder computes for window $1, in K (one per line).
_ladder_k() {
    python3 -I "$LADDER" "$1" | sed -n 's/^TOKEN_\(WARN\|URGENT\|CRITICAL\)=\([0-9]*\)$/\2/p' \
        | awk '{ v = $1 / 1000; sub(/\.0+$/, "", v); print v "K" }'
}

# The ladder figures the template states at the 800K default, in order (Amber, Red, Stop).
# The figures after the phrase, so the "800K" inside the phrase is not read as a figure.
_figures_after_default() {
    grep -oE 'at the 800K default[^.]*' "$1" | head -1 | sed 's/^at the 800K default//' \
        | grep -oE '[0-9.]+K' | head -3
}

_template_800k() {
    _figures_after_default "$TEMPLATE"
}

@test "T-4226: the gate and checkpoint both read the shared ladder, not a formula of their own" {
    grep -q 'lib/budget_ladder.py' "$GATE"
    grep -q 'lib/budget_ladder.py' "$CHECKPOINT"
    # The old percentage arithmetic must be gone from both gauges.
    run grep -nE 'CONTEXT_WINDOW \* (75|85|95) / 100' "$GATE" "$CHECKPOINT"
    [ "$status" -ne 0 ]
}

@test "T-4226: the template states the 800K ladder as three figures" {
    # If this fails, the parity check below measures nothing.
    run _template_800k
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | wc -l)" -eq 3 ]
}

@test "T-4226: template's 800K figures equal the ladder's, read from both sources" {
    local tmpl ladder
    tmpl=$(_template_800k | tr '\n' ' ')
    ladder=$(_ladder_k 800000 | tr '\n' ' ')
    [ "$tmpl" = "$ladder" ]
}

@test "T-4226: template's 975K figures equal the ladder's (this project's cap)" {
    grep -q 'At 975K: 825K / 875K / 925K' "$TEMPLATE"
    [ "$(_ladder_k 975000 | tr '\n' ' ')" = "825K 875K 925K " ]
}

@test "T-3155: no stale absolute token literals remain in the template" {
    # The 120K/150K/170K absolutes were correct for one FW_CONTEXT_WINDOW only.
    run grep -nE '120K|150K|170K' "$TEMPLATE"
    [ "$status" -ne 0 ]
}

@test "T-3155 [control]: a template with the OLD 800K figures fails the parity check" {
    # Proves the comparison discriminates. Without this, a parity test that always
    # passed would be indistinguishable from one that genuinely matched.
    local fake="$BATS_TEST_TMPDIR/stale-template.md"
    sed 's/650K \/ 700K \/ 750K/600K \/ 680K \/ 760K/' "$TEMPLATE" > "$fake"

    local tmpl ladder
    tmpl=$(_figures_after_default "$fake" | tr '\n' ' ')
    ladder=$(_ladder_k 800000 | tr '\n' ' ')
    [ "$tmpl" != "$ladder" ]
    [ "$tmpl" = "600K 680K 760K " ]
}

@test "T-3155: the template names FW_CONTEXT_WINDOW as the source of the numbers" {
    # Figures without their base are still ambiguous to a consumer.
    grep -q 'FW_CONTEXT_WINDOW' "$TEMPLATE"
}
