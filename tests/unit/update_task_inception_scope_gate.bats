#!/usr/bin/env bats
# T-1984: inception GO-scope trace gate in update-task.sh.
#
# Covers (per spec):
#   (a) grandfathering: inception without inception_decisions: closes fine
#   (b) opt-in pass: all ships_in resolve → closes fine
#   (c) refusal classes: missing file / task not completed / missing deferred target
#   (d) deferred:T-YYYY accepted when target exists
#   (e) --skip-inception-scope-trace flag: accepted with rationale, bypass log written
#   (f) FW_SKIP_INCEPTION_SCOPE_TRACE=1 env-var: accepted, bypass log written
#   (g) build child with unlocks_inception_decision: referencing non-existent decision
#       is rejected by the PreToolUse hook (not the close gate — see check_inception_decisions_hook.bats)
#
# Note: (g) is in check_inception_decisions_hook.bats (PreToolUse). This file tests (a)-(f).

load ../test_helper

# ── helpers ───────────────────────────────────────────────────────────────────

make_inception_task() {
    local project_dir="$1"
    local task_id="${2:-T-998}"
    local decisions_yaml="${3:-}"  # Empty = no inception_decisions field
    local file="$project_dir/.tasks/active/${task_id}-test.md"

    local decisions_block=""
    if [ -n "$decisions_yaml" ]; then
        decisions_block="inception_decisions:
$decisions_yaml"
    fi

    cat > "$file" <<EOF
---
id: ${task_id}
name: "Test inception"
description: "A test inception task"
status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
date_finished: null
${decisions_block}
---

# ${task_id}: Test inception

## Context

Test context.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

## Verification

## Recommendation

**Recommendation:** GO

**Rationale:** Approved for test.

**Evidence:**
- Test evidence.

## Decision

**Decision**: GO

**Rationale**: Test decision.

**Date**: 2026-01-01T00:00:00Z
EOF
    echo "$file"
}

make_build_task() {
    local project_dir="$1"
    local task_id="${2:-T-997}"
    local unlocks_yaml="${3:-}"
    local file="$project_dir/.tasks/active/${task_id}-build.md"

    local unlocks_block=""
    if [ -n "$unlocks_yaml" ]; then
        unlocks_block="unlocks_inception_decision:
$unlocks_yaml"
    fi

    cat > "$file" <<EOF
---
id: ${task_id}
name: "Test build"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
date_finished: null
${unlocks_block}
---

# ${task_id}: Test build

## Context

Test.

## Acceptance Criteria

- [x] Test criterion

## Verification

echo "ok"
EOF
    echo "$file"
}

# ── (a) Grandfathering — no inception_decisions field ─────────────────────────

@test "T-1984(a): inception without inception_decisions closes fine" {
    PROJECT="$(create_test_project)"
    TASK="$(make_inception_task "$PROJECT" T-998)"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-998 --status work-completed
    [ "$status" -eq 0 ]
    # Gate message should NOT appear
    [[ "$output" != *"INCEPTION-SCOPE-TRACE"* ]]
}

# ── (b) All ships_in resolve ──────────────────────────────────────────────────

@test "T-1984(b): inception with all decisions resolved closes fine" {
    PROJECT="$(create_test_project)"
    mkdir -p "$PROJECT/.tasks/completed"

    # Create the shipped build child (T-XXX shape)
    cat > "$PROJECT/.tasks/completed/T-100-shipped.md" <<'EOF'
---
id: T-100
name: shipped
status: work-completed
workflow_type: build
---
EOF

    # Create a test file (file-path shape)
    mkdir -p "$PROJECT/lib"
    echo "# shipped code" > "$PROJECT/lib/shipped.py"

    DECISIONS="  - id: via-task
    text: 'Ships via completed task'
    ships_in: T-100
  - id: via-file
    text: 'Ships as a file'
    ships_in: lib/shipped.py"

    TASK="$(make_inception_task "$PROJECT" T-998 "$DECISIONS")"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-998 --status work-completed
    [ "$status" -eq 0 ]
    [[ "$output" == *"GO-scope trace"*"reachable"* ]] || [[ "$output" == *"OK_EMPTY"* ]] || [[ "$output" == *"all decisions"* ]]
}

# ── (c) Refusal classes ───────────────────────────────────────────────────────

@test "T-1984(c): missing file path blocks inception close" {
    PROJECT="$(create_test_project)"
    mkdir -p "$PROJECT/.tasks/completed"

    DECISIONS="  - id: missing-file
    text: 'File does not exist'
    ships_in: lib/nonexistent.py"

    TASK="$(make_inception_task "$PROJECT" T-998 "$DECISIONS")"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-998 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"INCEPTION-SCOPE-TRACE"* ]]
    [[ "$output" == *"missing-file"* ]]
}

