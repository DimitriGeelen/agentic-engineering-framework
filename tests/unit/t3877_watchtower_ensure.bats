#!/usr/bin/env bats
# T-3877: Watchtower is ensured at session start (lib/watchtower-ensure.sh,
# called detached from post-compact-resume.sh). After the 2026-10-05 reboot
# nothing started it — AEF's stayed down until started by hand, 055's ~80 min.
# A stub watchtower.sh records every start; the real one (and T-3876's port
# rule) is exercised by t3662/t3876.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FWROOT="${BATS_TEST_DIRNAME}/../.."
    export PROJECT_ROOT="$TEST_TEMP_DIR/proj" FRAMEWORK_ROOT="$FWROOT"
    mkdir -p "$PROJECT_ROOT/.context/working"
    STUB="$TEST_TEMP_DIR/watchtower.sh"
    export FW_WATCHTOWER_SH="$STUB" CALLS="$TEST_TEMP_DIR/calls"
    unset FW_WATCHTOWER_ENSURE FW_REVIEW_WORKER
    source "$FWROOT/lib/watchtower-ensure.sh"
}

_stub() {   # _stub <status-rc> <start-rc> [start-sleep]
    cat > "$STUB" <<EOF
#!/usr/bin/env bash
echo "\$1" >> "$CALLS"
case "\$1" in
    status) exit $1 ;;
    start)  sleep ${3:-0}; exit $2 ;;
esac
EOF
    chmod +x "$STUB"
}

_starts() { grep -c '^start$' "$CALLS" 2>/dev/null || true; }

@test "t3877: already running → status only, no start" {
    _stub 0 0
    run fw_watchtower_ensure
    [ "$status" -eq 0 ]
    [ "$(_starts)" -eq 0 ]
    grep -q "ok: already running" "$PROJECT_ROOT/.context/working/watchtower-ensure.log"
}

@test "t3877: not running → exactly one start, logged" {
    _stub 3 0
    run fw_watchtower_ensure
    [ "$status" -eq 0 ]
    [ "$(_starts)" -eq 1 ]
    grep -q "started" "$PROJECT_ROOT/.context/working/watchtower-ensure.log"
}

@test "t3877: FW_WATCHTOWER_ENSURE=0 disables it entirely" {
    _stub 3 0
    FW_WATCHTOWER_ENSURE=0 run fw_watchtower_ensure
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}

@test "t3877: a failing start still returns 0 and is logged as FAILED" {
    _stub 3 1
    run fw_watchtower_ensure
    [ "$status" -eq 0 ]
    grep -q "START FAILED" "$PROJECT_ROOT/.context/working/watchtower-ensure.log"
}

@test "t3877: two concurrent sessions after a reboot start it once (flock)" {
    _stub 3 0 2
    fw_watchtower_ensure &
    sleep 0.3
    fw_watchtower_ensure
    wait
    [ "$(_starts)" -eq 1 ]
    grep -q "another ensure holds the lock" "$PROJECT_ROOT/.context/working/watchtower-ensure.log"
}

@test "t3877: post-compact-resume calls it before the cold-start exit" {
    f="$FWROOT/agents/context/post-compact-resume.sh"
    e=$(grep -n 'fw_watchtower_ensure' "$f" | head -1 | cut -d: -f1)
    x=$(grep -n 'exit 0 *# cold start' "$f" | head -1 | cut -d: -f1)
    [ -n "$e" ] && [ -n "$x" ] && [ "$e" -lt "$x" ]
    grep -q 'setsid bash -c' "$f"
}
