#!/usr/bin/env bats
# T-2055 — Pin CTL-029, the active-side mirror of CTL-028. Catches tasks
# where Agent ACs are 100% ticked but status remains started-work/issues
# (shipped-but-unclosed — agent finished the work and forgot to run
# `--status work-completed`).
#
# Four shape cases covered:
#   (a) ### Agent + ### Human split — count Agent only
#   (b) ## Acceptance Criteria with no sub-headers — count all
#   (c) placeholder/template-only AC list — silent (no false WARN)
#   (d) partial-ticked (mixed [x] and [ ]) — silent

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_PROJECT="$TEST_TEMP_DIR/proj-ctl029"
    mkdir -p "$TEST_PROJECT/.tasks/active" \
             "$TEST_PROJECT/.tasks/completed" \
             "$TEST_PROJECT/.tasks/templates" \
             "$TEST_PROJECT/.context/working" \
             "$TEST_PROJECT/.context/audits"
    echo "# template" > "$TEST_PROJECT/.tasks/templates/default.md"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_PROJECT/.framework.yaml"
    export PROJECT_ROOT="$TEST_PROJECT"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_run_compliance_audit() {
    run "$FRAMEWORK_ROOT/bin/fw" audit --section compliance
}

@test "(a) Agent/Human split, all Agent ACs ticked → CTL-029 WARN" {
    cat > "$TEST_PROJECT/.tasks/active/T-7001-shipped-not-closed.md" <<'EOF'
---
id: T-7001
name: shipped not closed
status: started-work
workflow_type: build
owner: agent
horizon: now
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

## Acceptance Criteria

### Agent
- [x] Did the thing
- [x] Wrote the test

### Human
- [ ] [REVIEW] Looks good
EOF
    _run_compliance_audit
    [[ "$output" == *"CTL-029: T-7001 has all Agent ACs ticked"* ]]
}

@test "(b) no sub-headers, all ACs ticked → CTL-029 WARN" {
    cat > "$TEST_PROJECT/.tasks/active/T-7002-flat-shipped.md" <<'EOF'
---
id: T-7002
name: flat shipped
status: started-work
workflow_type: build
owner: agent
horizon: now
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

## Acceptance Criteria

- [x] Implementation landed
- [x] Coverage proves it
EOF
    _run_compliance_audit
    [[ "$output" == *"CTL-029: T-7002 has all Agent ACs ticked"* ]]
}

@test "(c) placeholder-only ACs (template stubs) → silent" {
    cat > "$TEST_PROJECT/.tasks/active/T-7003-template-only.md" <<'EOF'
---
id: T-7003
name: template only
status: started-work
workflow_type: build
owner: agent
horizon: now
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

## Acceptance Criteria

### Agent
- [ ] [First criterion]
- [ ] [Second criterion]
EOF
    _run_compliance_audit
    [[ "$output" != *"CTL-029: T-7003"* ]]
}

@test "(d) partial-ticked → silent" {
    cat > "$TEST_PROJECT/.tasks/active/T-7004-partial.md" <<'EOF'
---
id: T-7004
name: partial work
status: started-work
workflow_type: build
owner: agent
horizon: now
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

## Acceptance Criteria

### Agent
- [x] First done
- [ ] Second still pending
EOF
    _run_compliance_audit
    [[ "$output" != *"CTL-029: T-7004"* ]]
}

@test "captured task (not started-work) → silent even when all ticked" {
    # Edge case: a task could be filed with already-ticked ACs (e.g. from a
    # spec that was copy-pasted). Only started-work/issues should WARN.
    cat > "$TEST_PROJECT/.tasks/active/T-7005-captured-with-ticks.md" <<'EOF'
---
id: T-7005
name: captured with pre-ticked ACs
status: captured
workflow_type: build
owner: agent
horizon: now
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

## Acceptance Criteria

### Agent
- [x] Already ticked
EOF
    _run_compliance_audit
    [[ "$output" != *"CTL-029: T-7005"* ]]
}

@test "(f) T-100129: human-owned, unchecked Human ACs → partial-complete, INFO not WARN" {
    cat > "$TEST_PROJECT/.tasks/active/T-7007-partial-complete.md" <<'EOF'
---
id: T-7007
name: awaiting human review
status: started-work
workflow_type: build
owner: human
horizon: now
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

## Acceptance Criteria

### Agent
- [x] Did the thing
- [x] Wrote the test

### Human
- [ ] [REVIEW] Layout reads clean
EOF
    _run_compliance_audit
    [[ "$output" != *"CTL-029: T-7007"* ]]
    [[ "$output" == *"partial-complete task(s) awaiting human review"* ]]
}

@test "(g) T-100129: human-owned, substantive Recommendation, no Human ACs → partial-complete, no WARN" {
    cat > "$TEST_PROJECT/.tasks/active/T-7008-reco-handoff.md" <<'EOF'
---
id: T-7008
name: handed off with recommendation
status: started-work
workflow_type: build
owner: human
horizon: now
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

## Acceptance Criteria

### Agent
- [x] Shipped and verified

## Recommendation

**Recommendation:** GO
**Rationale:** All agent verification passed; awaiting operator confirmation of the deploy window.
EOF
    _run_compliance_audit
    [[ "$output" != *"CTL-029: T-7008"* ]]
}

@test "(h) T-100129: human-owned but nothing actionable (no Human ACs, no Recommendation) → still WARN" {
    cat > "$TEST_PROJECT/.tasks/active/T-7009-improper-handoff.md" <<'EOF'
---
id: T-7009
name: human-owned dead end
status: started-work
workflow_type: build
owner: human
horizon: now
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

## Acceptance Criteria

### Agent
- [x] Everything ticked
EOF
    _run_compliance_audit
    [[ "$output" == *"CTL-029: T-7009 has all Agent ACs ticked"* ]]
}

@test "PASS line appears when there are no completable-not-completed tasks" {
    # Test isolation: only the captured task above is present
    cat > "$TEST_PROJECT/.tasks/active/T-7006-captured.md" <<'EOF'
---
id: T-7006
name: just captured
status: captured
workflow_type: build
owner: agent
horizon: now
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

## Acceptance Criteria

### Agent
- [ ] not yet
EOF
    _run_compliance_audit
    [[ "$output" == *"CTL-029: No completable-but-not-completed"* ]]
}
