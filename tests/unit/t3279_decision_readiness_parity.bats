#!/usr/bin/env bats
# T-3279 (G-102) — decision-readiness parity for the T-2190 disposition predicate.
#
# The predicate lives in lib/inception-readiness.sh and is called from THREE
# surfaces: the completion gate (update-task.sh, pinned by disposition_gate.bats),
# the decide preflight (lib/inception.sh — REFUSES before any body mutation),
# and review emission (lib/review.sh — WARNS the agent before it hands the
# human a decision the completion gate would refuse).
#
# Origin: 2026-09-05, T-3278 — operator recorded GO via Watchtower on an
# inception with 5 undisposed IWs; decision was written, completion refused,
# task stuck in class-2 state, raw gate stderr (Tier-2 bypass flags included)
# rendered to the operator.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export NO_COLOR=1
    unset CLAUDECODE
    unset FW_SKIP_DISPOSITION_GATE
    mkdir -p "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/.tasks/completed" "$TEST_TEMP_DIR/.context/working"
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/lib/inception-readiness.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Fixture: inception task. $2 = open-questions body, $3 = task id (default T-9300)
_make_inception() {
    local oq_body="$1" id="${2:-T-9300}"
    local path="$TEST_TEMP_DIR/.tasks/active/${id}-parity-test.md"
    cat > "$path" << EOF
---
id: $id
name: "parity test inception"
status: started-work
workflow_type: inception
owner: human
horizon: now
target_blast_radius: 3
voi_score: 0.5
created: 2026-09-05T00:00:00Z
last_update: 2026-09-05T00:00:00Z
---

# $id: parity test inception

## Open Questions

$oq_body

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision

## Recommendation

**Recommendation:** GO
**Rationale:** substantive rationale for the parity fixture, long enough to pass audits.
**Evidence:**
- fixture evidence line

## Decision

## Updates
EOF
    # review marker (T-973) so decide does not block on review-required
    touch "$TEST_TEMP_DIR/.context/working/.reviewed-${id}"
    echo "$path"
}

UNDISPOSED='- **IW-1: undisposed question?**
  confidence: 1
  disposition:
  rationale:'

DISPOSED='- **IW-1: disposed question?**
  confidence: 2
  disposition: answered
  rationale: fixture evidence'

# ---- Leg 0: the shared predicate ----

@test "P1 predicate reports under-disposed question and returns 1" {
    f=$(_make_inception "$UNDISPOSED")
    run inception_underdisposed_questions "$f"
    [ "$status" -eq 1 ]
    [[ "$output" == *"IW-1 disposition=false rationale=false"* ]]
}

@test "P2 predicate is silent and returns 0 on a disposed inception" {
    f=$(_make_inception "$DISPOSED")
    run inception_underdisposed_questions "$f"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "P3 predicate exempts non-inception tasks" {
    f=$(_make_inception "$UNDISPOSED")
    sed -i 's/^workflow_type: inception/workflow_type: build/' "$f"
    run inception_underdisposed_questions "$f"
    [ "$status" -eq 0 ]
}

@test "P4 predicate grandfathers a missing Open Questions section" {
    f=$(_make_inception "$DISPOSED")
    sed -i '/^## Open Questions/,/^## Acceptance/{/^## Acceptance/!d}' "$f"
    run inception_underdisposed_questions "$f"
    [ "$status" -eq 0 ]
}

# ---- Leg 1: decide preflight refuses BEFORE mutation ----

@test "D1 decide on under-disposed inception refuses and leaves the body byte-identical" {
    f=$(_make_inception "$UNDISPOSED")
    before=$(md5sum "$f" | awk '{print $1}')
    run do_inception_decide T-9300 go --rationale "test go" --i-am-human
    [ "$status" -ne 0 ]
    after=$(md5sum "$f" | awk '{print $1}')
    [ "$before" = "$after" ]
    # decision must NOT have been recorded
    ! grep -q '^\*\*Decision\*\*: GO' "$f"
}

@test "D2 the refusal names the under-disposed question in plain language" {
    f=$(_make_inception "$UNDISPOSED")
    run do_inception_decide T-9300 go --rationale "test go" --i-am-human
    [[ "$output" == *"IW-1"* ]]
    [[ "$output" == *"not ready"* || "$output" == *"not yet disposed"* ]]
}

@test "D3 the refusal does NOT push Tier-2 bypass flags at the reader" {
    f=$(_make_inception "$UNDISPOSED")
    run do_inception_decide T-9300 go --rationale "test go" --i-am-human
    [[ "$output" != *"--skip-disposition-gate"* ]]
    [[ "$output" != *"FW_SKIP_DISPOSITION_GATE"* ]]
}

@test "D4 GREEN PATH: decide on a fully disposed inception records the decision" {
    f=$(_make_inception "$DISPOSED")
    run do_inception_decide T-9300 go --rationale "test go" --i-am-human
    # decision block must be written wherever the task file now lives
    local now="$f"
    [ -f "$now" ] || now="$TEST_TEMP_DIR/.tasks/completed/T-9300-parity-test.md"
    [ -f "$now" ]
    grep -q '^\*\*Decision\*\*: GO' "$now"
}

# ---- Leg 2: review emission warns at the invitation surface ----

@test "R1 emit_review on an under-disposed inception warns it is not decision-ready" {
    f=$(_make_inception "$UNDISPOSED" T-9301)
    source "$FRAMEWORK_ROOT/lib/review.sh"
    run emit_review T-9301 "$f"
    [[ "$output" == *"NOT decision-ready"* ]]
    [[ "$output" == *"IW-1"* ]]
}

@test "R2 emit_review on a disposed inception emits no readiness warning" {
    f=$(_make_inception "$DISPOSED" T-9302)
    source "$FRAMEWORK_ROOT/lib/review.sh"
    run emit_review T-9302 "$f"
    [[ "$output" != *"NOT decision-ready"* ]]
}
