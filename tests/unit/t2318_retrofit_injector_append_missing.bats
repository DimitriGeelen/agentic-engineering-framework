#!/usr/bin/env bats
# T-2318: retrofit injector must handle missing-Recommendation-section case
# (pre-T-1716 backlog inceptions). Pins detector↔corrector symmetry per RCA.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    export TEST_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_DIR"
    export FRAMEWORK_ROOT
    mkdir -p "$TEST_DIR/.tasks/active"
}

teardown() {
    rm -rf "$TEST_DIR"
}

_emit_template_inception() {
    local id="$1"
    cat > "$TEST_DIR/.tasks/active/${id}-test.md" <<EOF
---
id: ${id}
name: "template-present inception"
status: captured
workflow_type: inception
horizon: later
owner: human
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

# ${id}

## Context
Test.

## Recommendation

<!-- **Recommendation:** GO / NO-GO / DEFER -->

## Updates
EOF
}

_emit_empty_inception() {
    local id="$1"
    cat > "$TEST_DIR/.tasks/active/${id}-test.md" <<EOF
---
id: ${id}
name: "empty-recommendation inception"
status: captured
workflow_type: inception
horizon: later
owner: human
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

# ${id}

## Context
Test.

## Recommendation


## Updates
EOF
}

_emit_missing_inception() {
    local id="$1"
    # Pre-T-1716 backlog shape: NO ## Recommendation section at all
    cat > "$TEST_DIR/.tasks/active/${id}-test.md" <<EOF
---
id: ${id}
name: "missing-recommendation inception"
status: captured
workflow_type: inception
horizon: later
owner: human
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

# ${id}

## Context
Test.

## Acceptance Criteria
- [ ] something

## Updates
EOF
}

# --- Detector parity (regression guard) ---

@test "scanner detects all three shapes pre-retrofit" {
    source "$FRAMEWORK_ROOT/lib/inception_recommendation.sh"
    _emit_template_inception "T-9001"
    _emit_empty_inception    "T-9002"
    _emit_missing_inception  "T-9003"
    out=$(find_inceptions_without_recommendation "$TEST_DIR/.tasks/active")
    [[ "$out" == *"T-9001"* ]]
    [[ "$out" == *"T-9002"* ]]
    [[ "$out" == *"T-9003"* ]]
}

# --- Corrector parity (the T-2318 fix) ---

@test "retrofit --apply REPLACES template Recommendation (T-1716 path preserved)" {
    source "$FRAMEWORK_ROOT/lib/inception_recommendation.sh"
    _emit_template_inception "T-9101"
    run "$FRAMEWORK_ROOT/bin/fw" inception retrofit-rec --apply
    [ "$status" -eq 0 ]
    has_real_recommendation "$TEST_DIR/.tasks/active/T-9101-test.md"
}

@test "retrofit --apply REPLACES empty Recommendation (T-1716 path preserved)" {
    source "$FRAMEWORK_ROOT/lib/inception_recommendation.sh"
    _emit_empty_inception "T-9102"
    run "$FRAMEWORK_ROOT/bin/fw" inception retrofit-rec --apply
    [ "$status" -eq 0 ]
    has_real_recommendation "$TEST_DIR/.tasks/active/T-9102-test.md"
}

@test "retrofit --apply APPENDS missing Recommendation section (T-2318)" {
    source "$FRAMEWORK_ROOT/lib/inception_recommendation.sh"
    _emit_missing_inception "T-9103"
    # Pre-retrofit: no ## Recommendation at all
    ! grep -q "^## Recommendation" "$TEST_DIR/.tasks/active/T-9103-test.md"
    run "$FRAMEWORK_ROOT/bin/fw" inception retrofit-rec --apply
    [ "$status" -eq 0 ]
    # Post-retrofit: section present + real Recommendation
    grep -q "^## Recommendation" "$TEST_DIR/.tasks/active/T-9103-test.md"
    has_real_recommendation "$TEST_DIR/.tasks/active/T-9103-test.md"
}

@test "retrofit --apply on missing case preserves pre-existing sections" {
    _emit_missing_inception "T-9104"
    # Pre-retrofit: ## Acceptance Criteria + ## Updates present
    grep -q "^## Acceptance Criteria" "$TEST_DIR/.tasks/active/T-9104-test.md"
    grep -q "^## Updates"              "$TEST_DIR/.tasks/active/T-9104-test.md"
    run "$FRAMEWORK_ROOT/bin/fw" inception retrofit-rec --apply
    [ "$status" -eq 0 ]
    # Post-retrofit: all original sections still present
    grep -q "^## Acceptance Criteria" "$TEST_DIR/.tasks/active/T-9104-test.md"
    grep -q "^## Updates"              "$TEST_DIR/.tasks/active/T-9104-test.md"
    grep -q "^## Recommendation"       "$TEST_DIR/.tasks/active/T-9104-test.md"
}

# --- End-to-end detector↔corrector symmetry (the prevention rail) ---

@test "every scanner-emitted task is fixed by --apply (no silent skip)" {
    source "$FRAMEWORK_ROOT/lib/inception_recommendation.sh"
    _emit_template_inception "T-9201"
    _emit_empty_inception    "T-9202"
    _emit_missing_inception  "T-9203"
    # Before: all three detected
    pre=$(find_inceptions_without_recommendation "$TEST_DIR/.tasks/active" | wc -l)
    [ "$pre" -eq 3 ]
    # Apply
    run "$FRAMEWORK_ROOT/bin/fw" inception retrofit-rec --apply
    [ "$status" -eq 0 ]
    # After: scanner emits zero (symmetry holds)
    post=$(find_inceptions_without_recommendation "$TEST_DIR/.tasks/active" | wc -l)
    [ "$post" -eq 0 ]
}
