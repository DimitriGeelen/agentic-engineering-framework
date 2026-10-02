#!/usr/bin/env bats
# Unit tests for agents/termlink/termlink.sh
# Origin: T-930

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
TERMLINK_SH="$FRAMEWORK_ROOT/agents/termlink/termlink.sh"

# --- Help ---

@test "termlink help shows usage" {
    run "$TERMLINK_SH" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw termlink"* ]]
    [[ "$output" == *"check"* ]]
    [[ "$output" == *"spawn"* ]]
    [[ "$output" == *"dispatch"* ]]
}

@test "termlink --help shows usage" {
    run "$TERMLINK_SH" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw termlink"* ]]
}

# --- Check ---

@test "termlink check reports installation" {
    run "$TERMLINK_SH" check
    [ "$status" -eq 0 ]
    # Should show version info
    [[ "$output" == *"termlink"* ]]
}

# --- Status ---

@test "termlink status runs without error" {
    run "$TERMLINK_SH" status
    [ "$status" -eq 0 ]
}

# --- Cleanup ---

@test "termlink cleanup runs without error" {
    # T-3595: NEVER run cleanup against the real /tmp/tl-dispatch. cmd_cleanup ends in
    # `rm -rf "$DISPATCH_DIR"`, so this test used to wipe every LIVE worker's result,
    # exit_code and meta whenever any worker ran the unit suite. Sandbox it.
    local dd="$BATS_TEST_TMPDIR/tl-dispatch"
    mkdir -p "$dd/done-worker" && echo 0 > "$dd/done-worker/exit_code"
    run bash -c "source '$TERMLINK_SH' >/dev/null 2>&1; DISPATCH_DIR='$dd'; cmd_cleanup --yes"  # T-3716: consent required since T-3651
    [ "$status" -eq 0 ]
    [ -d /tmp/tl-dispatch ] || [ ! -e /tmp/tl-dispatch ]
}

# --- Unknown command ---

@test "termlink unknown command fails" {
    run "$TERMLINK_SH" nonexistent_command
    [ "$status" -ne 0 ]
}

# --- Dispatch validation ---

@test "termlink dispatch fails without --name" {
    run "$TERMLINK_SH" dispatch
    [ "$status" -ne 0 ]
}

@test "termlink dispatch fails without --prompt" {
    run "$TERMLINK_SH" dispatch --name test-worker
    [ "$status" -ne 0 ]
}
