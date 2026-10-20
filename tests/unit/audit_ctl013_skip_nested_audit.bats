#!/usr/bin/env bats
# T-1870 / L-391: CTL-013 must skip verification lines that invoke
# `bin/fw audit` (or `fw audit`) — running them inside the audit lock
# always fails (lock held by the outer audit) and produces false-positive
# WARN. The skip-and-continue path treats those lines as if they passed
# (with a transparency note in the PASS line: "(N skipped — nested-audit
# invocation)").
#
# T-4380: these tests run the SHIPPED CTL-013 block, extracted from
# agents/audit/audit.sh between its own delimiters, against a fixture
# completed task. They used to grep a copy of the regex written out in the
# test, which stayed green when the skip branch in audit.sh was disabled.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"; export TEST_TEMP_DIR
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    TASKS_DIR="$TEST_TEMP_DIR/tasks"
    mkdir -p "$TASKS_DIR/completed"
    BLOCK="$TEST_TEMP_DIR/ctl013.sh"
    # Anchored on the block's own header and its closing `shopt -u nullglob`,
    # so a renamed or moved block fails loudly instead of yielding an empty
    # script that "passes".
    awk '/^# CTL-013 OE:/{f=1} f{print} f && /^shopt -u nullglob$/{exit}' "$AUDIT" > "$BLOCK"
    [ -s "$BLOCK" ] || { echo "CTL-013 extraction is empty — did the block move?" >&2; return 1; }
    grep -q 'nested-audit' "$BLOCK"
}

# ctl013 <verification-command>: run the shipped block on a fixture task whose
# only verification line is <cmd>; prints the pass()/warn() line it emits.
ctl013() {
    {
        printf -- '---\nid: T-9999\n---\n\n## Verification\n\n%s\n\n## Updates\n' "$1"
    } > "$TASKS_DIR/completed/T-9999-fixture.md"
    # A `fw` that always fails: if the skip branch is broken the nested audit line
    # is eval'd, and must neither start a real audit nor pass by accident.
    mkdir -p "$TEST_TEMP_DIR/stub"
    printf '#!/bin/sh\nexit 1\n' > "$TEST_TEMP_DIR/stub/fw"; chmod +x "$TEST_TEMP_DIR/stub/fw"
    PATH="$TEST_TEMP_DIR/stub:$PATH" TASKS_DIR="$TASKS_DIR" PROJECT_ROOT="$TEST_TEMP_DIR" bash -c '
        pass() { echo "PASS: $1"; }
        warn() { echo "WARN: $1"; }
        source "$1"
    ' _ "$BLOCK"
}

@test "L-391: detects 'bin/fw audit 2>&1 | grep -q Fail: 0' as nested" {
    run ctl013 'bin/fw audit 2>&1 | grep -q "Fail: 0"'
    [ "$status" -eq 0 ]
    [[ "$output" == PASS:*"1 skipped — nested-audit invocation"* ]]
}

@test "L-391: detects bare 'fw audit | grep' as nested" {
    run ctl013 'fw audit | grep -q ok'
    [[ "$output" == PASS:*"1 skipped — nested-audit invocation"* ]]
}

@test "L-391: detects '.agentic-framework/bin/fw audit' (consumer-shape path) as nested" {
    run ctl013 '.agentic-framework/bin/fw audit | grep -q pass'
    [[ "$output" == PASS:*"1 skipped — nested-audit invocation"* ]]
}

@test "L-391: does NOT mis-detect 'fw auditor' (unrelated subcommand)" {
    # Hypothetical future subcommand. Should not be skipped: it is run, and
    # fails here because no such command exists.
    run ctl013 'fw auditor --check thing'
    ! [[ "$output" == *"nested-audit"* ]] || false
    [[ "$output" == WARN:*"1 command(s) failing"* ]]
}

@test "L-391: does NOT mis-detect commands that quote 'fw audit' as a string" {
    # If a verification command merely references the literal phrase but
    # doesn't *run* audit (e.g. checks a log entry), it'll still match —
    # this is a known limitation, but safer to over-skip than to false-WARN.
    # Pin the limitation explicitly.
    run ctl013 'grep -q "ran fw audit at 12:00" /tmp/log.txt'
    [[ "$output" == PASS:*"1 skipped — nested-audit invocation"* ]]
    # Test asserts the over-match — if you change the predicate to be
    # more precise (require leading whitespace, etc.), update this test.
}

@test "L-391: does NOT match 'softwareauditing' or other word-internal hits" {
    run ctl013 'softwareauditing-tool --check'
    ! [[ "$output" == *"nested-audit"* ]] || false
    [[ "$output" == WARN:*"1 command(s) failing"* ]]
}

@test "L-391: a non-audit passing command is counted, not skipped (control)" {
    run ctl013 'true'
    [[ "$output" == "PASS: CTL-013: T-9999 verification re-run: 1/1 pass" ]]
}

@test "L-391: audit.sh CTL-013 contains the skip block" {
    # Source-of-truth pin: the audit.sh code MUST contain the skip
    # branch with the same regex. If this test fails, someone refactored
    # CTL-013 without preserving the L-391 protection.
    grep -q 'L-391\b' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    grep -q "(\\\\bbin/)?fw +audit\\\\b" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

@test "OBS-022: audit.sh CTL-013 contains bats-isolation-retry block" {
    # Source-of-truth pin: the OBS-022 retry path (re-run failing bats
    # commands under `env -i`) MUST be present. If this drifts, the
    # T-1858/T-1861 false-positive class resurfaces.
    grep -q "OBS-022" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    grep -q "cmd_isolated_pass" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    grep -q "env -i" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
}
