#!/usr/bin/env bats
# T-3648 — claude-fw --termlink must not end a live agent on ONE failed ping.
#
# Port of 055-agentic-fleet-cockpit pickups P-011 / P-012 (framework:pickup
# offsets 242, 244). The TermLink wait loop did `if ! termlink ping ...; then
# exit_code=1; break` — a single ping that failed or timed out under CPU load
# ended the wrapper, and without autorestart the agent's tmux session with it.
#
# Drives the REAL wrapper against a stub `termlink` whose `ping` answers from a
# script (one word per poll: ok|fail; `ok` once the script runs out) and whose
# `pty output` shows the exit marker from poll MARKER_AT onward (never if 0).
# Both directions are pinned: a transient failure is tolerated, and a session
# that really is gone is still declared gone after CLAUDE_FW_PING_FAILURES.

# T-3747: since T-3684 every claude-fw launch starts an always-on sidecar for
# its project; under a fixture it outlives the test, writes into the deleted
# tmpdir (teardown "Directory not empty") and slowed files past the suite cap.
export CLAUDE_FW_NO_SIDECAR=1

setup() {
    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    SRC="$FRAMEWORK_ROOT/bin/claude-fw"
    STATE="$(mktemp -d)"
    BINDIR="$(mktemp -d)"
    PROJ="$(mktemp -d)"
    mkdir -p "$PROJ/.context/working"
    echo 0 > "$STATE/pings_done"
    echo 0 > "$STATE/polls"

    cat > "$BINDIR/termlink" <<STUB
#!/bin/bash
case "\$1" in
    ping)
        n=\$(cat "$STATE/pings_done"); n=\$((n + 1)); echo "\$n" > "$STATE/pings_done"
        verdict=\$(sed -n "\${n}p" "$STATE/script")
        [ "\$verdict" = "fail" ] && exit 1
        exit 0 ;;
    pty)
        if [ "\$2" = "output" ]; then
            p=\$(cat "$STATE/polls"); p=\$((p + 1)); echo "\$p" > "$STATE/polls"
            at=\$(cat "$STATE/marker_at")
            if [ "\$at" -gt 0 ] && [ "\$p" -ge "\$at" ]; then
                printf '__CLAUDE_FW_EXIT_0__\n'
            fi
        fi
        exit 0 ;;
    *) exit 0 ;;
esac
STUB
    chmod +x "$BINDIR/termlink"
}

teardown() {
    [ -n "${STATE:-}" ] && rm -rf "$STATE"
    [ -n "${BINDIR:-}" ] && rm -rf "$BINDIR"
    [ -n "${PROJ:-}" ] && rm -rf "$PROJ"
    return 0
}

# $1 = ping script (space-separated ok|fail), $2 = poll at which the marker shows (0 = never)
run_wrapper() {
    printf '%s\n' $1 > "$STATE/script"
    echo "$2" > "$STATE/marker_at"
    cd "$PROJ"
    run timeout 90 env PATH="$BINDIR:$PATH" FW_NO_STARTUP_BANNER=1 \
        bash "$SRC" --termlink --no-restart -p "hello"
}

@test "one failed ping is tolerated: wrapper waits for the marker and exits 0 (the 055 bug)" {
    run_wrapper "fail" 2
    [ "$status" -eq 0 ]
    [[ "$output" == *"ping failed (1/3)"* ]]
}

@test "a success resets the count: fail fail ok fail fail never reaches 3, marker exit is 0" {
    run_wrapper "fail fail ok fail fail" 5
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE/pings_done")" -eq 5 ]
}

@test "sustained failure still ends the wait: exits 1 after exactly 3 consecutive failed pings" {
    run_wrapper "fail fail fail fail fail fail" 0
    [ "$status" -eq 1 ]
    [ "$(cat "$STATE/pings_done")" -eq 3 ]
}

@test "CLAUDE_FW_PING_FAILURES=2 is honoured" {
    export CLAUDE_FW_PING_FAILURES=2
    run_wrapper "fail fail fail fail" 0
    [ "$status" -eq 1 ]
    [ "$(cat "$STATE/pings_done")" -eq 2 ]
}

@test "non-numeric CLAUDE_FW_PING_FAILURES falls back to 3" {
    export CLAUDE_FW_PING_FAILURES=abc
    run_wrapper "fail fail fail fail fail" 0
    [ "$status" -eq 1 ]
    [ "$(cat "$STATE/pings_done")" -eq 3 ]
}

@test "CLAUDE_FW_PING_FAILURES=0 falls back to 3" {
    export CLAUDE_FW_PING_FAILURES=0
    run_wrapper "fail fail fail fail fail" 0
    [ "$status" -eq 1 ]
    [ "$(cat "$STATE/pings_done")" -eq 3 ]
}
