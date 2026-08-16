#!/usr/bin/env bats
# T-3029 -- Regression: update-task.sh's close-time AC gate must not silently
# report zero Human ACs when a `### Human` heading is separated from
# `## Acceptance Criteria` by an intervening `## ` heading.
#
# Origin: T-3028 was archived to completed/ with owner:agent and an unticked
# [REVIEW] Human AC still in the body, because
# `sed -n '/^## Acceptance Criteria/,/^## /p'` closed the AC section at
# `## Measured Result` -- which sat between `### Agent` and `### Human` --
# before the parser ever saw the Human heading. T-2420's PreToolUse hook
# prevents this shape from being *written* (once wired into
# .claude/settings.json), but does not cover files already malformed on
# disk. This suite pins the close-time backstop added directly to
# check_acceptance_criteria.

load ../test_helper

UPDATE_TASK="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    unset FW_ALLOW_AC_STRUCTURE_DRIFT
    mkdir -p "$PROJECT_ROOT/.tasks/active" \
             "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.tasks/templates" \
             "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/episodic"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" \
       "$PROJECT_ROOT/.tasks/templates/default.md" 2>/dev/null || \
       echo "# template" > "$PROJECT_ROOT/.tasks/templates/default.md"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# `### Human` after an intervening `## ` heading -- the T-3028 shape.
_make_malformed_task() {
    local id="$1"
    local task_file="$PROJECT_ROOT/.tasks/active/${id}-test-task.md"
    {
        echo "---"
        echo "id: $id"
        echo "name: \"Test malformed-AC-structure task\""
        echo "description: \"Test fixture for T-3029 regression\""
        echo "status: started-work"
        echo "workflow_type: build"
        echo "owner: agent"
        echo "horizon: now"
        echo "tags: []"
        echo "created: 2026-04-27T00:00:00Z"
        echo "last_update: 2026-04-27T00:00:00Z"
        echo "date_finished: null"
        echo "---"
        echo ""
        echo "# $id: Test malformed-AC-structure task"
        echo ""
        echo "## Acceptance Criteria"
        echo ""
        echo "### Agent"
        echo "- [x] Agent did the work"
        echo ""
        echo "## Measured Result"
        echo ""
        echo "Some intervening content that closes the sed range early."
        echo ""
        echo "### Human"
        echo "- [ ] [REVIEW] Human eyeballs it"
        echo "  **Steps:**"
        echo "  1. Look at it"
        echo "  **Expected:** Looks good"
        echo "  **If not:** Fix it"
        echo ""
        echo "## Verification"
        echo ""
        echo "## Recommendation"
        echo ""
        echo "**Recommendation:** GO"
        echo ""
        echo "**Rationale:** Test fixture."
    } > "$task_file"
    echo "$task_file"
}

# Same content, correctly ordered -- no `##` heading between Agent and Human.
_make_correct_task() {
    local id="$1"
    local task_file="$PROJECT_ROOT/.tasks/active/${id}-test-task.md"
    {
        echo "---"
        echo "id: $id"
        echo "name: \"Test correct-AC-structure task\""
        echo "description: \"Test fixture for T-3029 regression control\""
        echo "status: started-work"
        echo "workflow_type: build"
        echo "owner: agent"
        echo "horizon: now"
        echo "tags: []"
        echo "created: 2026-04-27T00:00:00Z"
        echo "last_update: 2026-04-27T00:00:00Z"
        echo "date_finished: null"
        echo "---"
        echo ""
        echo "# $id: Test correct-AC-structure task"
        echo ""
        echo "## Acceptance Criteria"
        echo ""
        echo "### Agent"
        echo "- [x] Agent did the work"
        echo ""
        echo "### Human"
        echo "- [ ] [REVIEW] Human eyeballs it"
        echo "  **Steps:**"
        echo "  1. Look at it"
        echo "  **Expected:** Looks good"
        echo "  **If not:** Fix it"
        echo ""
        echo "## Measured Result"
        echo ""
        echo "Some content after the AC block -- harmless here."
        echo ""
        echo "## Verification"
        echo ""
        echo "## Recommendation"
        echo ""
        echo "**Recommendation:** GO"
        echo ""
        echo "**Rationale:** Test fixture."
    } > "$task_file"
    echo "$task_file"
}

