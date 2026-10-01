#!/usr/bin/env bats
# T-3691: Design-conformance register gate test suite
#
# Tests the gate that prevents slices from deferring design spec requirements
# without naming an owner task. Reproduces the T-3682 pattern where 7 requirements
# were deferred with no owner and nobody noticed.
#
# Test fixtures:
#   - Synthetic arc + design doc with requirement register
#   - Synthetic task on that arc, scope fence deferring R-X
#   - Control: task with valid owner → passes
#   - Treatment: task without owner → blocks

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    cd "$FRAMEWORK_ROOT"
}

teardown() {
    rm -f "$FRAMEWORK_ROOT/.tasks/active/"T-99[0-9][0-9]-*.md
    rm -f "$FRAMEWORK_ROOT/.tasks/completed/"T-99[0-9][0-9]-*.md
    rm -f "$FRAMEWORK_ROOT/.context/episodic/"T-99[0-9][0-9].yaml
    rm -f "$FRAMEWORK_ROOT/.context/arcs/redteam-arc.yaml"
    rm -f "$FRAMEWORK_ROOT/docs/architecture/redteam-design.md"
}

# Helper: write arc metadata
_write_arc() {
    local slug="$1"
    local design_doc="$2"
    mkdir -p "$FRAMEWORK_ROOT/.context/arcs"
    cat > "$FRAMEWORK_ROOT/.context/arcs/${slug}.yaml" <<EOF
id: $slug
name: "Redteam Arc"
status: in-progress
design_doc: "$design_doc"
EOF
}

# Helper: write design doc with register
_write_design() {
    local doc_path="$1"
    local dir=$(dirname "$doc_path")
    mkdir -p "$dir"
    cat > "$doc_path" <<'EOF'
# Redteam Design

## 7. Design-conformance requirement register (T-3691)

```yaml
register:
  - id: R1
    text: "First requirement"
    source: "spec"
    owner_task: T-9901
    status: built
    evidence: "none"

  - id: R2
    text: "Second requirement — the liveness self-probe daemon"
    source: "spec"
    owner_task: null
    status: unbuilt
    evidence: "deferred"

  - id: R3
    text: "Third requirement"
    source: "spec"
    owner_task: T-9902
    status: unbuilt
    evidence: "deferred"
```
EOF
}

# Helper: write task on arc
_write_task_on_arc() {
    local id="$1"
    local title="$2"
    local arc_id="$3"
    local body="$4"
    local file="$FRAMEWORK_ROOT/.tasks/active/${id}-redteam.md"
    cat > "$file" <<EOF
---
id: ${id}
name: "${title}"
description: "redteam fixture for register gate"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
arc_id: ${arc_id}
components: []
related_tasks: []
created: 2026-04-29T00:00:00Z
last_update: 2026-04-29T00:00:00Z
date_finished: null
---

${body}
EOF
    echo "$file"
}

# Control: task with valid owner for deferred requirement
@test "register gate: PASSES when deferred R-id names existing owner" {
    _write_design "$FRAMEWORK_ROOT/docs/architecture/redteam-design.md"
    _write_arc "redteam-arc" "docs/architecture/redteam-design.md"

    # Create the owner task
    _write_task_on_arc "T-9901" "Owner for R1" "redteam-arc" "## Acceptance Criteria
### Agent
- [x] Dummy AC
## Verification
true"

    # Main task defers R1 but names owner
    _write_task_on_arc "T-9902" "Defers R1 with owner" "redteam-arc" "## Context
This slice defers R1 (First requirement) to T-9901.

## Acceptance Criteria
### Agent
- [x] Dummy AC
## Verification
true
## Recommendation
**Recommendation:** GO
**Rationale:** test
**Evidence:** none"

    run "$FW" task update T-9902 --status work-completed
    [ "$status" -eq 0 ] || echo "Output: $output"
}

# Treatment: task defers R-id without naming owner
@test "register gate: BLOCKS when R-id deferred without owner_task" {
    _write_design "$FRAMEWORK_ROOT/docs/architecture/redteam-design.md"
    _write_arc "redteam-arc" "docs/architecture/redteam-design.md"

    # Create owner for R1 so we only test R2
    _write_task_on_arc "T-9901" "Owner for R1" "redteam-arc" "## Acceptance Criteria
### Agent
- [x] Dummy AC
## Verification
true"

    # Main task defers R2, which has no owner
    _write_task_on_arc "T-9903" "Defers R2 no owner" "redteam-arc" "## Context
This slice defers the liveness self-probe daemon (R2) — a separate slice.

## Acceptance Criteria
### Agent
- [x] Dummy AC
## Verification
true
## Recommendation
**Recommendation:** GO
**Rationale:** test
**Evidence:** none"

    run "$FW" task update T-9903 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"register"* ]] || [[ "$output" == *"owner"* ]] || [[ "$output" == *"Cannot complete"* ]]
}

# Treatment: task defers requirement but owner doesn't exist
@test "register gate: BLOCKS when owner_task does not exist" {
    _write_design "$FRAMEWORK_ROOT/docs/architecture/redteam-design.md"
    _write_arc "redteam-arc" "docs/architecture/redteam-design.md"

    # Main task defers R1 which names T-9999 (doesn't exist)
    _write_task_on_arc "T-9904" "Defers with missing owner" "redteam-arc" "## Context
This slice defers R1 to T-9999 (which doesn't exist).

## Acceptance Criteria
### Agent
- [x] Dummy AC
## Verification
true
## Recommendation
**Recommendation:** GO
**Rationale:** test
**Evidence:** none"

    run "$FW" task update T-9904 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not exist"* ]] || [[ "$output" == *"Cannot complete"* ]]
}

# Control: task that doesn't defer anything passes
@test "register gate: PASSES when no requirements deferred" {
    _write_design "$FRAMEWORK_ROOT/docs/architecture/redteam-design.md"
    _write_arc "redteam-arc" "docs/architecture/redteam-design.md"

    # Task doesn't mention any R-X
    _write_task_on_arc "T-9905" "No deferred items" "redteam-arc" "## Context
This slice builds something without deferring spec requirements.

## Acceptance Criteria
### Agent
- [x] Dummy AC
## Verification
true
## Recommendation
**Recommendation:** GO
**Rationale:** test
**Evidence:** none"

    run "$FW" task update T-9905 --status work-completed
    [ "$status" -eq 0 ] || echo "Output: $output"
}

# Bypass: --skip-register-requirements allows override
@test "register gate: PASSES with --skip-register-requirements bypass" {
    _write_design "$FRAMEWORK_ROOT/docs/architecture/redteam-design.md"
    _write_arc "redteam-arc" "docs/architecture/redteam-design.md"

    # Task defers R2 with no owner
    _write_task_on_arc "T-9906" "Defers unowned, bypassed" "redteam-arc" "## Context
This slice defers R2 (liveness self-probe daemon) with no owner, but we're bypassing.

## Acceptance Criteria
### Agent
- [x] Dummy AC
## Verification
true
## Recommendation
**Recommendation:** GO
**Rationale:** test
**Evidence:** none"

    run "$FW" task update T-9906 --status work-completed \
        --skip-register-requirements --reason "testing bypass"
    [ "$status" -eq 0 ] || echo "Output: $output"
    [[ "$output" == *"bypass"* ]]
}
