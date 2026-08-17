#!/usr/bin/env bats
# T-3050 — the B-005 refusal must name the way forward.
#
# The gate itself is NOT relaxed here and must not be. A matcher entry carries
# `{"type":"command","command":"<arbitrary shell>"}`, so an "additive" edit adds
# code that runs before every matching tool call and can delete the other
# matchers. Additive describes the declarative shape; the effect is unbounded.
#
# What was actually broken: the refusal ended at "requires human review" and
# named no mechanism, so agents escalated to the operator for a JSON paste-in —
# for a capability (`fw hook-enable`) that has shipped since T-1189. A gate with
# no exit is a gate people route around, and routing around it is what B-005 is
# for.
#
# So these tests pin BOTH directions at once: still refuses (exit 2), and now
# tells you what to do instead.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
GATE="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"

setup() {
    TMP=$(mktemp -d)
    export TMP
}

teardown() {
    rm -rf "$TMP"
}

# Drive the real hook the way Claude Code does: PreToolUse JSON on stdin.
run_gate() {  # run_gate <gate-script> <project-root> <file-path>
    echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$3\"}}" \
        | PROJECT_ROOT="$2" bash "$1"
}

@test "A3 — Write/Edit on .claude/settings.json still exits 2" {
    run run_gate "$GATE" "$FRAMEWORK_ROOT" "$FRAMEWORK_ROOT/.claude/settings.json"
    [ "$status" -eq 2 ]
}

@test "A1 — the refusal names fw hook-enable" {
    run run_gate "$GATE" "$FRAMEWORK_ROOT" "$FRAMEWORK_ROOT/.claude/settings.json"
    [[ "$output" == *"hook-enable"* ]]
}

@test "A1 — it gives a copy-pasteable line with a cd prefix" {
    # §Copy-Pasteable Commands: single line, cd-prefixed, works from any cwd.
    run run_gate "$GATE" "$FRAMEWORK_ROOT" "$FRAMEWORK_ROOT/.claude/settings.json"
    [[ "$output" == *"cd $FRAMEWORK_ROOT && bin/fw hook-enable"* ]]
}

@test "A1 — it covers the project-local case too (--script)" {
    run run_gate "$GATE" "$FRAMEWORK_ROOT" "$FRAMEWORK_ROOT/.claude/settings.json"
    [[ "$output" == *"--script"* ]]
}

@test "A1 — a consumer project is told .agentic-framework/bin/fw, not bin/fw" {
    # T-1257: consumers have no bin/ at their root. The framework repo ALSO
    # vendors itself at .agentic-framework/, so a naive "does .agentic-framework
    # exist" test advertises the consumer path to the framework repo itself —
    # which is why the discriminator is FRAMEWORK.md + bin/fw, checked first.
    mkdir -p "$TMP/consumer/.agentic-framework/bin" "$TMP/consumer/.claude"
    printf '#!/bin/sh\n' > "$TMP/consumer/.agentic-framework/bin/fw"
    chmod +x "$TMP/consumer/.agentic-framework/bin/fw"

    run run_gate "$GATE" "$TMP/consumer" "$TMP/consumer/.claude/settings.json"
    [ "$status" -eq 2 ]
    [[ "$output" == *"cd $TMP/consumer && .agentic-framework/bin/fw hook-enable"* ]]
    [[ "$output" != *"&& bin/fw hook-enable"* ]]
}

@test "A2 — it no longer claims flatly that hook changes need human review" {
    # The claim was false for the case being refused: fw hook-enable is a Bash
    # command and B-005 matches tool_input.file_path, so it never sees it. A
    # control that describes itself as wider than it is gets trusted past its
    # reach (OBS-315).
    run run_gate "$GATE" "$FRAMEWORK_ROOT" "$FRAMEWORK_ROOT/.claude/settings.json"
    [[ "$output" != *"Changes to hook configuration require human review."* ]]
}

@test "A2 — it states what B-005 actually covers" {
    run run_gate "$GATE" "$FRAMEWORK_ROOT" "$FRAMEWORK_ROOT/.claude/settings.json"
    [[ "$output" == *"Write/Edit"* ]]
}

@test "A2 — removal/rewiring is still routed to the operator" {
    # Adding is delegable; taking enforcement away is not.
    run run_gate "$GATE" "$FRAMEWORK_ROOT" "$FRAMEWORK_ROOT/.claude/settings.json"
    [[ "$output" == *"operator"* ]]
}

@test "A3 — no bypass env var was introduced alongside the friendlier message" {
    # The failure mode of "make the gate helpful" is making it optional.
    run bash -c "sed -n '/B-005 (T-229)/,/Policy: B-005/p' '$GATE' > '$TMP/blk'
                 grep -cE 'FW_[A-Z_]*(SKIP|ALLOW|BYPASS)[A-Z_]*' '$TMP/blk' || true"
    [ "$output" = "0" ]
}

@test "A4 — mutation: dropping the hook-enable mention turns the check red" {
    sed 's/hook-enable/REDACTED-VERB/g' "$GATE" > "$TMP/mutant.sh"
    ! cmp -s "$TMP/mutant.sh" "$GATE"          # the substitution must have landed
    run run_gate "$TMP/mutant.sh" "$FRAMEWORK_ROOT" "$FRAMEWORK_ROOT/.claude/settings.json"
    [[ "$output" != *"hook-enable"* ]]
}

@test "A4 — positive control: the mutant still blocks and still prints" {
    # Required by L-616. A mutant that failed to run would also print no
    # "hook-enable", which is indistinguishable from a detected mutation. This
    # proves the mutant is alive and only altered where intended.
    sed 's/hook-enable/REDACTED-VERB/g' "$GATE" > "$TMP/mutant.sh"
    run run_gate "$TMP/mutant.sh" "$FRAMEWORK_ROOT" "$FRAMEWORK_ROOT/.claude/settings.json"
    [ "$status" -eq 2 ]
    [[ "$output" == *"BLOCKED"* ]]
    [[ "$output" == *"REDACTED-VERB"* ]]
}

@test "A3 — an unrelated .claude/ file is still exempt (not swept up)" {
    # Guards the harness AND the ordering: B-005 is checked before the
    # exempt-path branch, so a too-greedy path match here would block every
    # .claude/ write in the project.
    mkdir -p "$FRAMEWORK_ROOT/.claude"
    run run_gate "$GATE" "$FRAMEWORK_ROOT" "$FRAMEWORK_ROOT/.claude/projects/config.json"
    [ "$status" -eq 0 ]
}
