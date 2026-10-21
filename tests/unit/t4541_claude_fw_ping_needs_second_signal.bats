#!/usr/bin/env bats
# T-4541 — claude-fw --termlink must not end a LIVE agent on failed pings alone.
#
# Origin: 055 msg 3ff56409 (their T-587). Under host overload (load 283-443 on
# 24 cores, 2026-10-21) the local `termlink ping <session>` timed out for
# minutes, and after 3 consecutive failures (T-3648) every --termlink agent on
# the host was torn down, twice. A failed ping measures responsiveness, not
# existence. The session now ends only when a second signal agrees: no
# exact-name `termlink register --name <session>` process is left.
#
# Drives the REAL wrapper against a stub `termlink` whose ping ALWAYS fails.
# The stub's `spawn` starts a fake register process (argv holds `register` and
# `--name <session>` as separate words, as _tl_register_pids matches), which
# dies at ping number KILL_AT (0 = never). `pty output` shows the exit marker
# from poll MARKER_AT onward (0 = never). The no-process direction (sustained
# failure still ends the wait) stays pinned by t3648_claude_fw_ping_tolerance.bats.

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

    cat > "$BINDIR/fake-register" <<FAKE
#!/bin/bash
# argv: register --name <session> — lives until $STATE/die exists
while [ ! -e "$STATE/die" ]; do sleep 0.2; done
FAKE
    chmod +x "$BINDIR/fake-register"

    cat > "$BINDIR/termlink" <<STUB
#!/bin/bash
case "\$1" in
    spawn)
        nohup "$BINDIR/fake-register" register --name "\$3" >/dev/null 2>&1 </dev/null &
        echo \$! > "$STATE/fake.pid"
        exit 0 ;;
    ping)
        n=\$(cat "$STATE/pings_done"); n=\$((n + 1)); echo "\$n" > "$STATE/pings_done"
        k=\$(cat "$STATE/kill_at")
        if [ "\$k" -gt 0 ] && [ "\$n" -ge "\$k" ] && [ ! -e "$STATE/die" ]; then
            touch "$STATE/die"
            pid=\$(cat "$STATE/fake.pid" 2>/dev/null)
            [ -n "\$pid" ] && while kill -0 "\$pid" 2>/dev/null; do sleep 0.1; done
        fi
        exit 1 ;;
    pty)
        [ "\$2" = "inject" ] && printf '%s\\n' "\$4" > "$STATE/inject.last"
        if [ "\$2" = "output" ]; then
            p=\$(cat "$STATE/polls"); p=\$((p + 1)); echo "\$p" > "$STATE/polls"
            at=\$(cat "$STATE/marker_at")
            if [ "\$at" -gt 0 ] && [ "\$p" -ge "\$at" ]; then
                tok=\$(sed -E 's/.*__CLAUDE_FW_EXIT_([A-Za-z0-9]+)_%s__.*/\\1/' "$STATE/inject.last" 2>/dev/null)
                printf '__CLAUDE_FW_EXIT_%s_0__\n' "\$tok"
            fi
        fi
        exit 0 ;;
    *) exit 0 ;;
esac
STUB
    chmod +x "$BINDIR/termlink"
}

teardown() {
    [ -n "${STATE:-}" ] && touch "$STATE/die" 2>/dev/null
    if [ -n "${STATE:-}" ] && [ -f "$STATE/fake.pid" ]; then
        kill "$(cat "$STATE/fake.pid")" 2>/dev/null || true
    fi
    sleep 0.3
    [ -n "${STATE:-}" ] && rm -rf "$STATE"
    [ -n "${BINDIR:-}" ] && rm -rf "$BINDIR"
    [ -n "${PROJ:-}" ] && rm -rf "$PROJ"
    return 0
}

# $1 = ping at which the fake register process dies (0 = never), $2 = marker poll (0 = never)
run_wrapper() {
    echo "$1" > "$STATE/kill_at"
    echo "$2" > "$STATE/marker_at"
    cd "$PROJ"
    run timeout 120 env PATH="$BINDIR:$PATH" FW_NO_STARTUP_BANNER=1 \
        bash "$SRC" --termlink --no-restart -p "hello"
}

@test "every ping fails but the register process lives: session kept past the limit, ends on the marker (exit 0)" {
    run_wrapper 0 6
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE/pings_done")" -ge 5 ]
    [[ "$output" == *"DEGRADED"* ]]
    [[ "$output" != *"is gone"* ]]
}

@test "every ping fails and the register process dies: session declared gone (exit 1)" {
    run_wrapper 5 0
    [ "$status" -eq 1 ]
    [ "$(cat "$STATE/pings_done")" -eq 5 ]
    [[ "$output" == *"DEGRADED"* ]]
    [[ "$output" == *"no register process is left"* ]]
}
