#!/usr/bin/env bats
# T-3647 — claude-fw --termlink must not leak its claude-master register process.
#
# Port of 055-agentic-fleet-cockpit pickup P-009 (framework:pickup offset 241).
# termlink_cleanup used to inject `exit` into the session shell and run
# `termlink clean`, but the `termlink register --name claude-master-<pid>`
# process that owns the session outlives its shell and kept heartbeating.
#
# The stub `termlink spawn` here starts a REAL long-lived register stand-in (and a
# near-namesake decoy, `<name>0`), so the test measures the outcome — is the
# register process gone after the wrapper exits — rather than whether cleanup was
# merely attempted (which is all t3358 could see). The decoy must survive: the
# lookup is by exact name, never by pattern.

# T-3747: since T-3684 every claude-fw launch starts an always-on sidecar for
# its project; under a fixture it outlives the test, writes into the deleted
# tmpdir (teardown "Directory not empty") and slowed files past the suite cap.
export CLAUDE_FW_NO_SIDECAR=1

setup() {
    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    SRC="$FRAMEWORK_ROOT/bin/claude-fw"
    command -v python3 >/dev/null || skip "python3 unavailable"
    STATE="$(mktemp -d)"
    BINDIR="$(mktemp -d)"
    PROJ="$(mktemp -d)"
    mkdir -p "$PROJ/.context/working"

    # Register stand-in: argv carries `register --name <name>` like the real one.
    cat > "$BINDIR/fake-register" <<'FAKE'
#!/bin/bash
while :; do sleep 1; done
FAKE
    chmod +x "$BINDIR/fake-register"
}

# $1 = "list" → `termlink list --json` reports both sessions with their pids;
#      "none" → list reports nothing (the registration file is already gone,
#      which is what this host showed for every leaked process).
write_stub() {
    local list_mode="$1"
    cat > "$BINDIR/termlink" <<STUB
#!/bin/bash
echo "\$*" >> "$STATE/calls.log"
case "\$1" in
    spawn)
        name=""
        while [ \$# -gt 0 ]; do [ "\$1" = "--name" ] && name="\$2"; shift; done
        echo "\$name" > "$STATE/name"
        setsid "$BINDIR/fake-register" register --name "\$name" --shell </dev/null >/dev/null 2>&1 &
        echo \$! > "$STATE/reg.pid"
        setsid "$BINDIR/fake-register" register --name "\${name}0" --shell </dev/null >/dev/null 2>&1 &
        echo \$! > "$STATE/decoy.pid"
        exit 0 ;;
    list)
        if [ "$list_mode" = "list" ]; then
            n=\$(cat "$STATE/name"); r=\$(cat "$STATE/reg.pid"); d=\$(cat "$STATE/decoy.pid")
            printf '{"ok":true,"sessions":[{"display_name":"%s0","pid":%s},{"display_name":"%s","pid":%s}]}\n' "\$n" "\$d" "\$n" "\$r"
        else
            printf '{"ok":true,"sessions":[]}\n'
        fi
        exit 0 ;;
    pty)
        case "\$2" in
            output) printf '__CLAUDE_FW_EXIT_0__\n' ;;
        esac
        exit 0 ;;
    *) exit 0 ;;
esac
STUB
    chmod +x "$BINDIR/termlink"
}

teardown() {
    local f
    for f in reg.pid decoy.pid; do
        [ -f "${STATE:-/nonexistent}/$f" ] && kill "$(cat "$STATE/$f")" 2>/dev/null
    done
    [ -n "${STATE:-}" ] && rm -rf "$STATE"
    [ -n "${BINDIR:-}" ] && rm -rf "$BINDIR"
    [ -n "${PROJ:-}" ] && rm -rf "$PROJ"
    return 0
}

run_wrapper() {
    cd "$PROJ"
    run timeout 60 env PATH="$BINDIR:$PATH" FW_NO_STARTUP_BANNER=1 \
        bash "$SRC" --termlink --no-restart -p "hello"
}

alive() { kill -0 "$1" 2>/dev/null; }

@test "register process found via termlink list is SIGTERMed on exit; near-namesake decoy is not" {
    write_stub list
    run_wrapper
    [ "$status" -eq 0 ]
    reg=$(cat "$STATE/reg.pid"); decoy=$(cat "$STATE/decoy.pid")
    sleep 1
    run alive "$reg"
    [ "$status" -ne 0 ]
    alive "$decoy"
}

@test "register process invisible to termlink list is still found by exact argv; decoy is not" {
    write_stub none
    run_wrapper
    [ "$status" -eq 0 ]
    reg=$(cat "$STATE/reg.pid"); decoy=$(cat "$STATE/decoy.pid")
    sleep 1
    run alive "$reg"
    [ "$status" -ne 0 ]
    alive "$decoy"
}

@test "cleanup still injects exit and runs termlink clean (T-3358 contract kept)" {
    write_stub list
    run_wrapper
    [ "$status" -eq 0 ]
    run cat "$STATE/calls.log"
    [[ "$output" == *"pty inject claude-master-"*" exit --enter"* ]]
    [[ "$output" == *$'\n'"clean"* ]]
}
