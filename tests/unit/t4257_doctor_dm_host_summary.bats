#!/usr/bin/env bats
# T-4257 (0909 run F-11): `fw doctor` counted the host-wide TermLink DM-rail backlog as
# per-project WARNs — 13 of 31 warnings on a minutes-old project — and told the operator
# to drain it. Under the host-default identity every rail on the machine is addressed to
# every project, so the backlog is not this project's to act on.
#
# Fixture: a fake `termlink` whose `whoami --json` answers the host fingerprint, or an own
# fingerprint when an identity env var selects one — the same contract dm.py's
# identity_is_host_shared() reads (T-4252). The real probe runs; no hub is touched.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    mkdir -p "$TEST_TEMP_DIR/bin"
    cat > "$TEST_TEMP_DIR/bin/termlink" <<'SH'
#!/usr/bin/env bash
# Fake `termlink whoami --json`: own fingerprint when an identity env var is set.
if [ "$1" = "whoami" ]; then
    if [ -n "${TERMLINK_IDENTITY_FILE:-}${TERMLINK_AGENT_ID:-}${TERMLINK_IDENTITY_DIR:-}" ]; then
        fp=ownfp
    else
        fp=hostfp
    fi
    printf '{"session":{"identity_fingerprint":"%s"}}\n' "$fp"
    exit 0
fi
exit 1
SH
    chmod +x "$TEST_TEMP_DIR/bin/termlink"
    export PATH="$TEST_TEMP_DIR/bin:$PATH"
    unset TERMLINK_IDENTITY_FILE TERMLINK_AGENT_ID TERMLINK_IDENTITY_DIR FW_SIDECAR_IDENTITY_FP
    source "$FRAMEWORK_ROOT/lib/sidecar-audit.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

@test "T-4257: host-default identity is detected as host-shared" {
    run fw_sidecar_dm_host_shared
    [ "$status" -eq 0 ]
}

@test "T-4257: a project with its own identity is NOT host-shared" {
    export TERMLINK_IDENTITY_FILE="$TEST_TEMP_DIR/own.key"
    run fw_sidecar_dm_host_shared
    [ "$status" -eq 1 ]
}

@test "T-4257: host-shared backlog folds into ONE summary line with totals" {
    rows=$(printf 'dm:aaaa:hostfp\t5\t30.5\ndm:bbbb:hostfp\t2\t100\n')
    run fw_sidecar_dm_host_summary "$rows"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | wc -l)" -eq 1 ]
    echo "$output" | grep -q "2 DM rail"
    echo "$output" | grep -q "7 unread"
    echo "$output" | grep -q "4.2d"
}

@test "T-4257: host-scoped summary gives no drain advice and is not a WARN" {
    rows=$(printf 'dm:aaaa:hostfp\t5\t30.5\n')
    run fw_sidecar_dm_host_summary "$rows"
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -qi "drain"
    ! echo "$output" | grep -q "fw sidecar"
    ! echo "$output" | grep -q "WARN"
}

@test "T-4257: no rails means no summary line at all" {
    run fw_sidecar_dm_host_summary ""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-4257: doctor consults the host-shared probe before the per-rail WARN loop" {
    # Source-level pin, comments stripped (L-519). Without the probe call the per-rail
    # loop runs for every rail, which is the F-11 defect itself.
    body=$(sed 's/[[:space:]]*#.*//' "$FRAMEWORK_ROOT/bin/fw")
    echo "$body" | grep -q "fw_sidecar_dm_host_shared"
    echo "$body" | grep -q "fw_sidecar_dm_host_summary"
}
