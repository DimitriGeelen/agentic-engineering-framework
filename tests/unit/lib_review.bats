#!/usr/bin/env bats
# Unit tests for lib/review.sh
#
# Tests emit_review() — human review output helper

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/review.sh"

    # Create task directory structure
    mkdir -p "$TEST_TEMP_DIR/.tasks/active"
    mkdir -p "$TEST_TEMP_DIR/.tasks/completed"
    mkdir -p "$TEST_TEMP_DIR/.context/working"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_create_review_task() {
    local task_id="${1:-T-999}"
    local workflow="${2:-build}"
    local file="$TEST_TEMP_DIR/.tasks/active/${task_id}-test.md"
    # T-2206: inception fixtures need a substantive ## Recommendation block,
    # otherwise emit_review BLOCKS them via the Slice C consumer-side gate.
    #
    # T-2949: this used to add the block for inceptions ONLY, on the reasoning
    # that "build tasks do not gate on Recommendation". That was true when it was
    # written and T-2421 (2026-06-16) made it false — the same BLOCK now applies
    # to partial-complete build-class tasks, which is exactly what this fixture
    # builds (1 of 3 Human ACs checked). Five legs here went red that day and
    # stayed red for 57 days; the comment above them read as intent, so nobody
    # re-read the code. Unconditional now — a fixture must satisfy the gates that
    # are live, not the ones that were live when it was authored.
    #
    # Deliberately NOT fixed with FW_ALLOW_EMPTY_RECOMMENDATION=1: bypassing a
    # gate inside its own suite makes the suite blind to the thing it guards.
    # The leg that asserts the gate still FIRES is below (`rec-gate blocks a
    # partial-complete build fixture`).
    local rec_block=$'\n## Recommendation\n\n**Recommendation:** GO\n**Rationale:** test fixture\n'
    cat > "$file" <<EOF
---
id: ${task_id}
name: "Test task"
status: work-completed
workflow_type: ${workflow}
owner: human
---

# ${task_id}: Test task
${rec_block}
## Acceptance Criteria

### Agent
- [x] Agent criterion done

### Human
- [ ] First human AC
- [x] Second human AC checked
- [ ] Third human AC
EOF
    echo "$file"
}

@test "review: emit_review returns 1 on empty task_id" {
    run emit_review ""
    [ "$status" -eq 1 ]
}

@test "review: emit_review returns 1 on missing task file" {
    run emit_review "T-000"
    [ "$status" -eq 1 ]
}

@test "review: emit_review outputs review header for build task" {
    local task_file
    task_file=$(_create_review_task "T-100" "build")
    run emit_review "T-100" "$task_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-100"* ]]
    [[ "$output" == *"Human AC Review"* ]]
}

@test "review: emit_review outputs inception review for inception task" {
    local task_file
    task_file=$(_create_review_task "T-200" "inception")
    run emit_review "T-200" "$task_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-200"* ]]
    [[ "$output" == *"Inception Review"* ]]
}

@test "review: emit_review counts human ACs correctly" {
    local task_file
    task_file=$(_create_review_task "T-300" "build")
    run emit_review "T-300" "$task_file"
    [ "$status" -eq 0 ]
    # 1 checked out of 3 total
    [[ "$output" == *"1/3"* ]]
}

@test "review: emit_review finds task file by ID" {
    _create_review_task "T-400" "build"
    run emit_review "T-400"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-400"* ]]
}

@test "review: emit_review includes Watchtower URL" {
    local task_file
    task_file=$(_create_review_task "T-500" "build")
    run emit_review "T-500" "$task_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"http"* ]]
    [[ "$output" == *"/review/T-500"* ]]
}

@test "review: emit_review uses inception URL for inception tasks" {
    local task_file
    task_file=$(_create_review_task "T-600" "inception")
    run emit_review "T-600" "$task_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/inception/T-600"* ]]
}

@test "review: emit_review handles task with zero human ACs" {
    local file="$TEST_TEMP_DIR/.tasks/active/T-700-test.md"
    cat > "$file" <<EOF
---
id: T-700
name: "No human ACs"
workflow_type: build
---

# T-700: No human ACs

## Acceptance Criteria

### Agent
- [x] Only agent criteria
EOF
    run emit_review "T-700" "$file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0/0"* ]]
}

