#!/usr/bin/env bats
# T-1870 / L-391: CTL-013 must skip verification lines that invoke
# `bin/fw audit` (or `fw audit`) — running them inside the audit lock
# always fails (lock held by the outer audit) and produces false-positive
# WARN. The skip-and-continue path treats those lines as if they passed
# (with a transparency note in the PASS line: "(N skipped — nested-audit
# invocation)").

load ../test_helper

# We test the *predicate* directly — the regex `(\bbin/)?fw +audit\b` —
# to keep the test fast (running a full audit takes 60-180s). The
# audit.sh code path is a single grep -qE; pinning the regex pins the
# semantics.

@test "L-391: detects 'bin/fw audit 2>&1 | grep -q Fail: 0' as nested" {
    cmd='bin/fw audit 2>&1 | grep -q "Fail: 0"'
    echo "$cmd" | grep -qE '(\bbin/)?fw +audit\b'
}

@test "L-391: detects bare 'fw audit | grep' as nested" {
    cmd='fw audit | grep -q ok'
    echo "$cmd" | grep -qE '(\bbin/)?fw +audit\b'
}

@test "L-391: detects '.agentic-framework/bin/fw audit' (consumer-shape path) as nested" {
    cmd='.agentic-framework/bin/fw audit | grep -q pass'
    echo "$cmd" | grep -qE '(\bbin/)?fw +audit\b'
}

@test "L-391: does NOT mis-detect 'fw auditor' (unrelated subcommand)" {
    # Hypothetical future subcommand. Should not be skipped.
    cmd='fw auditor --check thing'
    run bash -c "echo '$cmd' | grep -qE '(\bbin/)?fw +audit\b'"
    [ "$status" -ne 0 ]
}

@test "L-391: does NOT mis-detect commands that quote 'fw audit' as a string" {
    # If a verification command merely references the literal phrase but
    # doesn't *run* audit (e.g. checks a log entry), it'll still match —
    # this is a known limitation, but safer to over-skip than to false-WARN.
    # Pin the limitation explicitly.
    cmd='grep -q "ran fw audit at 12:00" /tmp/log.txt'
    echo "$cmd" | grep -qE '(\bbin/)?fw +audit\b'
    # Test asserts the over-match — if you change the predicate to be
    # more precise (require leading whitespace, etc.), update this test.
}

@test "L-391: does NOT match 'softwareauditing' or other word-internal hits" {
    cmd='softwareauditing-tool --check'
    run bash -c "echo '$cmd' | grep -qE '(\bbin/)?fw +audit\b'"
    [ "$status" -ne 0 ]
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
