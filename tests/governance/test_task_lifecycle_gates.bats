#!/usr/bin/env bats
# T-1608 (T-1601 GO follow-up, Phase 3): red-team harness for task-lifecycle gates.
#
# Phase 1 (T-1606) covered 7 PreToolUse hooks. Phase 2 (T-1607) covered 3 git hooks.
# Phase 3 closes the loop on the 4 task-lifecycle gates:
#
#   - P-010: unchecked AC gate    (agents/task-create/update-task.sh:check_acceptance_criteria)
#   - P-011: verification gate    (agents/task-create/update-task.sh:run_verification_commands)
#   - RCA gate (T-1550)          (agents/task-create/update-task.sh:check_rca_for_bugfix)
#   - inception-decide CLAUDECODE (lib/inception.sh:do_inception_decide)
#
# Block-only coverage. Allow paths trigger irreversible side effects (move task to
# completed/, episodic generation, fabric updates) that we don't want to mutate
# in the framework repo. The block paths are what governance regression detection
# needs to pin — if a block silently becomes an allow, that's the bug.
#
# Synthetic task files use T-99XX IDs; teardown removes residue from both
# .tasks/active/ and .tasks/completed/ + episodic/.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FW="$FRAMEWORK_ROOT/bin/fw"

# Always run from FRAMEWORK_ROOT so PROJECT_ROOT resolves to the framework repo
setup() {
    cd "$FRAMEWORK_ROOT"
}

# Sweep any T-99XX residue from active/ + completed/ + episodic/.
# Tests should clean themselves; this is a backstop in case of unexpected exit.
teardown() {
    rm -f "$FRAMEWORK_ROOT/.tasks/active/"T-99[0-9][0-9]-*.md
    rm -f "$FRAMEWORK_ROOT/.tasks/completed/"T-99[0-9][0-9]-*.md
    rm -f "$FRAMEWORK_ROOT/.context/episodic/"T-99[0-9][0-9].yaml
}

# Helper: write a synthetic task file. Caller picks ID + name + body shape.
_write_task() {
    local id="$1"
    local title="$2"
    local body="$3"
    local file="$FRAMEWORK_ROOT/.tasks/active/${id}-redteam.md"
    cat > "$file" <<EOF
---
id: ${id}
name: "${title}"
description: "redteam-harness fixture"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
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

# ============================================================================
# P-010: unchecked AC gate
# ============================================================================

@test "P-010: blocks --status work-completed when Agent ACs unchecked" {
    _write_task "T-9910" "redteam P-010 unchecked AC fixture" "$(cat <<'BODY'
## Acceptance Criteria

### Agent
- [ ] First criterion is intentionally unchecked
- [ ] Second criterion is also unchecked

## Recommendation
- **Recommendation:** GO
- **Rationale:** test fixture
- **Evidence:** none — block path

## Verification
true
BODY
)"
    run "$FW" task update T-9910 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"unchecked"* ]] || [[ "$output" == *"Cannot complete"* ]]
}

# ============================================================================
# P-011: verification gate
# ============================================================================

@test "P-011: blocks --status work-completed when verification command fails" {
    _write_task "T-9911" "redteam P-011 verification fail fixture" "$(cat <<'BODY'
## Acceptance Criteria

### Agent
- [x] AC is checked so P-010 passes
- [x] Second AC also checked

## Recommendation
- **Recommendation:** GO
- **Rationale:** test fixture
- **Evidence:** none — block path

## Verification
false
BODY
)"
    run "$FW" task update T-9911 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"verification"* ]] || [[ "$output" == *"Verification"* ]] || [[ "$output" == *"failed"* ]]
}

# ============================================================================
# RCA gate (T-1550)
# ============================================================================

@test "RCA gate: blocks bug-class task with empty ## RCA section" {
    # Title contains 'fix' → triggers bug-class detection. ACs checked + verification
    # passes + recommendation present so earlier gates don't fire — RCA is the test.
    _write_task "T-9912" "redteam fix bug-class RCA gate fixture" "$(cat <<'BODY'
## Acceptance Criteria

### Agent
- [x] AC is checked
- [x] Second AC also checked

## Recommendation
- **Recommendation:** GO
- **Rationale:** test fixture
- **Evidence:** none — block path

## Verification
true

## RCA

<!-- intentionally empty so the gate fires -->
BODY
)"
    run "$FW" task update T-9912 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"RCA"* ]] || [[ "$output" == *"bug-class"* ]]
}

# ============================================================================
# inception-decide CLAUDECODE gate (T-1259)
# ============================================================================

@test "inception-decide: blocks invocation when CLAUDECODE=1 set" {
    # Gate fires BEFORE task file lookup, so no fixture needed — any T-XXX works.
    run env CLAUDECODE=1 "$FW" inception decide T-9913 go --rationale "redteam test"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Claude Code"* ]] || [[ "$output" == *"CLAUDECODE"* ]] || [[ "$output" == *"agents must not invoke"* ]] || [[ "$output" == *"Agents must not invoke"* ]]
}

@test "inception-decide: --i-am-human bypasses the CLAUDECODE block" {
    # Bypass should let the script proceed past the gate. Without a real task file
    # the script will fail later with "Task not found" — that's our success signal:
    # the CLAUDECODE block message must NOT appear.
    run env CLAUDECODE=1 "$FW" inception decide T-9914 go --rationale "redteam test" --i-am-human
    # Either it succeeds (unlikely without a task file), or it fails with a
    # different error that does NOT mention the CLAUDECODE block.
    [[ "$output" != *"running inside Claude Code"* ]]
    [[ "$output" != *"Agents must not invoke"* ]]
}
