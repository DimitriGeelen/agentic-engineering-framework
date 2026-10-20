#!/usr/bin/env bats
# T-2859 — `fw work-on` usage text advertised `fw work-on "Fix login bug"
# --description "Details here"` with no --type. create-task.sh fails fast on a
# missing --type whenever stdin is not a tty (T-100160), which is every agent
# session, cron job and dispatch worker — so the example shown to a stuck new
# user could never work. This test RUNS every create-form example the usage
# text prints, off-tty, so a usage line and the parser cannot drift apart again.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export TASKS_DIR="$TEST_TEMP_DIR/.tasks"
    export CONTEXT_DIR="$TEST_TEMP_DIR/.context"
    export NO_COLOR=1
    unset CLAUDECODE
    unset AI_AGENT

    mkdir -p "$TASKS_DIR/active" "$TASKS_DIR/completed" "$TASKS_DIR/templates"
    mkdir -p "$CONTEXT_DIR/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" "$TASKS_DIR/templates/" 2>/dev/null || true
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "every create-form example in fw work-on usage succeeds off-tty" {
    run "$FRAMEWORK_ROOT/bin/fw" work-on </dev/null
    [ "$status" -eq 1 ]
    examples=$(printf '%s\n' "$output" | grep -E '^ *fw work-on "' | sed 's/ *#.*$//')
    [ -n "$examples" ]
    n=0
    while IFS= read -r ex; do
        n=$((n + 1))
        cmd="\"$FRAMEWORK_ROOT/bin/fw\"${ex#*fw}"
        run bash -c "$cmd </dev/null"
        if [ "$status" -ne 0 ]; then
            echo "usage example failed off-tty: $ex"
            echo "$output"
            return 1
        fi
        [[ "$output" == *"Ready to work on"* ]]
    done <<< "$examples"
    [ "$n" -ge 2 ]
}
