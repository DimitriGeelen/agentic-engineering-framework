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
#
# T-4580: fixture Verification lines must be real checks, not `true` — since T-4197
# the reviewer's severe tautology finding refuses the close before the register
# gate runs, which turned every PASSES case red for the wrong reason.
#
# T-4671: every case runs in a throwaway `git init`'d PROJECT_ROOT. This file used
# to cd into the framework repo and write its T-99xx fixtures there; the closes
# that succeed are staged by update-task.sh's T-4094 postcondition, so they landed
# in the REAL index and an unrelated commit (a2e53a22a) picked them up. The live
# repo guard now fails any case that changes the real repo's status or index.

load ../test_helper
load ../live_repo_guard

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    # Scoped to the namespace these fixtures write: a whole-repo snapshot also trips
    # on other workers editing the shared checkout mid-run (T-4671, first run).
    live_repo_guard_begin "$FRAMEWORK_ROOT" \
        ':(glob).tasks/**/T-99[0-9][0-9]-*' ':(glob).context/episodic/T-99[0-9][0-9].yaml' \
        '.context/arcs/redteam-arc.yaml' 'docs/architecture/redteam-design.md'
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    # bin/fw prefers CLAUDE_PROJECT_DIR over PROJECT_ROOT; inside a Claude session it
    # names the live repo, which is exactly where these fixtures must not go.
    unset CLAUDE_PROJECT_DIR FW_SKIP_REGISTER_REQUIREMENTS
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.tasks/templates" "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/episodic" "$PROJECT_ROOT/.context/arcs" \
             "$PROJECT_ROOT/docs/architecture"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" \
       "$PROJECT_ROOT/.tasks/templates/default.md" 2>/dev/null || \
       echo "# template" > "$PROJECT_ROOT/.tasks/templates/default.md"
    git -C "$PROJECT_ROOT" init -q
    git -C "$PROJECT_ROOT" config user.email t@t
    git -C "$PROJECT_ROOT" config user.name t
    git -C "$PROJECT_ROOT" add -A
    git -C "$PROJECT_ROOT" commit -qm "fixture base" --no-verify
    cd "$PROJECT_ROOT"
}

teardown() {
    cd /
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    live_repo_guard_end
}

# Helper: write arc metadata
_write_arc() {
    local slug="$1"
    local design_doc="$2"
    cat > "$PROJECT_ROOT/.context/arcs/${slug}.yaml" <<EOF
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
    # T-3694: was T-9902 — the control's own closing task owning an unbuilt row,
    # which the close gate now refuses (the T-3561 shape). Owned elsewhere instead.
    owner_task: T-9910
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
    local file="$PROJECT_ROOT/.tasks/active/${id}-redteam.md"
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
    _write_design "$PROJECT_ROOT/docs/architecture/redteam-design.md"
    _write_arc "redteam-arc" "docs/architecture/redteam-design.md"

    # Create the owner task
    _write_task_on_arc "T-9901" "Owner for R1" "redteam-arc" "## Acceptance Criteria
### Agent
- [x] Dummy AC
## Verification
test -f .framework.yaml"

    # Main task defers R1 but names owner
    _write_task_on_arc "T-9902" "Defers R1 with owner" "redteam-arc" "## Context
This slice defers R1 (First requirement) to T-9901.

## Acceptance Criteria
### Agent
- [x] Dummy AC
## Verification
test -f .framework.yaml
## Recommendation
**Recommendation:** GO
**Rationale:** test
**Evidence:** none"

    run "$FW" task update T-9902 --status work-completed
    [ "$status" -eq 0 ]  # T-3694: was `|| echo`, which can never fail
}

# Treatment: task defers R-id without naming owner
@test "register gate: BLOCKS when R-id deferred without owner_task" {
    _write_design "$PROJECT_ROOT/docs/architecture/redteam-design.md"
    _write_arc "redteam-arc" "docs/architecture/redteam-design.md"

    # Create owner for R1 so we only test R2
    _write_task_on_arc "T-9901" "Owner for R1" "redteam-arc" "## Acceptance Criteria
### Agent
- [x] Dummy AC
## Verification
test -f .framework.yaml"

    # Main task defers R2, which has no owner
    _write_task_on_arc "T-9903" "Defers R2 no owner" "redteam-arc" "## Context
This slice defers the liveness self-probe daemon (R2) — a separate slice.

## Acceptance Criteria
### Agent
- [x] Dummy AC
## Verification
test -f .framework.yaml
## Recommendation
**Recommendation:** GO
**Rationale:** test
**Evidence:** none"

    run "$FW" task update T-9903 --status work-completed
    [ "$status" -ne 0 ]
    # T-3694: was an any-of on "register"/"owner"/"Cannot complete", which any
    # unrelated close failure satisfies. Pin the register gate's own finding.
    [[ "$output" == *"R2: deferred here but has no owner_task"* ]]
}

# Treatment: task defers requirement but owner doesn't exist
@test "register gate: BLOCKS when owner_task does not exist" {
    _write_design "$PROJECT_ROOT/docs/architecture/redteam-design.md"
    _write_arc "redteam-arc" "docs/architecture/redteam-design.md"

    # Main task defers R1, whose register owner T-9901 is not created in this test.
    # T-3694: the prose used to name T-9999, which the register gate never reads —
    # the row's owner_task is what is checked, so the fixture now says so.
    _write_task_on_arc "T-9904" "Defers with missing owner" "redteam-arc" "## Context
This slice defers R1 (its register owner T-9901 does not exist here).

## Acceptance Criteria
### Agent
- [x] Dummy AC
## Verification
test -f .framework.yaml
## Recommendation
**Recommendation:** GO
**Rationale:** test
**Evidence:** none"

    run "$FW" task update T-9904 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"R1: deferred to owner_task T-9901, which does not exist"* ]]
}

# Control: task that doesn't defer anything passes
@test "register gate: PASSES when no requirements deferred" {
    _write_design "$PROJECT_ROOT/docs/architecture/redteam-design.md"
    _write_arc "redteam-arc" "docs/architecture/redteam-design.md"

    # Task doesn't mention any R-X
    _write_task_on_arc "T-9905" "No deferred items" "redteam-arc" "## Context
This slice builds something without deferring spec requirements.

## Acceptance Criteria
### Agent
- [x] Dummy AC
## Verification
test -f .framework.yaml
## Recommendation
**Recommendation:** GO
**Rationale:** test
**Evidence:** none"

    run "$FW" task update T-9905 --status work-completed
    [ "$status" -eq 0 ]  # T-3694: was `|| echo`, which can never fail
}

# Bypass: --skip-register-requirements allows override
@test "register gate: PASSES with --skip-register-requirements bypass" {
    _write_design "$PROJECT_ROOT/docs/architecture/redteam-design.md"
    _write_arc "redteam-arc" "docs/architecture/redteam-design.md"

    # Task defers R2 with no owner
    _write_task_on_arc "T-9906" "Defers unowned, bypassed" "redteam-arc" "## Context
This slice defers R2 (liveness self-probe daemon) with no owner, but we're bypassing.

## Acceptance Criteria
### Agent
- [x] Dummy AC
## Verification
test -f .framework.yaml
## Recommendation
**Recommendation:** GO
**Rationale:** test
**Evidence:** none"

    run "$FW" task update T-9906 --status work-completed \
        --skip-register-requirements --reason "testing bypass"
    [ "$status" -eq 0 ]  # T-3694: was `|| echo`, which can never fail
    [[ "$output" == *"bypass"* ]]
}