@test "malformed structure refuses close instead of silently reporting zero Human ACs" {
    _make_malformed_task "T-9995"
    run "$UPDATE_TASK" T-9995 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"outside"* ]]
    [[ "$output" == *"### Human"* ]]
    # Must not have silently archived as fully complete.
    [ -f "$PROJECT_ROOT/.tasks/active/T-9995-test-task.md" ]
    [ ! -f "$PROJECT_ROOT/.tasks/completed/T-9995-test-task.md" ]
    grep -q "status: started-work" "$PROJECT_ROOT/.tasks/active/T-9995-test-task.md"
}

@test "malformed structure with FW_ALLOW_AC_STRUCTURE_DRIFT=1 bypasses and logs" {
    _make_malformed_task "T-9996"
    export FW_ALLOW_AC_STRUCTURE_DRIFT=1
    run "$UPDATE_TASK" T-9996 --status work-completed
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    local log="$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    grep -q "T-9996" "$log"
    grep -q "FW_ALLOW_AC_STRUCTURE_DRIFT" "$log"
}

# A `### Human` line quoted INSIDE an HTML comment is not a heading. The default
# template's AC-routing guidance quotes exactly that, so a raw-file grep trips on
# it: 6 of 60 task files in this repo matched with no misplaced heading at all.
# The guard strips comments the same way ac_section does, so both sides of the
# comparison read the same document.
_make_commented_mention_task() {
    local id="$1"
    local task_file="$PROJECT_ROOT/.tasks/active/${id}-test-task.md"
    {
        echo "---"
        echo "id: $id"
        echo "name: \"Test commented-mention control\""
        echo "description: \"Test fixture for the T-3029 false-positive class\""
        echo "status: started-work"
        echo "workflow_type: build"
        echo "owner: agent"
        echo "horizon: now"
        echo "tags: []"
        echo "created: 2026-04-27T00:00:00Z"
        echo "last_update: 2026-04-27T00:00:00Z"
        echo "date_finished: null"
        echo "---"
        echo ""
        echo "# $id: Test commented-mention control"
        echo ""
        echo "## Acceptance Criteria"
        echo ""
        echo "### Agent"
        echo "- [x] Agent did the work"
        echo ""
        echo "## Notes"
        echo ""
        echo "<!-- Routing guidance quoted verbatim from the template:"
        echo "### Human"
        echo "- [ ] [REVIEW] example criterion that is not a real AC"
        echo "-->"
        echo ""
        echo "## Verification"
    } > "$task_file"
    echo "$task_file"
}

@test "a ### Human quoted inside an HTML comment does not trip the guard" {
    _make_commented_mention_task "T-9998"
    run "$UPDATE_TASK" T-9998 --status work-completed
    [[ "$output" != *"positioned outside"* ]]
    # No real Human ACs, so this is a full completion, not partial-complete.
    [ -f "$PROJECT_ROOT/.tasks/completed/T-9998-test-task.md" ]
}

@test "correctly-structured task is unaffected: reaches normal partial-complete path" {
    _make_correct_task "T-9997"
    run "$UPDATE_TASK" T-9997 --status work-completed
    [ "$status" -eq 0 ]
    [[ "$output" != *"outside \`## Acceptance Criteria\`"* ]]
    [[ "$output" == *"Partial-complete"* ]]
    [ -f "$PROJECT_ROOT/.tasks/active/T-9997-test-task.md" ]
    [ ! -f "$PROJECT_ROOT/.tasks/completed/T-9997-test-task.md" ]
}
