#!/usr/bin/env bats
# T-1883: CTL-012 section-gating regression — promoted from oe-daily-only to
# (compliance || oe-daily) so pre-push audit catches completed/ tasks with
# unchecked Agent ACs BEFORE the drift ships. Twin of T-1882 (CTL-028 promotion).
#
# CTL-012 is the AC-side symmetric twin of CTL-028. Same scan path
# (COMPLETED_SCAN, populated when compliance section is requested per T-1882),
# same detection-window class (was: up to 24h via daily cron).
#
# Tests verify:
#   1. CTL-012 fires when --section compliance (the new pre-push path)
#   2. CTL-012 still fires when --section oe-daily (no regression)
#   3. CTL-012 fires under pre-push profile (structure,compliance,quality,discovery)
#   4. CTL-012 does NOT fire under --section structure alone (gate granularity)

load ../test_helper

setup() {
    TMPREPO=$(mktemp -d)
    export TMPREPO
    mkdir -p "$TMPREPO/.tasks/completed" "$TMPREPO/.tasks/active" \
             "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports" \
             "$TMPREPO/.git" "$TMPREPO/agents/audit"
    cp "$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py" "$TMPREPO/agents/audit/"
    cp "$FRAMEWORK_ROOT/agents/audit/active-task-scan.py" "$TMPREPO/agents/audit/" 2>/dev/null || true
}

teardown() {
    [ -d "${TMPREPO:-}" ] && rm -rf "$TMPREPO"
}

# Helper: write a completed task with one unchecked Agent AC (triggers CTL-012)
_write_unchecked_task() {
    local id="$1"
    cat > "$TMPREPO/.tasks/completed/${id}-test.md" <<EOF
---
id: $id
name: "test task with unchecked AC"
status: work-completed
workflow_type: build
owner: agent
horizon: now
created: 2026-05-15T00:00:00Z
last_update: 2026-05-15T00:00:00Z
date_finished: 2026-05-15T00:00:00Z
---

# $id: test task

## Acceptance Criteria

### Agent
- [ ] Unchecked criterion that should trip CTL-012
- [x] Checked criterion

## Verification
EOF
}

@test "CTL-012 T-1883: --section compliance fires CTL-012 (pre-push path)" {
    _write_unchecked_task "T-9100"
    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section compliance 2>&1
    [[ "$output" == *"CTL-012"* ]]
    [[ "$output" == *"T-9100"* ]]
}

@test "CTL-012 T-1883: --section oe-daily still fires CTL-012 (no regression)" {
    _write_unchecked_task "T-9101"
    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section oe-daily 2>&1
    [[ "$output" == *"CTL-012"* ]]
    [[ "$output" == *"T-9101"* ]]
}

@test "CTL-012 T-1883: pre-push profile (structure,compliance,quality,discovery) fires CTL-012" {
    _write_unchecked_task "T-9102"
    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section structure,compliance,quality,discovery 2>&1
    [[ "$output" == *"CTL-012"* ]]
    [[ "$output" == *"T-9102"* ]]
}

@test "CTL-012 T-1883: --section structure alone does NOT fire CTL-012 (gate granularity)" {
    # Mirrors T-1882's gate-granularity test for CTL-028. The structure section
    # is intentionally lean for fast pre-push; CTL-012 lives in compliance.
    _write_unchecked_task "T-9103"
    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section structure 2>&1
    [[ "$output" != *"CTL-012"* ]]
}

@test "CTL-012 T-1883: clean fixture under compliance section emits PASS" {
    # Negative path: well-formed completed task (all ACs checked) → PASS line
    cat > "$TMPREPO/.tasks/completed/T-9104-test.md" <<EOF
---
id: T-9104
name: "clean completed task"
status: work-completed
workflow_type: build
owner: agent
horizon: now
created: 2026-05-15T00:00:00Z
last_update: 2026-05-15T00:00:00Z
date_finished: 2026-05-15T00:00:00Z
---

# T-9104

## Acceptance Criteria

### Agent
- [x] Done

## Verification
EOF
    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section compliance 2>&1
    [[ "$output" == *"CTL-012"* ]]
    [[ "$output" == *"have checked ACs"* ]]
}
