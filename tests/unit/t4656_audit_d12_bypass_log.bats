#!/usr/bin/env bats
# T-4656 — audit D12 (bypass-log growth) must read the log the writers write,
# and must not count approved inception decisions as bypasses.
#
# Every writer (agents/git/lib/common.sh BYPASS_LOG, check-tier0.sh T0_LOG_FILE,
# lib/tier0_action.py, bin/fw onboarding skip, lib/init.sh) and every other
# reader (audit.sh CTL-010, web/blueprints/enforcement.py) uses
# $CONTEXT_DIR/bypass-log.yaml. D12 read .context/project/bypass-log.yaml, which
# nothing writes, so it reported "PASS — no log file" forever. And the Tier-0
# gate logs each human-approved `fw inception decide` with risk
# "INCEPTION DECISION: ..." — a sanctioned decision, not a bypass.
#
# The test runs the REAL D12 block, cut verbatim out of audit.sh, against a
# fixture project, with pass/warn stubbed to print their verdict.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

setup() {
    TMP=$(mktemp -d)
    P="$TMP/proj"
    mkdir -p "$P/.context/project"
    awk '/^# D12: Bypass Log Growth/{f=1} f{print} f && /^fi$/{exit}' "$AUDIT" > "$TMP/d12.sh"
    grep -q 'D12: Bypass log' "$TMP/d12.sh"       # the block was found
}

teardown() {
    rm -rf "$TMP"
}

run_d12() {
    bash -c '
        PROJECT_ROOT="'"$P"'"
        CONTEXT_DIR="'"$P"'/.context"
        pass() { echo "PASS: $1"; }
        warn() { echo "WARN: $1"; }
        source "'"$TMP"'/d12.sh"
    '
}

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

real_bypass() {  # tier-0 approval of a genuinely destructive command
    printf -- "- timestamp: '%s'\n  tier: 0\n  risk: 'FORCE PUSH: rewrites remote history'\n  command_preview: git push --force origin x\n  authorized_by: human\n  mechanism: fw tier0 approve\n" "$(now)"
}

inception_decision() {  # tier-0 approval of a human inception decide
    printf -- "- timestamp: '%s'\n  tier: 0\n  risk: 'INCEPTION DECISION: GO/NO-GO decisions require human authority.'\n  command_preview: bin/fw inception decide T-1 go --rationale x\n  authorized_by: human\n  mechanism: fw tier0 approve\n" "$(now)"
}

@test "R1 — D12 reads the log at the writer path (\$CONTEXT_DIR/bypass-log.yaml)" {
    { echo "bypasses:"; real_bypass; } > "$P/.context/bypass-log.yaml"
    run run_d12
    [[ "$output" != *"no log file"* ]]
    [[ "$output" == *"1 recent_7d total=1"* ]]
}

@test "R2 — the dead .context/project/ path is not what D12 reads" {
    { echo "bypasses:"; real_bypass; } > "$P/.context/project/bypass-log.yaml"
    run run_d12
    [[ "$output" == *"no log file"* ]]
}

@test "R3 — an approved inception decision is not counted as a bypass" {
    { echo "bypasses:"; inception_decision; inception_decision; } > "$P/.context/bypass-log.yaml"
    run run_d12
    [[ "$output" == *"PASS: D12: Bypass log — normal (PASS total=0"* ]]
}

@test "R4 — real bypasses beside inception decisions are counted, and 5 recent WARN" {
    { echo "bypasses:"; for i in 1 2 3 4 5; do real_bypass; inception_decision; done; } \
        > "$P/.context/bypass-log.yaml"
    run run_d12
    [[ "$output" == *"WARN: D12: Bypass log growth — 5 recent_7d total=5"* ]]
}
