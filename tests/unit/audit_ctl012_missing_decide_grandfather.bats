#!/usr/bin/env bats
# T-2385: CTL-012-MISSING-DECIDE grandfather cutoff regression.
#
# RCA finding: T-1902/T-2000/T-1915/T-1905 were flagged as
# "flipped without decide ceremony" but git archaeology proved each was
# moved into .tasks/completed/ as a silent git-mv side-effect of an
# unrelated commit (the L-390 pattern) — weeks BEFORE the
# CTL-012-MISSING-DECIDE classifier itself existed (T-2202, shipped
# 2026-06-13). The detector cannot have caught something it didn't exist
# to catch; re-flagging these forever adds no actionable signal, since the
# flip path is already closed for NEW instances by CTL-028 (T-1870/T-1882/
# T-1883) at pre-push time.
#
# Fix: agents/audit/completed-task-scan.py MISSING_DECIDE_CUTOFF (2026-06-13)
# — a task is only classified "missing-decide" (rather than silently
# skipped) when its date_finished is on/after the cutoff, OR when
# date_finished is empty/absent (a live, undated desync — still flagged,
# matches T-2494 in production data).
#
# Tests verify:
#   1. Pre-cutoff date_finished + auto-tick marker + empty Decision → NOT flagged (grandfathered)
#   2. Post-cutoff date_finished + same shape → still flagged missing-decide (no over-suppression)
#   3. Missing/empty date_finished + same shape → still flagged (live desync, undated)
#   4. Pre-cutoff task with a genuine (non-auto-tick) unchecked AC → still flagged as plain "drift"

load ../test_helper

setup() {
    TMPREPO=$(mktemp -d)
    export TMPREPO
    mkdir -p "$TMPREPO/.tasks/completed" "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports"
}

teardown() {
    [ -d "${TMPREPO:-}" ] && rm -rf "$TMPREPO"
}

_write_missing_decide_task() {
    local id="$1" date_finished="$2"
    cat > "$TMPREPO/.tasks/completed/${id}-test.md" <<EOF
---
id: $id
name: "test inception, decide ceremony never ran"
status: work-completed
workflow_type: inception
owner: human
horizon: now
created: 2026-05-01T00:00:00Z
last_update: 2026-05-01T00:00:00Z
date_finished: $date_finished
---

# $id: test task

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Verification
EOF
}

@test "CTL-012-MISSING-DECIDE T-2385: pre-cutoff date_finished is grandfathered (not flagged)" {
    _write_missing_decide_task "T-9200" "2026-05-18T20:15:17Z"
    run python3 "$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py" "$TMPREPO/.tasks" "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports"
    [ "$status" -eq 0 ]
    # T-9200 correctly still surfaces via missing_episodic/missing_research
    # (unrelated checks, not scoped by this cutoff) — assert only that it is
    # absent from unchecked_ac specifically.
    unchecked=$(echo "$output" | python3 -c "import sys,json; print([i['id'] for i in json.load(sys.stdin)['unchecked_ac']])")
    [[ "$unchecked" != *"T-9200"* ]]
}

@test "CTL-012-MISSING-DECIDE T-2385: post-cutoff date_finished still flags missing-decide" {
    _write_missing_decide_task "T-9201" "2026-07-01T00:00:00Z"
    run python3 "$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py" "$TMPREPO/.tasks" "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"id": "T-9201"'* ]]
    [[ "$output" == *'"class": "missing-decide"'* ]]
}

@test "CTL-012-MISSING-DECIDE T-2385: empty date_finished (live/undated desync) still flags" {
    _write_missing_decide_task "T-9202" ""
    run python3 "$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py" "$TMPREPO/.tasks" "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"id": "T-9202"'* ]]
    [[ "$output" == *'"class": "missing-decide"'* ]]
}

@test "CTL-012-MISSING-DECIDE T-2385: pre-cutoff task with genuine unchecked AC (no auto-tick marker) still flags as drift" {
    cat > "$TMPREPO/.tasks/completed/T-9203-test.md" <<'INNEREOF'
---
id: T-9203
name: "test task, real outstanding AC, not a decide-ceremony artifact"
status: work-completed
workflow_type: build
owner: agent
horizon: now
created: 2026-05-01T00:00:00Z
last_update: 2026-05-01T00:00:00Z
date_finished: 2026-05-18T20:15:17Z
---

# T-9203: test task

## Acceptance Criteria

### Agent
- [ ] Genuine outstanding criterion

## Verification
INNEREOF
    run python3 "$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py" "$TMPREPO/.tasks" "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"id": "T-9203"'* ]]
    [[ "$output" == *'"class": "drift"'* ]]
}
