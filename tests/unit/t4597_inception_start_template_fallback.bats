#!/usr/bin/env bats
# T-4597 — `fw inception start` in a project with no .tasks/templates/.
#
# Two defects, one symptom (tests/integration/fw_inception.bats 3-5 red):
#   1. create-task.sh read templates only from the project, so an unseeded project
#      fell to the inline fallback, which has no ## Recommendation / ## Decision,
#      and the T-1263 check refused every inception.
#   2. do_inception_start captured create-task's output in `output=$(...)` under
#      bin/fw's set -e, so that refusal aborted the verb before it was echoed:
#      exit 1, nothing printed.

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    export NO_COLOR=1
    unset CLAUDECODE CLAUDE_CODE_ENTRYPOINT AI_AGENT FW_INCEPTION_PRE_GATED
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "inception start with no project templates uses the framework template" {
    [ ! -d "$PROJECT_ROOT/.tasks/templates" ]
    run "$FW" inception start "Template fallback probe"
    [ "$status" -eq 0 ]
    local f
    f=$(ls "$PROJECT_ROOT/.tasks/active/"T-*-template-fallback-probe.md)
    grep -q '^workflow_type: inception' "$f"
    grep -qE '^## Recommendation[[:space:]]*$' "$f"
    grep -qE '^## Decision[[:space:]]*$' "$f"
}

@test "task create with no project templates uses the framework default template" {
    run "$FW" task create --name "Default fallback probe" --description "probe" \
        --type build --owner agent
    [ "$status" -eq 0 ]
    local f
    f=$(ls "$PROJECT_ROOT/.tasks/active/"T-*-default-fallback-probe.md)
    grep -q '^## RCA' "$f"
}

@test "a project template still wins over the framework copy" {
    mkdir -p "$PROJECT_ROOT/.tasks/templates"
    cp "$FRAMEWORK_ROOT/.tasks/templates/inception.md" "$PROJECT_ROOT/.tasks/templates/"
    echo "PROJECT-TEMPLATE-MARKER" >> "$PROJECT_ROOT/.tasks/templates/inception.md"
    run "$FW" inception start "Project template probe"
    [ "$status" -eq 0 ]
    grep -q 'PROJECT-TEMPLATE-MARKER' "$PROJECT_ROOT/.tasks/active/"T-*-project-template-probe.md
}

@test "a create-task refusal is printed and fails the verb, not swallowed" {
    mkdir -p "$PROJECT_ROOT/.tasks/templates"
    # A project inception template without the required sections.
    grep -vE '^## (Recommendation|Decision)[[:space:]]*$' \
        "$FRAMEWORK_ROOT/.tasks/templates/inception.md" > "$PROJECT_ROOT/.tasks/templates/inception.md"
    run "$FW" inception start "Broken template probe"
    [ "$status" -ne 0 ]
    [[ "$output" == *"missing required sections"* ]]
    [[ "$output" == *"inception task was not created"* ]]
}
