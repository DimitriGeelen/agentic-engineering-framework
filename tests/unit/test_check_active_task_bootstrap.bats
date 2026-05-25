#!/usr/bin/env bats
# T-2052: task-bootstrap commands must never be blocked by the no-active-task gate.
#
# When focus is cleared (current_task: null — e.g. after a Watchtower inception
# decision), check-active-task.sh used to block ALL non-safe Bash, including
# `fw context focus`, `fw task create`, and `fw work-on` — the exact commands its
# own block message lists as the unblock path. Root cause: is_bash_safe_command
# extracted the base via `awk '{print $1}'` (first word), so a `cd … && bin/fw …`
# prefix or multi-line form resolved the base to `cd`/garbage and never inspected
# the fw subcommand; `fw task create` was also absent from the fw allowlist.
#
# This test pins: bootstrap commands allowed with NO active task (incl. cd-prefix
# and multi-line), non-bootstrap writes still blocked, write-pattern still wins.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export CLAUDECODE=1  # enforce (vs advisory)
    mkdir -p "$TEST_TEMP_DIR/.context/working" "$TEST_TEMP_DIR/.tasks/active"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_TEMP_DIR/.framework.yaml"

    # Focus CLEARED — the deadlock scenario.
    cat > "$TEST_TEMP_DIR/.context/working/focus.yaml" <<'EOF'
current_task: null
focus_session: S-test-001
EOF

    # One active task so the non-bootstrap-write test exercises the
    # no-active-task path (current_task empty), not a missing-file path.
    cat > "$TEST_TEMP_DIR/.tasks/active/T-1100-x.md" <<'EOF'
---
id: T-1100
status: started-work
---
# T-1100
EOF

    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    [ -x "$HOOK" ] || skip "check-active-task.sh not executable"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_run_hook_bash() {
    local cmd="$1"
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command': sys.argv[1]}}))" "$cmd")
    echo "$json" | "$HOOK"
}

@test "bootstrap: fw context focus allowed with no active task" {
    run _run_hook_bash "bin/fw context focus T-1100"
    [ "$status" -eq 0 ]
}

@test "bootstrap: fw work-on allowed with no active task" {
    run _run_hook_bash 'bin/fw work-on "new task" --type build'
    [ "$status" -eq 0 ]
}

@test "bootstrap: fw task create allowed with no active task" {
    run _run_hook_bash 'bin/fw task create --name foo --type build --owner agent'
    [ "$status" -eq 0 ]
}

@test "bootstrap: cd-prefixed bin/fw context focus allowed (the real deadlock form)" {
    run _run_hook_bash "cd /opt/project && bin/fw context focus T-1100"
    [ "$status" -eq 0 ]
}

@test "bootstrap: multi-line cd then bin/fw work-on allowed" {
    run _run_hook_bash "$(printf 'cd /opt/project\nbin/fw work-on T-1100')"
    [ "$status" -eq 0 ]
}

@test "bootstrap: bare fw (no bin/ prefix) work-on allowed" {
    run _run_hook_bash "fw work-on T-1100"
    [ "$status" -eq 0 ]
}

@test "non-bootstrap write still blocked: fw task update with no active task" {
    run _run_hook_bash "bin/fw task update T-1100 --status started-work"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "No active task" ]]
}

@test "gate not weakened: arbitrary source edit command still blocked" {
    run _run_hook_bash "echo x >> lib/init.sh"
    [ "$status" -eq 2 ]
}

@test "write-pattern wins: bootstrap command with a redirect falls through to block" {
    # A smuggled write (`> file`) must still be gated even on a bootstrap verb —
    # the write-pattern guard runs before the bootstrap allow.
    run _run_hook_bash "bin/fw work-on T-1100 > /tmp/should-not-matter"
    [ "$status" -eq 2 ]
}
