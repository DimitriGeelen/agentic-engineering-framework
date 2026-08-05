#!/usr/bin/env bats
# T-2300: re-close-path leg-gap regression test.
#
# T-2163 nulled horizon at close-time, but only INSIDE the move-conditional
# in agents/task-create/update-task.sh. The re-close path (file already in
# .tasks/completed/ with non-completed status — the L-461 stale-PC class)
# bypassed the move, and therefore the horizon-null mutation too.
#
# Result: 8 tasks in completed/ kept `horizon: now` and tripped CTL-030
# (T-2168/T-2180/T-2182/T-2196/T-2201/T-2203/T-2204/T-2248).
#
# T-2300 lifts the mutation out of the move-conditional. This test pins the
# re-close path so any future refactor that re-nests it trips the gate.

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

# Helper: write a task directly into .tasks/completed/ with started-work
# status and horizon: now — the stale-PC shape L-461 detects.
_mk_stale_pc_task() {
    local id="$1"
    cat > "$PROJECT_ROOT/.tasks/completed/${id}-test.md" <<EOF
---
id: $id
name: "stale-PC test task"
status: started-work
workflow_type: build
owner: claude-code
horizon: now
tags: []
created: 2026-06-01T00:00:00Z
last_update: 2026-06-01T00:00:00Z
---

# $id: stale-PC test task

## Acceptance Criteria

### Agent
- [x] Done

## Verification
EOF
    git -C "$PROJECT_ROOT" add ".tasks/completed/${id}-test.md" 2>/dev/null
    git -C "$PROJECT_ROOT" commit -qm "init $id stale-PC" 2>/dev/null
}

@test "T-2300: re-close of file already in completed/ nulls horizon" {
    _mk_stale_pc_task "T-9300"
    # Precondition — file is in completed/, status started-work, horizon now
    [ -f "$PROJECT_ROOT/.tasks/completed/T-9300-test.md" ]
    grep -q "^horizon: now\$" "$PROJECT_ROOT/.tasks/completed/T-9300-test.md"
    grep -q "^status: started-work\$" "$PROJECT_ROOT/.tasks/completed/T-9300-test.md"

    # Trigger the re-close: status flip from started-work → work-completed,
    # file does NOT need to move (already in completed/).
    run env PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9300 \
        --status work-completed --skip-render-review "test fixture" 2>&1

    # File stayed in completed/
    [ -f "$PROJECT_ROOT/.tasks/completed/T-9300-test.md" ]
    [ ! -f "$PROJECT_ROOT/.tasks/active/T-9300-test.md" ]

    # T-2300 invariant: horizon must be null on the re-close path too
    grep -q "^horizon: null\$" "$PROJECT_ROOT/.tasks/completed/T-9300-test.md"
    ! grep -q "^horizon: now\$" "$PROJECT_ROOT/.tasks/completed/T-9300-test.md"

    # Frontmatter still parses
    python3 -c "
import yaml, sys
text = open('$PROJECT_ROOT/.tasks/completed/T-9300-test.md').read()
fm = text.split('---', 2)[1]
d = yaml.safe_load(fm)
assert d.get('horizon') is None, f'horizon should be null, got: {d.get(\"horizon\")!r}'
assert d.get('status') == 'work-completed', f'status should be work-completed, got: {d.get(\"status\")!r}'
"
}

@test "T-2300: re-close with horizon: next also nulls" {
    _mk_stale_pc_task "T-9301"
    sed -i 's/^horizon: now$/horizon: next/' "$PROJECT_ROOT/.tasks/completed/T-9301-test.md"
    git -C "$PROJECT_ROOT" add -u 2>/dev/null
    git -C "$PROJECT_ROOT" commit -qm "set next" 2>/dev/null

    run env PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9301 \
        --status work-completed --skip-render-review "test fixture" 2>&1

    grep -q "^horizon: null\$" "$PROJECT_ROOT/.tasks/completed/T-9301-test.md"
}

@test "T-2300: original active→completed path still nulls (regression)" {
    # Pin that the lift didn't break the original T-2163 path
    cat > "$PROJECT_ROOT/.tasks/active/T-9302-test.md" <<EOF
---
id: T-9302
name: "active→completed test task"
status: started-work
workflow_type: build
owner: claude-code
horizon: now
tags: []
created: 2026-06-01T00:00:00Z
last_update: 2026-06-01T00:00:00Z
---

# T-9302: active→completed test task

## Acceptance Criteria

### Agent
- [x] Done

## Verification
EOF
    git -C "$PROJECT_ROOT" add ".tasks/active/T-9302-test.md" 2>/dev/null
    git -C "$PROJECT_ROOT" commit -qm "init T-9302" 2>/dev/null

    run env PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9302 \
        --status work-completed --skip-render-review "test fixture" 2>&1

    # Moved
    [ -f "$PROJECT_ROOT/.tasks/completed/T-9302-test.md" ]
    [ ! -f "$PROJECT_ROOT/.tasks/active/T-9302-test.md" ]
    # And nulled
    grep -q "^horizon: null\$" "$PROJECT_ROOT/.tasks/completed/T-9302-test.md"
}
