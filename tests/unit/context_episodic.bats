#!/usr/bin/env bats
# Unit tests for agents/context/lib/episodic.sh
#
# Tests git-mining helpers and do_generate_episodic():
#   - Error handling for missing task ID
#   - Error handling for missing task file
#   - Episodic file creation
#   - Git timeline mining
#   - AC parsing and outcome extraction

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
    mkdir -p "$CONTEXT_DIR/handovers" "$CONTEXT_DIR/audits"

    # Initialize git repo for mining
    git -C "$PROJECT_ROOT" init -q 2>/dev/null || true
    git -C "$PROJECT_ROOT" config user.email "test@test.com" 2>/dev/null || true
    git -C "$PROJECT_ROOT" config user.name "Test" 2>/dev/null || true
    touch "$PROJECT_ROOT/.gitkeep"
    git -C "$PROJECT_ROOT" add .gitkeep && git -C "$PROJECT_ROOT" commit -q -m "init" 2>/dev/null || true

    # Disable colors for test output matching
    RED='' GREEN='' YELLOW='' CYAN='' NC=''

    # Stub ensure_context_dirs
    ensure_context_dirs() { mkdir -p "$CONTEXT_DIR/working" "$CONTEXT_DIR/project" "$CONTEXT_DIR/episodic" "$CONTEXT_DIR/handovers" "$CONTEXT_DIR/audits"; }
    export -f ensure_context_dirs

    # Source dependencies
    source "$FRAMEWORK_ROOT/lib/compat.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Error handling ---

@test "episodic: errors on missing task ID" {
    run do_generate_episodic
    [ "$status" -eq 1 ]
    [[ "$output" == *"Task ID required"* ]]
}

@test "episodic: errors on nonexistent task" {
    run do_generate_episodic "T-999"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Task not found"* ]]
}

# --- Episodic file creation ---

@test "episodic: creates episodic YAML file" {
    cat > "$PROJECT_ROOT/.tasks/completed/T-100-test-task.md" << 'EOF'
---
id: T-100
name: "Test task"
description: >
  A test task for episodic generation
status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [test]
created: 2026-03-30T10:00:00Z
last_update: 2026-03-30T10:30:00Z
date_finished: 2026-03-30T10:30:00Z
---

# T-100: Test task

## Acceptance Criteria

### Agent
- [x] First criterion done
- [x] Second criterion done

## Decisions

## Updates

### 2026-03-30T10:00:00Z — task-created [task-create-agent]
- **Action:** Created task
EOF
    run do_generate_episodic "T-100"
    [ "$status" -eq 0 ]
    [ -f "$CONTEXT_DIR/episodic/T-100.yaml" ]
}

@test "episodic: output shows success message" {
    cat > "$PROJECT_ROOT/.tasks/completed/T-101-simple.md" << 'EOF'
---
id: T-101
name: "Simple task"
description: >
  Simple
status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-03-30T10:00:00Z
last_update: 2026-03-30T10:05:00Z
date_finished: 2026-03-30T10:05:00Z
---

# T-101: Simple task

## Acceptance Criteria

- [x] Done

## Updates
EOF
    run do_generate_episodic "T-101"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Episodic generated"* ]]
    [[ "$output" == *"T-101"* ]]
}

@test "episodic: file contains task metadata" {
    cat > "$PROJECT_ROOT/.tasks/completed/T-102-metadata.md" << 'EOF'
---
id: T-102
name: "Metadata check"
description: >
  Check metadata
status: work-completed
workflow_type: refactor
owner: agent
horizon: now
tags: [meta]
created: 2026-03-30T09:00:00Z
last_update: 2026-03-30T09:45:00Z
date_finished: 2026-03-30T09:45:00Z
---

# T-102: Metadata check

## Acceptance Criteria

- [x] AC1

## Decisions

### 2026-03-30 — chose approach
- **Chose:** Option A
- **Why:** Simpler

## Updates
EOF
    run do_generate_episodic "T-102"
    [ "$status" -eq 0 ]
    grep -q 'task_id: T-102' "$CONTEXT_DIR/episodic/T-102.yaml"
    grep -q 'task_name: "Metadata check"' "$CONTEXT_DIR/episodic/T-102.yaml"
    grep -q 'workflow_type: refactor' "$CONTEXT_DIR/episodic/T-102.yaml"
}

