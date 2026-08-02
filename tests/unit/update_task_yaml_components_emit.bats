#!/usr/bin/env bats
# T-1469: update-task.sh auto-populate components path used a sed line replace
# that left orphan `  - item` continuation lines from block-style components,
# producing invalid YAML. This caused Watchtower's scanner to crash on parse,
# rendering empty queues for the human (T-1468 cleanup).
#
# This test pins the fix by:
#   1. Seeding a task with block-style `components:\n  - X\n  - Y\n`
#   2. Seeding a fabric card whose location matches a file the commit touched
#   3. Running `update-task.sh --status work-completed` (triggers the auto-pop)
#   4. Asserting the resulting YAML parses cleanly AND has no orphan `  - ` lines

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJECT="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJECT/.tasks/active" \
             "$PROJECT/.tasks/completed" \
             "$PROJECT/.context/episodic" \
             "$PROJECT/.context/working" \
             "$PROJECT/.context/project" \
             "$PROJECT/.fabric/components" \
             "$PROJECT/src"
    touch "$PROJECT/.framework.yaml"

    # Seed fabric card whose `location` matches src/widget.sh (a file we'll touch)
    cat > "$PROJECT/.fabric/components/widget.yaml" <<'EOF'
id: C-WIDGET
name: widget
location: src/widget.sh
EOF

    # Seed task with BLOCK-STYLE components (the exact pattern that broke)
    cat > "$PROJECT/.tasks/active/T-9469-block.md" <<'EOF'
---
id: T-9469
name: "Block-style components repro"
description: "repro"
status: started-work
workflow_type: build
horizon: now
owner: agent
tags: [bug]
components:
  - src/widget.sh
  - src/legacy.sh
related_tasks: []
created: 2026-04-25T20:00:00Z
last_update: 2026-04-25T20:00:00Z
---

# T-9469: Block-style components repro

## Acceptance Criteria

### Agent
- [x] test

## RCA

**Symptom:** fixture placeholder — this task is closed by the test below.
**Root cause:** n/a, fixture.
**Why structurally allowed:** n/a, fixture.
**Prevention:** n/a, fixture.

## Updates

### 2026-04-25T20:00:00Z — task-created [task-create-agent]
EOF

    cd "$PROJECT"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    # Initial commit (no T-XXX) so the task commit is not the root — auto-populate
    # uses `git diff ${c}~1 c` which fails on root commits.
    echo "init" > README.md
    git add README.md .framework.yaml .fabric/components/widget.yaml .tasks/active/T-9469-block.md
    git commit -q -m "init"
    echo "echo widget" > src/widget.sh
    git add src/widget.sh
    git commit -q -m "T-9469: seed widget"
    cd - >/dev/null

    export PROJECT_ROOT="$PROJECT"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "update-task.sh emits valid flow-style components, removes block-style continuation lines (T-1469)" {
    cd "$PROJECT"
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9469 --status work-completed
    [ "$status" -eq 0 ]

    TASK_FILE="$PROJECT/.tasks/completed/T-9469-block.md"
    [ -f "$TASK_FILE" ]

    # The frontmatter must parse as valid YAML (this was the actual user-visible failure)
    run python3 -c "
import yaml, sys
content = open('$TASK_FILE').read()
fm = content.split('---', 2)[1]
yaml.safe_load(fm)
print('OK')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]

    # No orphan block-style continuation lines after frontmatter components rewrite
    # (this is the exact bug — `  - src/widget.sh` left dangling after `components: [...]`)
    run python3 -c "
import re, sys
content = open('$TASK_FILE').read()
fm = content.split('---', 2)[1]
# After 'components: [...]' line there must be no orphan '  - ' line
m = re.search(r'^components:[^\n]*\n([ \t]+-[^\n]*\n)+', fm, re.MULTILINE)
if m:
    print('FAIL: orphan continuation lines after components:')
    print(m.group(0))
    sys.exit(1)
print('OK')
"
    [ "$status" -eq 0 ]

    # And components must now be flow-style with the resolved id
    grep -q '^components: \[.*C-WIDGET.*\]$' "$TASK_FILE"
}

@test "update-task.sh preserves flow-style components (no regression on already-flow files)" {
    # Re-seed task with flow-style components
    cat > "$PROJECT/.tasks/active/T-9470-flow.md" <<'EOF'
---
id: T-9470
name: "Flow-style components"
description: "no regression"
status: started-work
workflow_type: build
horizon: now
owner: agent
tags: [bug]
components: [src/widget.sh]
related_tasks: []
created: 2026-04-25T20:00:00Z
last_update: 2026-04-25T20:00:00Z
---

# T-9470

## Acceptance Criteria

### Agent
- [x] test

## RCA

**Symptom:** fixture placeholder — this task is closed by the test below.
**Root cause:** n/a, fixture.
**Why structurally allowed:** n/a, fixture.
**Prevention:** n/a, fixture.

## Updates

### 2026-04-25T20:00:00Z — task-created [task-create-agent]
EOF
    cd "$PROJECT"
    # Seed src/widget.sh again under T-9470 commit so auto-populate has a path to resolve
    echo "echo flow" >> src/widget.sh
    git add .tasks/active/T-9470-flow.md src/widget.sh
    git commit -q -m "T-9470: seed flow"

    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9470 --status work-completed
    [ "$status" -eq 0 ]

    TASK_FILE="$PROJECT/.tasks/completed/T-9470-flow.md"
    grep -q '^components: \[.*C-WIDGET.*\]$' "$TASK_FILE"
    run python3 -c "
import yaml; yaml.safe_load(open('$TASK_FILE').read().split('---', 2)[1]); print('OK')
"
    [ "$status" -eq 0 ]
}