@test "T-1984(c): task not in completed blocks inception close" {
    PROJECT="$(create_test_project)"
    mkdir -p "$PROJECT/.tasks/completed"
    # T-100 is only in active/, not completed/
    cat > "$PROJECT/.tasks/active/T-100-active.md" <<'EOF'
---
id: T-100
name: active task
status: started-work
workflow_type: build
---
EOF

    DECISIONS="  - id: unshipped-task
    text: 'Task not yet completed'
    ships_in: T-100"

    TASK="$(make_inception_task "$PROJECT" T-998 "$DECISIONS")"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-998 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"INCEPTION-SCOPE-TRACE"* ]]
    [[ "$output" == *"unshipped-task"* ]]
}

@test "T-1984(c): non-existent deferred target blocks inception close" {
    PROJECT="$(create_test_project)"
    mkdir -p "$PROJECT/.tasks/completed"

    DECISIONS="  - id: deferred-missing
    text: 'Deferred to missing task'
    ships_in: deferred:T-9999"

    TASK="$(make_inception_task "$PROJECT" T-998 "$DECISIONS")"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-998 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"INCEPTION-SCOPE-TRACE"* ]]
}

# ── (d) deferred:T-YYYY accepted when target exists ──────────────────────────

@test "T-1984(d): deferred:T-YYYY accepted when target task exists" {
    PROJECT="$(create_test_project)"
    mkdir -p "$PROJECT/.tasks/completed"

    # Create the defer target in active/
    cat > "$PROJECT/.tasks/active/T-200-future.md" <<'EOF'
---
id: T-200
name: future
status: captured
workflow_type: build
---
EOF

    DECISIONS="  - id: deferred-ok
    text: 'Deferred to future task'
    ships_in: deferred:T-200"

    TASK="$(make_inception_task "$PROJECT" T-998 "$DECISIONS")"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-998 --status work-completed
    [ "$status" -eq 0 ]
}

# ── (e) --skip-inception-scope-trace flag ─────────────────────────────────────

@test "T-1984(e): --skip-inception-scope-trace bypasses gate and writes bypass log" {
    PROJECT="$(create_test_project)"
    mkdir -p "$PROJECT/.tasks/completed"

    DECISIONS="  - id: will-fail
    text: 'This file does not exist'
    ships_in: lib/does-not-exist.py"

    TASK="$(make_inception_task "$PROJECT" T-998 "$DECISIONS")"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-998 \
        --status work-completed \
        --skip-inception-scope-trace "test rationale"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skip-inception-scope-trace"* ]] || [[ "$output" == *"bypass"* ]]
    # Bypass log written
    [ -f "$PROJECT/.context/working/.gate-bypass-log.yaml" ]
    out=$(cat "$PROJECT/.context/working/.gate-bypass-log.yaml")
    [[ "$out" == *"check_inception_scope_trace"* ]]
}

# ── (f) FW_SKIP_INCEPTION_SCOPE_TRACE=1 env-var ──────────────────────────────

@test "T-1984(f): FW_SKIP_INCEPTION_SCOPE_TRACE=1 bypasses gate and writes bypass log" {
    PROJECT="$(create_test_project)"
    mkdir -p "$PROJECT/.tasks/completed"

    DECISIONS="  - id: will-fail-env
    text: 'This file does not exist either'
    ships_in: lib/also-missing.py"

    TASK="$(make_inception_task "$PROJECT" T-998 "$DECISIONS")"
    FW_SKIP_INCEPTION_SCOPE_TRACE=1 PROJECT_ROOT="$PROJECT" \
        run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-998 --status work-completed
    [ "$status" -eq 0 ]
    [[ "$output" == *"FW_SKIP_INCEPTION_SCOPE_TRACE"* ]] || [[ "$output" == *"bypass"* ]]
    # Bypass log written
    [ -f "$PROJECT/.context/working/.gate-bypass-log.yaml" ]
    out=$(cat "$PROJECT/.context/working/.gate-bypass-log.yaml")
    [[ "$out" == *"FW_SKIP_INCEPTION_SCOPE_TRACE"* ]]
}

# ── block message quality ─────────────────────────────────────────────────────

@test "T-1984: block message names both override mechanisms" {
    PROJECT="$(create_test_project)"
    mkdir -p "$PROJECT/.tasks/completed"

    DECISIONS="  - id: d1
    text: 'Missing file'
    ships_in: lib/missing.py"

    TASK="$(make_inception_task "$PROJECT" T-998 "$DECISIONS")"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-998 --status work-completed
    [ "$status" -ne 0 ]
    # Must name the failing decision id
    [[ "$output" == *"d1"* ]]
    # Must list both bypass mechanisms
    [[ "$output" == *"--skip-inception-scope-trace"* ]]
    [[ "$output" == *"FW_SKIP_INCEPTION_SCOPE_TRACE"* ]]
}

# ── non-inception tasks not affected ─────────────────────────────────────────

@test "T-1984: build task without inception_decisions is not gated" {
    PROJECT="$(create_test_project)"
    TASK="$(create_test_task "$PROJECT" T-996 normal-build)"
    sed -i 's/- \[ \] Test criterion/- [x] Test criterion/' "$TASK"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-996 --status work-completed
    [ "$status" -eq 0 ]
    [[ "$output" != *"INCEPTION-SCOPE-TRACE"* ]]
}
