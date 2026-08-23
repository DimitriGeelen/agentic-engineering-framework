#!/usr/bin/env bats
# T-3070 — a full (unscoped) `fw audit` run inherited the same 600s internal
# watchdog as section-scoped cron runs, even though it walks ~28 section
# headers plus whole-tree scans. Measured killed mid-run at 590s having
# reached only 12/28 sections (T-1719). This pins the fix: full runs get a
# larger default timeout; section-scoped runs (the frequent cron case) keep
# the original 600s fast-fail; FW_AUDIT_TIMEOUT still overrides either.
#
# Drives the SHIPPED block out of audit.sh via sed range extraction (same
# technique as t2930's _decision_block) so the test cannot pass against
# source that no longer matches what ships.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

_timeout_block() {
    sed -n '/^if \[ -z "\$SECTIONS" \]; then$/,/^fi$/p' "$AUDIT"
}

@test "t3070: the timeout-resolution block is present in source" {
    run _timeout_block
    [ -n "$output" ]
    [[ "$output" == *'AUDIT_TIMEOUT="${FW_AUDIT_TIMEOUT:-${FW_AUDIT_FULL_TIMEOUT:-'*'}}"'* ]]
}

_resolve() {
    # $1 = SECTIONS value ("" = full run), remaining args = env assignments
    local sections="$1"; shift
    local block; block=$(_timeout_block)
    [ -n "$block" ] || { echo "could not extract timeout block from audit.sh" >&2; return 1; }
    run env -u FW_AUDIT_TIMEOUT -u FW_AUDIT_FULL_TIMEOUT "$@" \
        bash -c "SECTIONS='$sections'
$block
echo \"\$AUDIT_TIMEOUT\""
}

@test "t3070: full run (SECTIONS empty) defaults to a timeout well above 600s" {
    _resolve ""
    [ "$status" -eq 0 ]
    [ "$output" -gt 600 ] || { echo "full-run default $output is not > 600" >&2; return 1; }
}

@test "t3070: section-scoped run keeps the original 600s default" {
    _resolve "structure"
    [ "$status" -eq 0 ]
    [ "$output" -eq 600 ] || { echo "section-run default changed: $output" >&2; return 1; }
}

@test "t3070: FW_AUDIT_TIMEOUT overrides the full-run default" {
    _resolve "" FW_AUDIT_TIMEOUT=123
    [ "$status" -eq 0 ]
    [ "$output" -eq 123 ]
}

@test "t3070: FW_AUDIT_TIMEOUT overrides the section-run default" {
    _resolve "structure" FW_AUDIT_TIMEOUT=124
    [ "$status" -eq 0 ]
    [ "$output" -eq 124 ]
}

@test "t3070: FW_AUDIT_FULL_TIMEOUT tunes the full-run default without FW_AUDIT_TIMEOUT" {
    _resolve "" FW_AUDIT_FULL_TIMEOUT=987
    [ "$status" -eq 0 ]
    [ "$output" -eq 987 ]
}

@test "t3070: FW_AUDIT_FULL_TIMEOUT does not affect section-scoped runs" {
    _resolve "structure" FW_AUDIT_FULL_TIMEOUT=987
    [ "$status" -eq 0 ]
    [ "$output" -eq 600 ]
}

@test "t3070: passes shell syntax check after edit" {
    run bash -n "$AUDIT"
    [ "$status" -eq 0 ]
}
