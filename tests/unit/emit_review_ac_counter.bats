#!/usr/bin/env bats
# T-2422 (OBS-079): emit_review human-AC counter must anchor on
# `^## Acceptance Criteria` AND `^### Human` start-of-line. Regression-guard
# the class where a task title/description containing the literal string
# `### Human` was flipping the counter into human-mode while still parsing
# the frontmatter.
#
# Pins the OBS-079 surface:
#   - title containing `### Human` → counter must NOT enter human-mode in frontmatter
#   - real Human ACs are still counted correctly
#   - prose containing `### Human` (Context section etc.) does NOT enter human-mode
#
# Companion suite to recommendation_gate_build_partial.bats — both exercise
# emit_review() but for different gate behaviours.

load ../test_helper

REVIEW_LIB="$FRAMEWORK_ROOT/lib/review.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" \
             "$PROJECT_ROOT/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: write a task file with the given frontmatter name and AC body, then
# count human_total + human_checked by sourcing review.sh and running the
# in-place counter. We extract just the counter (lines ~120-170) by running
# emit_review and grepping its stderr for the gate or its stdout for the
# `Open:` line — but the cleanest way is to source the lib and call a tiny
# inline counter that mirrors the production loop. Easier: run emit_review
# and inspect the block message vs the URL — the gate message includes the
# total/checked count when partial-complete with empty Recommendation.
#
# emit_review prints the gate message to stderr only when:
#   - workflow_type ∈ {build,refactor,test,decommission}
#   - human_total > 0 AND human_checked < human_total
#   - ## Recommendation block is empty (forces the BLOCK path)
# We use that path to test that human_total is correctly counted.

_make_task_with_title() {
    local id="$1"
    local title="$2"
    local body="$3"
    local task_file="$PROJECT_ROOT/.tasks/active/${id}-fixture.md"
    cat > "$task_file" <<EOF
---
id: $id
name: "$title"
description: "$title"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-06-16T00:00:00Z
last_update: 2026-06-16T00:00:00Z
date_finished: null
---

# $id

## Context

$body

## Acceptance Criteria

### Agent
- [x] Done

### Human
- [ ] [REVIEW] do the thing

## Verification

EOF
    echo "$task_file"
}

_run_emit() {
    local id="$1"
    local task_file="$2"
    run bash -c "
        export PROJECT_ROOT='$PROJECT_ROOT'
        export FRAMEWORK_ROOT='$FRAMEWORK_ROOT'
        source '$REVIEW_LIB'
        emit_review '$id' '$task_file' 2>&1
    "
}

@test "t1 (OBS-079): task whose name field contains '### Human' counts the REAL Human AC" {
    f=$(_make_task_with_title "T-OBS079A" "PreToolUse hook: detect ### Human outside ## Acceptance Criteria" "Normal body prose.")
    _run_emit "T-OBS079A" "$f"
    # Should hit the build-leg gate (1 unchecked Human AC, empty Rec) → BLOCK
    [ "$status" -ne 0 ]
    [[ "$output" == *"BLOCKED"* ]]
    # The block message includes "1/1" or counts — but the surest assertion is
    # that the gate fires AT ALL, which only happens when human_total > 0.
    # Pre-fix behaviour: human_total stayed at 0 → no block → exit 0.
    [[ "$output" == *"empty ## Recommendation"* ]]
}

@test "t2 (OBS-079): task with no real Human AC + '### Human' only in title → no false-enter" {
    # Build a fixture with `### Human` in the title but NO Human AC section.
    local task_file="$PROJECT_ROOT/.tasks/active/T-OBS079B-fixture.md"
    cat > "$task_file" <<EOF
---
id: T-OBS079B
name: "fix counter that mishandles ### Human in titles"
description: "fix counter that mishandles ### Human in titles"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-06-16T00:00:00Z
last_update: 2026-06-16T00:00:00Z
date_finished: null
---

# T-OBS079B

## Acceptance Criteria

### Agent
- [x] Done

## Verification

EOF
    _run_emit "T-OBS079B" "$task_file"
    # No Human ACs → no partial-complete gate → emit_review allows (no block)
    [ "$status" -eq 0 ]
    [[ "$output" == *"Open:"* ]]
}

@test "t3 (OBS-079): Context prose containing '### Human' does NOT enter human-mode" {
    f=$(_make_task_with_title "T-OBS079C" "normal title" "We need to fix the case where ### Human appears in description prose. The counter must not be confused.")
    _run_emit "T-OBS079C" "$f"
    # Real Human AC count = 1 unchecked. Gate fires correctly.
    [ "$status" -ne 0 ]
    [[ "$output" == *"BLOCKED"* ]]
}

@test "t4 (OBS-079): Human AC headings inside the AC block are matched start-of-line" {
    # Sanity baseline: a totally vanilla task (no `### Human` anywhere except the
    # canonical heading) still counts correctly.
    f=$(_make_task_with_title "T-OBS079D" "vanilla task" "vanilla body")
    _run_emit "T-OBS079D" "$f"
    [ "$status" -ne 0 ]
    [[ "$output" == *"BLOCKED"* ]]
}

@test "t5 (OBS-079): fully-ticked Human AC + '### Human' in title → emit_review allows" {
    local task_file="$PROJECT_ROOT/.tasks/active/T-OBS079E-fixture.md"
    cat > "$task_file" <<EOF
---
id: T-OBS079E
name: "task whose title has ### Human in it"
description: "task whose title has ### Human in it"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-06-16T00:00:00Z
last_update: 2026-06-16T00:00:00Z
date_finished: null
---

# T-OBS079E

## Acceptance Criteria

### Agent
- [x] Done

### Human
- [x] [REVIEW] done by operator

## Verification

EOF
    _run_emit "T-OBS079E" "$task_file"
    # All Human ACs ticked → not partial-complete → no gate
    [ "$status" -eq 0 ]
    [[ "$output" == *"Open:"* ]]
}

@test "t6 (OBS-079): multiple Human ACs, partial completion — count parity" {
    local task_file="$PROJECT_ROOT/.tasks/active/T-OBS079F-fixture.md"
    cat > "$task_file" <<EOF
---
id: T-OBS079F
name: "task whose name contains ### Human"
description: "task whose name contains ### Human"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-06-16T00:00:00Z
last_update: 2026-06-16T00:00:00Z
date_finished: null
---

# T-OBS079F

## Acceptance Criteria

### Agent
- [x] Done

### Human
- [x] [REVIEW] first thing
- [ ] [REVIEW] second thing
- [ ] [REVIEW] third thing

## Verification

EOF
    _run_emit "T-OBS079F" "$task_file"
    # 2/3 unchecked → partial → gate fires
    [ "$status" -ne 0 ]
    [[ "$output" == *"BLOCKED"* ]]
}