@test "review: T-1492 — emit_review survives pipefail when inception task has no Recommendation line" {
    # T-1492 invariant: grep-finds-nothing under pipefail must NOT silently
    # abort emit_review between "Scan QR" and the marker touch.
    # T-2206 update: empty ## Recommendation now BLOCKS by default — assert the
    # pipefail-survival invariant under the FW_ALLOW_EMPTY_RECOMMENDATION=1 bypass
    # path, which keeps emit_review's body-print path active. The T-2206 BLOCK
    # branch is covered separately in tests/unit/audit_inception_recommendation.bats.
    local file="$TEST_TEMP_DIR/.tasks/active/T-1492a-test.md"
    cat > "$file" <<EOF
---
id: T-1492a
name: "Inception with no recommendation"
workflow_type: inception
owner: human
---

# T-1492a: Inception with no recommendation

## Acceptance Criteria

### Human
- [ ] [REVIEW] decide
EOF
    # Run with the exact shell mode update-task.sh uses
    set -euo pipefail
    FW_ALLOW_EMPTY_RECOMMENDATION=1 run emit_review "T-1492a" "$file"
    [ "$status" -eq 0 ]
    # Marker MUST exist — proves we reached past the bug site (line ~150)
    [ -f "$TEST_TEMP_DIR/.context/working/.reviewed-T-1492a" ]
    # Warning MUST be emitted (no silent fallback)
    [[ "$output" == *"No \`**Recommendation:**\` line found"* ]]
}

@test "review: T-1492 — HTML-commented Recommendation line does not poison the rationale" {
    # If the only **Recommendation:** match is inside an HTML comment, treat
    # it as missing rather than extracting the comment marker as rationale.
    # T-2206: same bypass needed — empty ## Recommendation BLOCKS by default.
    local file="$TEST_TEMP_DIR/.tasks/active/T-1492b-test.md"
    cat > "$file" <<EOF
---
id: T-1492b
name: "Recommendation in HTML comment only"
workflow_type: inception
owner: human
---

# T-1492b: only commented recommendation

<!-- **Recommendation:** TBD -->

## Acceptance Criteria

### Human
- [ ] [REVIEW] decide
EOF
    set -euo pipefail
    FW_ALLOW_EMPTY_RECOMMENDATION=1 run emit_review "T-1492b" "$file"
    [ "$status" -eq 0 ]
    [ -f "$TEST_TEMP_DIR/.context/working/.reviewed-T-1492b" ]
    [[ "$output" == *"No \`**Recommendation:**\` line found"* ]]
}

@test "review: T-1492 — present Recommendation line is extracted into the CLI rationale" {
    # T-2206: the Recommendation line must live INSIDE the ## Recommendation
    # section for the new audit gate to accept it. Pre-T-2206 fixture had the
    # bare line at file scope; updated to canonical structure.
    local file="$TEST_TEMP_DIR/.tasks/active/T-1492c-test.md"
    cat > "$file" <<EOF
---
id: T-1492c
name: "Has recommendation"
workflow_type: inception
owner: human
---

# T-1492c

## Recommendation

**Recommendation:** GO — apply the fix

## Acceptance Criteria

### Human
- [ ] [REVIEW] decide
EOF
    set -euo pipefail
    run emit_review "T-1492c" "$file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GO — apply the fix"* ]]
    # No warning when recommendation is present
    [[ "$output" != *"No \`**Recommendation:**\` line found"* ]]
}

@test "review: emit_review respects WATCHTOWER_URL env var" {
    export WATCHTOWER_URL="http://custom:8080"
    local task_file
    task_file=$(_create_review_task "T-800" "build")
    run emit_review "T-800" "$task_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"http://custom:8080/review/T-800"* ]]
    unset WATCHTOWER_URL
}

@test "review: T-2421 rec-gate BLOCKS a partial-complete build fixture with no Recommendation" {
    # T-2949. Every other build fixture in this file now carries a Recommendation
    # block, which is what T-2421 requires — but that alone would leave the suite
    # merely TOLERATING the gate rather than covering it. Strip the block back out
    # and the gate must still fire; otherwise a regression that disables T-2421
    # would turn this whole file green and tell us nothing.
    local task_file
    task_file=$(_create_review_task "T-810" "build")
    # Remove the ## Recommendation section (up to the next `## ` heading).
    sed -i '/^## Recommendation$/,/^## /{/^## Acceptance Criteria$/!d}' "$task_file"
    run grep -c '^## Recommendation$' "$task_file"
    [ "$output" -eq 0 ]   # fixture really is bare, or the assertion below is vacuous

    run emit_review "T-810" "$task_file"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Recommendation"* ]]
}
