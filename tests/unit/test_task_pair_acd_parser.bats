#!/usr/bin/env bats
# T-1762: task-pair §ACD gate (P-012) — parser spike (T-1713 Spike 1)
#
# Tests for lib/task_pair_acd.{sh,py}::extract_deliverables
#
# Pins the parser contract:
#   - T-1442 GO with explicit `**Decomposition (follow-up build tasks after GO):**`
#     block → returns 8 items (B1..B8)
#   - T-1713 GO without Decomposition heading → returns empty (gate no-op)
#   - T-1715 GO without Decomposition heading → returns empty (gate no-op)
#   - NO-GO inception → exit 3
#   - Missing Recommendation block → exit 2

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    cd "$TEST_TEMP_DIR" || exit 1
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

write_inception() {
    local file="$1"
    cat > "$file"
}

@test "T-1442 (3-deliverable GO) — extracts B1..B8 from Decomposition" {
    run python3 "$FRAMEWORK_ROOT/lib/task_pair_acd.py" extract \
        "$FRAMEWORK_ROOT/.tasks/completed/T-1442-ac-validation-default-flip--mechanical-v.md"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 8 ]
    [[ "${lines[0]}" =~ ^B1: ]]
    [[ "${lines[7]}" =~ ^B8: ]]
}

@test "T-1713 (1-deliverable GO, no Decomposition) — returns empty" {
    run python3 "$FRAMEWORK_ROOT/lib/task_pair_acd.py" extract \
        "$FRAMEWORK_ROOT/.tasks/completed/T-1713-task-pair-acd-gate-detect-substrate-vs-d.md"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-1715 (clean-shipped baseline) — returns empty" {
    run python3 "$FRAMEWORK_ROOT/lib/task_pair_acd.py" extract \
        "$FRAMEWORK_ROOT/.tasks/completed/T-1715-meta-rca-agent-files-inception-artefacts.md"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "NO-GO inception — exit 3" {
    write_inception "$TEST_TEMP_DIR/T-9001.md" <<'EOF'
---
id: T-9001
workflow_type: inception
---
# T-9001
## Recommendation
**Recommendation:** NO-GO
**Rationale:** declined.
EOF
    run python3 "$FRAMEWORK_ROOT/lib/task_pair_acd.py" extract \
        "$TEST_TEMP_DIR/T-9001.md"
    [ "$status" -eq 3 ]
}

@test "Missing Recommendation block — exit 2" {
    write_inception "$TEST_TEMP_DIR/T-9002.md" <<'EOF'
---
id: T-9002
workflow_type: inception
---
# T-9002
## Context
Just a context.
EOF
    run python3 "$FRAMEWORK_ROOT/lib/task_pair_acd.py" extract \
        "$TEST_TEMP_DIR/T-9002.md"
    [ "$status" -eq 2 ]
}

@test "DEFER inception — exit 3 (gate no-op)" {
    write_inception "$TEST_TEMP_DIR/T-9003.md" <<'EOF'
---
id: T-9003
workflow_type: inception
---
# T-9003
## Recommendation
**Recommendation:** DEFER
**Rationale:** parked.
EOF
    run python3 "$FRAMEWORK_ROOT/lib/task_pair_acd.py" extract \
        "$TEST_TEMP_DIR/T-9003.md"
    [ "$status" -eq 3 ]
}

@test "GO with Decomposition — multi-line items extracted" {
    write_inception "$TEST_TEMP_DIR/T-9004.md" <<'EOF'
---
id: T-9004
workflow_type: inception
---
# T-9004
## Recommendation
**Recommendation:** GO

**Rationale:** because.

**Decomposition (follow-up build tasks after GO):**
- B1: First deliverable
- B2: Second deliverable

**Risk:** none

EOF
    run python3 "$FRAMEWORK_ROOT/lib/task_pair_acd.py" extract \
        "$TEST_TEMP_DIR/T-9004.md"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [[ "${lines[0]}" == "B1: First deliverable" ]]
    [[ "${lines[1]}" == "B2: Second deliverable" ]]
}

@test "HTML-comment-only Recommendation — exit 3 (no GO line)" {
    write_inception "$TEST_TEMP_DIR/T-9005.md" <<'EOF'
---
id: T-9005
workflow_type: inception
---
# T-9005
## Recommendation
<!-- **Recommendation:** GO / NO-GO / DEFER (template hint) -->
EOF
    run python3 "$FRAMEWORK_ROOT/lib/task_pair_acd.py" extract \
        "$TEST_TEMP_DIR/T-9005.md"
    [ "$status" -eq 3 ]
}

@test "GO with bold-emphasis on verdict (T-1746 tolerance) — Decomposition extracted" {
    write_inception "$TEST_TEMP_DIR/T-9006.md" <<'EOF'
---
id: T-9006
workflow_type: inception
---
# T-9006
## Recommendation
**Recommendation:** **GO**

**Decomposition (follow-up build tasks after GO):**
- B1: Item one
EOF
    run python3 "$FRAMEWORK_ROOT/lib/task_pair_acd.py" extract \
        "$TEST_TEMP_DIR/T-9006.md"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
}

@test "shell wrapper extract_deliverables matches python output" {
    source "$FRAMEWORK_ROOT/lib/task_pair_acd.sh"
    run extract_deliverables \
        "$FRAMEWORK_ROOT/.tasks/completed/T-1442-ac-validation-default-flip--mechanical-v.md"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 8 ]
}
