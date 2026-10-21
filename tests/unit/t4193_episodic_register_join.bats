#!/usr/bin/env bats
# T-4193 (832 OBS-458, their T-1150): the episodic generator derived
# has_decisions only from the task file's `## Decisions` section and never read
# .context/project/decisions.yaml. A decision recorded through the register
# (`fw context add-decision --task T-XXX`) was therefore missing from the
# episodic, which then stated "no decisions to record". The fix joins the
# register by task id and, where the register holds an entry the task file
# lacks, says so instead of concluding absence.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$CONTEXT_DIR/working" "$CONTEXT_DIR/project" "$CONTEXT_DIR/episodic"
    git -C "$PROJECT_ROOT" init -q 2>/dev/null || true
    git -C "$PROJECT_ROOT" config user.email "test@test.com"
    git -C "$PROJECT_ROOT" config user.name "Test"
    touch "$PROJECT_ROOT/.gitkeep"
    git -C "$PROJECT_ROOT" add .gitkeep && git -C "$PROJECT_ROOT" commit -q -m "init"
    RED='' GREEN='' YELLOW='' CYAN='' NC=''
    ensure_context_dirs() { mkdir -p "$CONTEXT_DIR/episodic"; }
    fw_post_write_index() { :; }
    source "$FRAMEWORK_ROOT/lib/compat.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"

    cat > "$CONTEXT_DIR/project/decisions.yaml" << 'EOF'
decisions:

  - id: D-001
    decision: "Join the register by task id, it's the source of truth"
    scope: project
    date: 2026-10-01
    task: T-200
    rationale: "Recorded via fw context add-decision only"

  - id: D-002
    decision: "Decision for an unrelated task"
    scope: project
    date: 2026-10-01
    task: T-999
    rationale: "Must not leak into T-200"

  - id: D-003
    decision: "Keep the task-file entry authoritative"
    scope: project
    date: 2026-10-02
    task: T-201
    rationale: "Auto-captured from task file on completion"
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_task() {  # $1 id, $2 decisions body
    cat > "$PROJECT_ROOT/.tasks/completed/$1-t.md" << EOF
---
id: $1
name: "Task $1"
description: >
  test
status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-10-01T10:00:00Z
last_update: 2026-10-01T10:30:00Z
---

## Acceptance Criteria

- [x] done

## Decisions

$2

## Updates
EOF
}

_load() {  # python one-shot over the episodic: prints the expression
    python3 -c "import yaml,sys; d=yaml.safe_load(open(sys.argv[1])); print($2)" \
        "$CONTEXT_DIR/episodic/$1.yaml"
}

@test "register-only decision appears in the episodic, with its source" {
    _task T-200 ""
    run do_generate_episodic T-200
    [ "$status" -eq 0 ]
    run _load T-200 "len(d['decisions'] or [])"
    [ "$output" = "1" ]
    run _load T-200 "d['decisions'][0]['source'] + '|' + d['decisions'][0]['id']"
    [ "$output" = "register|D-001" ]
    run _load T-200 "d['decisions'][0]['chose']"
    [ "$output" = "Join the register by task id, it's the source of truth" ]
}

@test "register-only decision: episodic says so instead of concluding absence" {
    _task T-200 ""
    do_generate_episodic T-200 >/dev/null
    local f="$CONTEXT_DIR/episodic/T-200.yaml"
    ! grep -q "No decisions recorded" "$f" || false
    ! grep -q "no decisions to record" "$f" || false
    grep -q "decisions.yaml" "$f"
    grep -q "absent from the task file" "$f"
    run _load T-200 "d['enrichment_status']"
    [ "$output" = "complete" ]
}

@test "register entries for other tasks do not leak" {
    _task T-300 ""
    do_generate_episodic T-300 >/dev/null
    run _load T-300 "d['decisions']"
    [ "$output" = "None" ]
    grep -q "No decisions recorded" "$CONTEXT_DIR/episodic/T-300.yaml"
}

@test "register entry already in the task file is not duplicated" {
    _task T-201 "### 2026-10-02 — authority
- **Chose:** Keep the task-file entry authoritative
- **Why:** the task file holds the full rationale"
    do_generate_episodic T-201 >/dev/null
    run _load T-201 "len(d['decisions'])"
    [ "$output" = "1" ]
    run _load T-201 "d['decisions'][0].get('source', 'task-file')"
    [ "$output" = "task-file" ]
    ! grep -q "absent from the task file" "$CONTEXT_DIR/episodic/T-201.yaml" || false
}

@test "task-file decision plus a different register entry: both emitted" {
    _task T-200 "### 2026-10-02 — other
- **Chose:** Something recorded in the task file only"
    do_generate_episodic T-200 >/dev/null
    run _load T-200 "[e.get('source', 'task-file') for e in d['decisions']]"
    [ "$output" = "['task-file', 'register']" ]
}

@test "missing register file: generator still works, no register entries" {
    rm -f "$CONTEXT_DIR/project/decisions.yaml"
    _task T-200 ""
    run do_generate_episodic T-200
    [ "$status" -eq 0 ]
    run _load T-200 "d['decisions']"
    [ "$output" = "None" ]
}
