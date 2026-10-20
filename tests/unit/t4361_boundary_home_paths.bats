#!/usr/bin/env bats
# T-4361 (GitHub #104): the project-boundary gate hard-coded /root/.local/ and
# /root/.claude/, so a non-root account was refused reads of its own ~/.local and
# writes to its own ~/.claude, with no setting to allow a path. The zones now follow
# the running account's $HOME, and BOUNDARY_EXTRA_READ_PATHS adds read-only paths.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    [ -x "$HOOK" ]
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
    # A non-root home outside every built-in allowlist entry.
    export HOME="/home/t4361user"
    unset FW_BOUNDARY_EXTRA_READ_PATHS
}

run_bash() {
    local payload
    payload=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Bash', 'tool_input': {'command': sys.argv[1]}}))
" "$1")
    echo "$payload" | bash "$HOOK"
}

run_write() {
    local payload
    payload=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Write', 'tool_input': {'file_path': sys.argv[1], 'content': 'x'}}))
" "$1")
    echo "$payload" | bash "$HOOK"
}

@test "non-root account may read its own ~/.local tool install" {
    run run_bash 'cat /home/t4361user/.local/bin/fw'
    [ "$status" -eq 0 ]
}

@test "non-root account may read its own ~/.local via tilde" {
    run run_bash 'ls ~/.local/bin'
    [ "$status" -eq 0 ]
}

@test "non-root account may read its own ~/.claude" {
    run run_bash 'cat /home/t4361user/.claude/settings.json'
    [ "$status" -eq 0 ]
}

@test "non-root account may Write its own ~/.claude" {
    run run_write '/home/t4361user/.claude/projects/x/memory.md'
    [ "$status" -eq 0 ]
}

@test "non-root account may Bash-write its own ~/.claude" {
    run run_bash 'echo x > /home/t4361user/.claude/note.md'
    [ "$status" -eq 0 ]
}

@test "control: another account's home stays blocked for reads" {
    run run_bash 'cat /home/someoneelse/.local/bin/fw'
    [ "$status" -eq 2 ]
}

@test "control: own ~/.local is read-only (Bash write still blocked)" {
    run run_bash 'echo x > /home/t4361user/.local/bin/fw'
    [ "$status" -eq 2 ]
}

@test "control: /root/.claude stays allowed for root-run installs" {
    run run_bash 'cat /root/.claude/settings.json'
    [ "$status" -eq 0 ]
}

@test "BOUNDARY_EXTRA_READ_PATHS admits a read under /opt and /srv" {
    run run_bash 'cat /srv/tools/x.sh'
    [ "$status" -eq 2 ]
    run run_bash 'cat /opt/sharedtools/bin/y'
    [ "$status" -eq 2 ]
    export FW_BOUNDARY_EXTRA_READ_PATHS="/srv/tools:/opt/sharedtools/"
    run run_bash 'cat /srv/tools/x.sh'
    [ "$status" -eq 0 ]
    run run_bash 'cat /opt/sharedtools/bin/y'
    [ "$status" -eq 0 ]
}

@test "BOUNDARY_EXTRA_READ_PATHS does not widen writes" {
    export FW_BOUNDARY_EXTRA_READ_PATHS="/srv/tools"
    run run_bash 'echo x > /srv/tools/x.sh'
    [ "$status" -eq 2 ]
    run run_write '/srv/tools/x.sh'
    [ "$status" -eq 2 ]
}

@test "BOUNDARY_EXTRA_READ_PATHS ignores / and relative entries" {
    export FW_BOUNDARY_EXTRA_READ_PATHS="/:relative/dir::"
    run run_bash 'cat /srv/tools/x.sh'
    [ "$status" -eq 2 ]
}

@test "Bash block message names the config key" {
    run run_bash 'cat /srv/tools/x.sh'
    [ "$status" -eq 2 ]
    [[ "$output" == *"BOUNDARY_EXTRA_READ_PATHS"* ]]
}
