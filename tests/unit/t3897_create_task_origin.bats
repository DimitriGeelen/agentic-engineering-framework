#!/usr/bin/env bats
# T-3897 — `--origin` on task creation: the recorded answer to "where did this
# approval come from", shown as a badge on /approvals. Origin: T-3659, an
# unratified external proposal that the queue showed exactly like the
# operator's own request.

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

@test "--origin kind:source:ref is written to frontmatter as a map" {
    run_create --name "Origin probe" --type build --description "test" --owner agent \
        --origin "peer:ring20-dashboard:msg 711087b1"
    [ "$status" -eq 0 ]
    f=$(ls "$TASKS_DIR/active"/T-*-origin-probe.md)
    grep -q '^origin: {kind: "peer", source: "ring20-dashboard", ref: "msg 711087b1"}$' "$f"
}

@test "--origin with a kind only records just the kind" {
    run_create --name "Origin kind only" --type build --description "test" --owner agent --origin operator
    [ "$status" -eq 0 ]
    f=$(ls "$TASKS_DIR/active"/T-*-origin-kind-only.md)
    grep -q '^origin: {kind: "operator"}$' "$f"
}

@test "an unknown --origin kind is refused with exit 2 and no task file" {
    run_create --name "Origin bad kind" --type build --description "test" --owner agent --origin friend:someone
    [ "$status" -eq 2 ]
    [[ "$output" == *"--origin kind 'friend' unknown"* ]]
    [ -z "$(ls "$TASKS_DIR/active" 2>/dev/null)" ]
}

@test "no --origin writes no origin field (absence stays honest: unknown, never 'you')" {
    run_create --name "Origin absent" --type build --description "test" --owner agent
    [ "$status" -eq 0 ]
    f=$(ls "$TASKS_DIR/active"/T-*-origin-absent.md)
    ! grep -q '^origin:' "$f"
}

@test "fw inception start forwards --origin to create-task" {
    grep -q -- '--origin) origin="\$2"; shift 2 ;;' "$FRAMEWORK_ROOT/lib/inception.sh"
    grep -q -- '\${origin:+--origin "\$origin"}' "$FRAMEWORK_ROOT/lib/inception.sh"
}
