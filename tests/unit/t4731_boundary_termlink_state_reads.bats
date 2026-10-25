#!/usr/bin/env bats
# T-4731 (010-termlink T-3000): the project-boundary gate refused reads of TermLink's
# own per-account state (`sqlite3 ~/.termlink/outbound.sqlite`) as "another project".
# ~/.termlink and the hub runtime dir are now READ zones, judged the same in the `~`,
# `$HOME` and absolute spellings; writes there and reads of other projects still refuse.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    [ -x "$HOOK" ]
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
    export HOME="/home/t4731user"
    unset FW_BOUNDARY_EXTRA_READ_PATHS TERMLINK_RUNTIME_DIR
}

run_bash() {
    local payload
    payload=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Bash', 'tool_input': {'command': sys.argv[1]}}))
" "$1")
    echo "$payload" | bash "$HOOK"
}

@test "read of ~/.termlink via literal tilde is allowed" {
    run run_bash 'sqlite3 ~/.termlink/outbound.sqlite .tables'
    [ "$status" -eq 0 ]
}

@test "read of ~/.termlink via \$HOME is allowed" {
    run run_bash 'sqlite3 $HOME/.termlink/outbound.sqlite .tables'
    [ "$status" -eq 0 ]
}

@test "read of ~/.termlink via absolute path is allowed" {
    run run_bash 'sqlite3 /home/t4731user/.termlink/outbound.sqlite .tables'
    [ "$status" -eq 0 ]
}

@test "read of /root/.termlink is allowed (root-run installs)" {
    run run_bash 'cat /root/.termlink/hubs.toml'
    [ "$status" -eq 0 ]
}

@test "read of the hub runtime dir /var/lib/termlink is allowed" {
    run run_bash 'ls /var/lib/termlink'
    [ "$status" -eq 0 ]
}

@test "read of a TERMLINK_RUNTIME_DIR named for termlink is allowed" {
    export TERMLINK_RUNTIME_DIR=/srv/termlink-hub
    run run_bash 'ls /srv/termlink-hub/sessions'
    [ "$status" -eq 0 ]
}

@test "a TERMLINK_RUNTIME_DIR not named for termlink opens nothing" {
    export TERMLINK_RUNTIME_DIR=/opt
    run run_bash 'cat /opt/other-project/.env'
    [ "$status" -eq 2 ]
}

@test "another project's file is refused via tilde" {
    run run_bash 'cat ~/other-project/.env'
    [ "$status" -eq 2 ]
}

@test "another project's file is refused via \$HOME" {
    run run_bash 'cat $HOME/other-project/.env'
    [ "$status" -eq 2 ]
}

@test "another project's file is refused via absolute path" {
    run run_bash 'cat /home/t4731user/other-project/.env'
    [ "$status" -eq 2 ]
}

@test "a ~/.termlink sibling prefix is not admitted" {
    run run_bash 'cat ~/.termlinkx/secret'
    [ "$status" -eq 2 ]
}

@test "dot-dot out of ~/.termlink is refused" {
    run run_bash 'cat ~/.termlink/../other-project/.env'
    [ "$status" -eq 2 ]
}

@test "a write into ~/.termlink stays refused (redirect)" {
    run run_bash 'echo x > ~/.termlink/outbound.sqlite'
    [ "$status" -eq 2 ]
}

@test "a write into ~/.termlink stays refused (cp target)" {
    run run_bash 'cp /tmp/x /home/t4731user/.termlink/identity.key'
    [ "$status" -eq 2 ]
}
