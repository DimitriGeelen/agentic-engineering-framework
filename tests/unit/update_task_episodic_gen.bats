#!/usr/bin/env bats
# T-1368: Regression test for episodic auto-gen silent failure.
#
# Four tasks in one session (T-1363, T-1364, T-1366, T-1367) transitioned to
# work-completed via update-task.sh (evidenced by date_finished set and the
# [task-update-agent] Updates entry), yet no episodic was generated. Sandbox
# reproduction with the exact real task files DOES generate the episodic, so
# the code path works. This test pins the happy path so any regression in
# auto-gen (code-side) surfaces immediately.
#
# Does NOT reproduce the real-world silent failure (environmental, unknown
# trigger) — tracked separately in concerns.yaml.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJECT="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJECT/.tasks/active" \
             "$PROJECT/.tasks/completed" \
             "$PROJECT/.context/episodic" \
             "$PROJECT/.context/working" \
             "$PROJECT/.context/project"
    touch "$PROJECT/.framework.yaml"

    cat > "$PROJECT/.tasks/active/T-9001-repro.md" <<'EOF'
---
id: T-9001
name: "Auto-gen regression task"
description: "test"
status: started-work
workflow_type: build
horizon: now
owner: agent
created: 2026-04-20T22:00:00Z
last_update: 2026-04-20T22:00:00Z
tags: []
---

# T-9001: Auto-gen regression task

## Acceptance Criteria

### Agent
- [x] Done

## RCA

**Symptom:** fixture placeholder — this task is closed by the test below.
**Root cause:** n/a, fixture.
**Why structurally allowed:** n/a, fixture.
**Prevention:** n/a, fixture.

## Updates

### 2026-04-20T22:00:00Z — task-created [task-create-agent]
EOF

    export PROJECT_ROOT="$PROJECT"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "update-task.sh work-completed auto-generates episodic summary" {
    cd "$PROJECT"
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9001 --status work-completed
    [ "$status" -eq 0 ]

    # Task moved to completed/
    [ ! -f "$PROJECT/.tasks/active/T-9001-repro.md" ]
    [ -f "$PROJECT/.tasks/completed/T-9001-repro.md" ]

    # Episodic auto-generated
    [ -f "$PROJECT/.context/episodic/T-9001.yaml" ]
}

@test "T-1860: episodic-gen log lands at per-task path .context/working/episodic-gen/<TASK>.log" {
    # Use a non-bug-class fixture (no fix/bug/error/regression in the title) so
    # the T-1550 RCA gate doesn't refuse — orthogonal to what this test pins.
    cat > "$PROJECT/.tasks/active/T-9002-feature.md" <<'EOF'
---
id: T-9002
name: "Episodic-gen log path canary"
description: "test"
status: started-work
workflow_type: build
horizon: now
owner: agent
created: 2026-04-20T22:00:00Z
last_update: 2026-04-20T22:00:00Z
tags: []
---

# T-9002: Episodic-gen log path canary

## Acceptance Criteria

### Agent
- [x] Done

## Updates

### 2026-04-20T22:00:00Z — task-created [task-create-agent]
EOF
    cd "$PROJECT"
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9002 --status work-completed
    [ "$status" -eq 0 ]
    # New per-task path exists; old single rolling log does NOT
    [ -f "$PROJECT/.context/working/episodic-gen/T-9002.log" ]
    [ ! -f "$PROJECT/.context/working/.last-episodic-gen.log" ]
    # Log contains a recognizable header
    grep -q "^=== episodic-gen invocation:" "$PROJECT/.context/working/episodic-gen/T-9002.log"
    grep -q "^task_id: T-9002" "$PROJECT/.context/working/episodic-gen/T-9002.log"
}

@test "T-1860: source-of-truth — update-task.sh writes per-task log with append (no single-truncate regression)" {
    # Pin the structural fix: agents/task-create/update-task.sh must use a per-task
    # EPISODIC_LOG path AND append (>>) — not single rolling log with truncate (>).
    src="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    grep -q 'EPISODIC_LOG=.*working/episodic-gen/\$TASK_ID\.log' "$src"
    # Header write must use >> (append), not > (truncate). Match the exact closing
    # brace from the header block.
    grep -E 'echo "--- context\.sh output ---"' -A 1 "$src" | grep -q '>>\s*"\$EPISODIC_LOG"'
    # And the older single rolling path must not reappear
    ! grep -q '\.last-episodic-gen\.log' "$src"
}

@test "update-task.sh prints silent-failure warning when episodic not created" {
    # Guard rail on T-1169's detection: if gen ever breaks silently, the warning
    # must appear. Force the failure by making context.sh non-executable.
    chmod -x "$FRAMEWORK_ROOT/agents/context/context.sh" 2>/dev/null || skip "cannot chmod context.sh (read-only FS?)"

    cd "$PROJECT"
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9001 --status work-completed

    # Restore permissions regardless of outcome
    chmod +x "$FRAMEWORK_ROOT/agents/context/context.sh"

    # Completion still succeeds (|| true in update-task.sh)
    [ "$status" -eq 0 ]

    # Either "not created" warning OR "Context agent not found" message appears
    echo "$output" | grep -qiE "not created|context agent not found|run manually"
}
