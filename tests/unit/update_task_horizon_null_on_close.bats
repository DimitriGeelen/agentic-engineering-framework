#!/usr/bin/env bats
# T-2163 / arc-009 Slice 4: write-side horizon-null at full close.
#
# update-task.sh nulls the stored `horizon:` field when moving a task into
# .tasks/completed/. Partial-complete (file stays in active/) does NOT
# touch horizon — that branch still renders via the stored value.
#
# This test pins both branches in isolation so any future refactor that
# regresses either direction trips the bats gate.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/episodic"
    git -C "$PROJECT_ROOT" init -q
    git -C "$PROJECT_ROOT" config user.email "test@test"
    git -C "$PROJECT_ROOT" config user.name "test"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: write a minimal full-close-ready task.
_mk_full_close_task() {
    local id="$1"
    cat > "$PROJECT_ROOT/.tasks/active/${id}-test.md" <<EOF
---
id: $id
name: "test task"
status: started-work
workflow_type: build
owner: claude-code
horizon: now
tags: []
created: 2026-06-01T00:00:00Z
last_update: 2026-06-01T00:00:00Z
---

# $id: test task

## Acceptance Criteria

### Agent
- [x] Done

## Verification
EOF
    git -C "$PROJECT_ROOT" add ".tasks/active/${id}-test.md" 2>/dev/null
    git -C "$PROJECT_ROOT" commit -qm "init $id" 2>/dev/null
}

# Helper: write a partial-complete task (1 unchecked Human AC).
_mk_partial_complete_task() {
    local id="$1"
    cat > "$PROJECT_ROOT/.tasks/active/${id}-test.md" <<EOF
---
id: $id
name: "test task"
status: started-work
workflow_type: build
owner: claude-code
horizon: now
tags: []
created: 2026-06-01T00:00:00Z
last_update: 2026-06-01T00:00:00Z
---

# $id: test task

## Acceptance Criteria

### Agent
- [x] Done

### Human
- [ ] [REVIEW] Visual check
  **Steps:** 1. Open URL.
  **Expected:** No layout break.
  **If not:** Reopen.

## Verification
EOF
    git -C "$PROJECT_ROOT" add ".tasks/active/${id}-test.md" 2>/dev/null
    git -C "$PROJECT_ROOT" commit -qm "init $id" 2>/dev/null
}

@test "T-2163: full close nulls stored horizon in completed/ file" {
    _mk_full_close_task "T-9200"
    # Sanity: precondition — horizon: now in active/
    grep -q "^horizon: now\$" "$PROJECT_ROOT/.tasks/active/T-9200-test.md"

    # Run the close. Skip P-013 render-surface gate (test fixture has no web/ files).
    run env PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9200 \
        --status work-completed --skip-render-review "test fixture" 2>&1
    # Output may include warnings, but the file MUST have moved + been nulled
    [ -f "$PROJECT_ROOT/.tasks/completed/T-9200-test.md" ]
    [ ! -f "$PROJECT_ROOT/.tasks/active/T-9200-test.md" ]

    # Postcondition — stored horizon is now `null`
    grep -q "^horizon: null\$" "$PROJECT_ROOT/.tasks/completed/T-9200-test.md"
    ! grep -q "^horizon: now\$" "$PROJECT_ROOT/.tasks/completed/T-9200-test.md"
}

@test "T-2163: partial-complete keeps stored horizon (file stays in active/)" {
    _mk_partial_complete_task "T-9201"
    # Precondition
    grep -q "^horizon: now\$" "$PROJECT_ROOT/.tasks/active/T-9201-test.md"

    run env PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9201 \
        --status work-completed --skip-render-review "test fixture" 2>&1
    # Partial-complete: file stays in active/
    [ -f "$PROJECT_ROOT/.tasks/active/T-9201-test.md" ]
    [ ! -f "$PROJECT_ROOT/.tasks/completed/T-9201-test.md" ]

    # Horizon must be preserved — active/ render path needs it
    grep -q "^horizon: now\$" "$PROJECT_ROOT/.tasks/active/T-9201-test.md"
}

@test "T-2163: full close with horizon: next also nulls (not just 'now')" {
    _mk_full_close_task "T-9202"
    # Mutate horizon to next before closing
    sed -i 's/^horizon: now$/horizon: next/' "$PROJECT_ROOT/.tasks/active/T-9202-test.md"
    git -C "$PROJECT_ROOT" add -u 2>/dev/null
    git -C "$PROJECT_ROOT" commit -qm "set next" 2>/dev/null

    run env PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9202 \
        --status work-completed --skip-render-review "test fixture" 2>&1
    [ -f "$PROJECT_ROOT/.tasks/completed/T-9202-test.md" ]
    grep -q "^horizon: null\$" "$PROJECT_ROOT/.tasks/completed/T-9202-test.md"
}

@test "T-2163: post-close + migration rerun emits 0 changes (no drift)" {
    _mk_full_close_task "T-9203"
    run env PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9203 \
        --status work-completed --skip-render-review "test fixture" 2>&1
    # Run migration on the fixture corpus — should be 0 changes since
    # the write-side null already happened
    run env PROJECT_ROOT="$PROJECT_ROOT" \
        bash "$FRAMEWORK_ROOT/bin/migrate-horizon-null-completed.sh" 2>&1
    [[ "$output" == *"0 changes"* ]]
}
