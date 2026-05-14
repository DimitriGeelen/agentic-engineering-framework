#!/usr/bin/env bats
# T-1837: tick_inception_decide_acs PATTERNS must match the real-world
# `[REVIEW] Decide ...` wording variants caught in S-2026-0514 cluster.
#
# Origin: PATTERNS only had `\[REVIEW\].*go/?no-go decision` which missed:
# - T-1829: "[REVIEW] Decide go/no-go AND which approach (A/B/C/D)"
# - T-1830: "[REVIEW] Decide GO/NO-GO/DEFER on the umbrella remediation..."
# - T-1831: "[REVIEW] Decide on prevention pattern (Layer 1) AND..."
# All three user decisions landed as `**Decision**: GO` in body, but the
# Human AC checkboxes stayed `- [ ]` because the regex didn't fire.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_make_task() {
    local task_id="$1"
    local ac_text="$2"
    local f="$TEST_TEMP_DIR/$task_id-test.md"
    cat > "$f" <<EOF
---
id: $task_id
workflow_type: inception
---

## Recommendation

**Recommendation:** GO

## Acceptance Criteria

### Human
- [ ] $ac_text

## Decision

EOF
    echo "$f"
}

@test "T-1829 wording: 'Decide go/no-go AND which approach' is ticked" {
    local f
    f=$(_make_task "T-9801" "[REVIEW] Decide go/no-go AND which approach (A/B/C/D)")
    tick_inception_decide_acs "$f"
    grep -q '^- \[x\] \[REVIEW\] Decide go/no-go' "$f"
}

@test "T-1830 wording: 'Decide GO/NO-GO/DEFER on the umbrella...' is ticked" {
    local f
    f=$(_make_task "T-9802" "[REVIEW] Decide GO/NO-GO/DEFER on the umbrella remediation pattern, AND which candidate")
    tick_inception_decide_acs "$f"
    grep -q '^- \[x\] \[REVIEW\] Decide GO/NO-GO/DEFER' "$f"
}

@test "T-1831 wording: 'Decide on prevention pattern' is ticked" {
    local f
    f=$(_make_task "T-9803" "[REVIEW] Decide on prevention pattern (Layer 1) AND triage Layer 2")
    tick_inception_decide_acs "$f"
    grep -q '^- \[x\] \[REVIEW\] Decide on prevention pattern' "$f"
}

@test "non-decide [REVIEW] AC is NOT ticked (no false positive on review-class verbs)" {
    local f
    f=$(_make_task "T-9804" "[REVIEW] Confirm UI renders cleanly in production")
    tick_inception_decide_acs "$f"
    # Must remain unchecked — 'Confirm' is not 'decide'.
    grep -q '^- \[ \] \[REVIEW\] Confirm UI' "$f"
}
