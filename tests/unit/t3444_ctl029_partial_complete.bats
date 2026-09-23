#!/usr/bin/env bats
# T-3444 — CTL-029 (T-2055) must not WARN on the correctly partial-complete
# state CLAUDE.md prescribes: owner:human with an open ### Human criterion.
# Upstreamed from 832-Workflow-designer's consult (832-T833, OBS-485): their
# vendored audit.sh fired CTL-029 on every partial-complete task because the
# predicate read neither `owner:` nor `### Human`, and the only remedy (an
# agent closing a human-owned task) is prohibited.
#
# Four control branches (832's control shape):
#   (1) owner:human, unticked ### Human criterion exists → silent (the fix)
#   (2) owner:agent (abandoned), all Agent ACs ticked      → still fires
#   (3) owner:human, every ### Human criterion ticked      → still fires
#   (4) owner:human, no ### Human section at all           → still fires

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_PROJECT="$TEST_TEMP_DIR/proj-ctl029-partial"
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

@test "predicate is locatable in agents/audit/audit.sh (refuse to measure if not)" {
    if ! grep -q "CTL-029" "$FRAMEWORK_ROOT/agents/audit/audit.sh"; then
        echo "CTL-029 predicate not found in agents/audit/audit.sh — refusing to measure a moved/renamed control" >&2
        exit 3
    fi
}

_run_compliance_audit() {
    run "$FRAMEWORK_ROOT/bin/fw" audit --section compliance
}

@test "(1) owner:human + open ### Human criterion → silent (partial-complete, not shipped-unclosed)" {
    cat > "$TEST_PROJECT/.tasks/active/T-8001-partial-complete.md" <<'EOF'
---
id: T-8001
name: partial complete awaiting human review
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
- [ ] [REVIEW] Looks good
EOF
    _run_compliance_audit
    [[ "$output" != *"CTL-029: T-8001"* ]]
}

@test "(2) owner:agent, abandoned, all Agent ACs ticked → still fires" {
    cat > "$TEST_PROJECT/.tasks/active/T-8002-abandoned.md" <<'EOF'
---
id: T-8002
name: abandoned agent-owned task
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
EOF
    _run_compliance_audit
    [[ "$output" == *"CTL-029: T-8002 has all Agent ACs ticked"* ]]
}

@test "(3) owner:human, every ### Human criterion ticked → still fires" {
    cat > "$TEST_PROJECT/.tasks/active/T-8003-human-all-ticked.md" <<'EOF'
---
id: T-8003
name: human owner but all human ACs ticked
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

### Human
- [x] [REVIEW] Looks good
EOF
    _run_compliance_audit
    [[ "$output" == *"CTL-029: T-8003 has all Agent ACs ticked"* ]]
}

@test "(4) owner:human, no ### Human section at all → still fires" {
    cat > "$TEST_PROJECT/.tasks/active/T-8004-human-no-section.md" <<'EOF'
---
id: T-8004
name: human owner, no human section
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
EOF
    _run_compliance_audit
    [[ "$output" == *"CTL-029: T-8004 has all Agent ACs ticked"* ]]
}
