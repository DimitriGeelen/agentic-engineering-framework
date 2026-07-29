#!/usr/bin/env bats
# T-2674 — creation-side owner validation (residual G-040 hole).
#
# is_valid_owner() has existed since T-1180 (lib/enums.sh, compiled from
# status-transitions.yaml `owners:`) but create-task.sh never called it —
# any --owner string was written verbatim while Watchtower's dropdowns and
# update endpoints whitelist the enum. Surfaced by T-2666's task-creation
# corpus map + 832's round-#3 pair-draft verdict (rail 316).
#
# The enum was reconciled with live reality in the same task: `agent` (the
# fw work-on default, 500+ live tasks) added to status-transitions.yaml
# owners — the gate goes hard only against values outside {human,
# claude-code, agent}.

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
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

run_create() {
    run "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" "$@"
}

@test "invalid owner is rejected with the valid-owner list, no task file written" {
    run_create --name "Owner gate probe" --type build --description "test" --owner orchestrator
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid owner 'orchestrator'"* ]]
    [[ "$output" == *"Valid owners:"* ]]
    [ -z "$(ls "$TASKS_DIR/active" 2>/dev/null)" ]
}

@test "owner human is accepted" {
    run_create --name "Owner human probe" --type build --description "test" --owner human
    [ "$status" -eq 0 ]
    ls "$TASKS_DIR/active"/T-*-owner-human-probe.md >/dev/null
}

@test "owner claude-code is accepted" {
    run_create --name "Owner cc probe" --type build --description "test" --owner claude-code
    [ "$status" -eq 0 ]
    ls "$TASKS_DIR/active"/T-*-owner-cc-probe.md >/dev/null
}

@test "owner agent is accepted (enum reconciled with fw work-on default)" {
    run_create --name "Owner agent probe" --type build --description "test" --owner agent
    [ "$status" -eq 0 ]
    ls "$TASKS_DIR/active"/T-*-owner-agent-probe.md >/dev/null
}
