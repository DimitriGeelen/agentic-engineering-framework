#!/usr/bin/env bats
# T-1374 (G-054 root cause): update-task.sh aborted silently at the components
# lookup pipeline because `grep` returned exit 1 on no-match, and under
# `set -euo pipefail` the command-substitution assignment carried that exit
# code, triggering the EXIT trap (keylock_release) before the Episodic block
# at line 843.
#
# Fix: `|| true` appended to the grep pipeline.
#
# This test pins the fix by:
#   1. Creating a task
#   2. Seeding a git commit that touches a NON-fabric-carded file (so grep
#      misses every path in ALL_PATHS — the exact condition that triggered
#      the abort)
#   3. Running `update-task.sh --status work-completed`
#   4. Asserting the episodic file IS generated (proves the script reached
#      the Episodic block after the components lookup)

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJECT="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJECT/.tasks/active" \
             "$PROJECT/.tasks/completed" \
             "$PROJECT/.context/episodic" \
             "$PROJECT/.context/working" \
             "$PROJECT/.context/project" \
             "$PROJECT/.fabric/components"
    touch "$PROJECT/.framework.yaml"

    # Seed a fabric card with a location that will NOT match the commit's files
    cat > "$PROJECT/.fabric/components/unrelated.yaml" <<'EOF'
id: unrelated/file.sh
name: unrelated
location: unrelated/file.sh
EOF

    # Seed a task
    cat > "$PROJECT/.tasks/active/T-9002-repro.md" <<'EOF'
---
id: T-9002
name: "G-054 root cause repro"
description: "repro"
status: started-work
workflow_type: build
horizon: now
owner: agent
tags: []
components: []
created: 2026-04-20T22:00:00Z
last_update: 2026-04-20T22:00:00Z
---

# T-9002: G-054 root cause repro

## Acceptance Criteria

### Agent
- [x] test

## Updates

### 2026-04-20T22:00:00Z — task-created [task-create-agent]
EOF

    # Init git and commit touching ONLY a file with no matching fabric card
    # (this is the exact condition that caused G-054 aborts pre-fix)
    cd "$PROJECT"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    echo "noise" > .gitignore.test
    git add .tasks/active/T-9002-repro.md .gitignore.test .fabric/components/unrelated.yaml .framework.yaml
    git commit -q -m "T-9002: seed commit (no fabric-carded paths)"
    cd - >/dev/null

    export PROJECT_ROOT="$PROJECT"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "update-task.sh completes + episodic-gen runs when commit paths miss all fabric cards (regression T-1374/G-054)" {
    cd "$PROJECT"
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9002 --status work-completed
    [ "$status" -eq 0 ]

    # Task moved to completed/
    [ ! -f "$PROJECT/.tasks/active/T-9002-repro.md" ]
    [ -f "$PROJECT/.tasks/completed/T-9002-repro.md" ]

    # Critical assertion: episodic WAS generated — proves script reached
    # the Episodic block (pre-fix, this would be missing because the
    # components-lookup pipeline aborted the script first)
    [ -f "$PROJECT/.context/episodic/T-9002.yaml" ]

    # The auto-trigger banner must have printed (pre-fix it never did)
    echo "$output" | grep -q "Auto-trigger: Episodic Generation"
}