@test "episodic: parses acceptance criteria as outcomes" {
    cat > "$PROJECT_ROOT/.tasks/completed/T-103-ac.md" << 'EOF'
---
id: T-103
name: "AC parsing"
description: >
  Test AC parsing
status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-03-30T10:00:00Z
last_update: 2026-03-30T10:30:00Z
date_finished: 2026-03-30T10:30:00Z
---

# T-103: AC parsing

## Acceptance Criteria

### Agent
- [x] Tests pass
- [x] No regressions
- [ ] Docs updated

## Updates
EOF
    run do_generate_episodic "T-103"
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 AC checked"* ]]
}

@test "episodic: records decisions from task file" {
    cat > "$PROJECT_ROOT/.tasks/completed/T-104-decisions.md" << 'EOF'
---
id: T-104
name: "Decision recording"
description: >
  Test decision extraction
status: work-completed
workflow_type: inception
owner: agent
horizon: now
tags: []
created: 2026-03-30T10:00:00Z
last_update: 2026-03-30T10:30:00Z
date_finished: 2026-03-30T10:30:00Z
---

# T-104: Decision recording

## Acceptance Criteria

- [x] Research complete

## Decisions

### 2026-03-30 — Architecture approach
- **Chose:** Monolith
- **Why:** Simpler deployment
- **Rejected:** Microservices — premature complexity

## Updates
EOF
    run do_generate_episodic "T-104"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Decisions: recorded from task file"* ]]
    grep -q 'decisions:' "$CONTEXT_DIR/episodic/T-104.yaml"
}

# --- Git mining helpers ---

@test "episodic: mines git commits for timeline" {
    # Create task file
    cat > "$PROJECT_ROOT/.tasks/completed/T-105-git.md" << 'EOF'
---
id: T-105
name: "Git mining"
description: >
  Test git mining
status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-03-30T10:00:00Z
last_update: 2026-03-30T10:30:00Z
date_finished: 2026-03-30T10:30:00Z
---

# T-105: Git mining

## Acceptance Criteria

- [x] Done

## Updates
EOF
    # Create commits referencing the task
    echo "code1" > "$PROJECT_ROOT/feature.sh"
    git -C "$PROJECT_ROOT" add feature.sh
    git -C "$PROJECT_ROOT" commit -q -m "T-105: Add feature" 2>/dev/null || true

    run do_generate_episodic "T-105"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Commits: 1"* ]]
    grep -q 'commits: 1' "$CONTEXT_DIR/episodic/T-105.yaml"
}

@test "episodic: detects challenges from fix commits" {
    cat > "$PROJECT_ROOT/.tasks/completed/T-106-fix.md" << 'EOF'
---
id: T-106
name: "Fix detection"
description: >
  Test challenge detection
status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-03-30T10:00:00Z
last_update: 2026-03-30T10:30:00Z
date_finished: 2026-03-30T10:30:00Z
---

# T-106: Fix detection

## Acceptance Criteria

- [x] Fixed

## Updates
EOF
    echo "buggy" > "$PROJECT_ROOT/bugfix.sh"
    git -C "$PROJECT_ROOT" add bugfix.sh
    git -C "$PROJECT_ROOT" commit -q -m "T-106: Fix broken parser" 2>/dev/null || true

    run do_generate_episodic "T-106"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Challenges: 1 detected"* ]]
}

# --- Enrichment status ---

@test "episodic: auto-complete for mechanical tasks" {
    cat > "$PROJECT_ROOT/.tasks/completed/T-107-mech.md" << 'EOF'
---
id: T-107
name: "Mechanical task"
description: >
  No decisions needed
status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-03-30T10:00:00Z
last_update: 2026-03-30T10:05:00Z
date_finished: 2026-03-30T10:05:00Z
---

# T-107: Mechanical task

## Acceptance Criteria

- [x] Done

## Decisions

## Updates
EOF
    run do_generate_episodic "T-107"
    [ "$status" -eq 0 ]
    # AC checked but no decisions = auto-complete
    grep -q 'enrichment_status: auto-complete' "$CONTEXT_DIR/episodic/T-107.yaml"
}

@test "episodic: complete status when AC + decisions present" {
    cat > "$PROJECT_ROOT/.tasks/completed/T-108-full.md" << 'EOF'
---
id: T-108
name: "Full task"
description: >
  Has both AC and decisions
status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-03-30T10:00:00Z
last_update: 2026-03-30T10:30:00Z
date_finished: 2026-03-30T10:30:00Z
---

# T-108: Full task

## Acceptance Criteria

- [x] Feature works

## Decisions

### 2026-03-30 — approach
- **Chose:** Simple
- **Why:** Fast

## Updates
EOF
    run do_generate_episodic "T-108"
    [ "$status" -eq 0 ]
    grep -q 'enrichment_status: complete' "$CONTEXT_DIR/episodic/T-108.yaml"
}
