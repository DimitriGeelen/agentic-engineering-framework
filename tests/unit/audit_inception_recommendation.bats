#!/usr/bin/env bats
# T-2206 (T-2204 Slice C) — emit_review / emit_review_batch refuse emission
# when an inception task has a template-only ## Recommendation block.
#
# Shipped under T-2206:
#   - lib/review.sh:emit_review (lines ~147-186) upgraded WARN→BLOCK on inception
#     with empty Recommendation. Bypass: FW_ALLOW_EMPTY_RECOMMENDATION=1 → Tier-2 log.
#   - lib/review.sh:emit_review_batch (lines ~315-415) gained a pre-pass that
#     refuses the entire batch if any inception member has empty Recommendation;
#     same bypass.
#   - lib/task-audit.sh:117 audit_inception_recommendation — pure primitive used
#     by both emit_review and emit_review_batch (T-1497 origin, reused as-is).
#
# Producer/consumer parity (T-1890): same env-var name as the Slice B Write/Edit
# hook (T-2205 — agents/context/check-inception-recommendation.py).
#
# Coverage:
#   - audit_inception_recommendation: populated/empty/template-only return codes
#   - emit_review: non-inception passes; inception+populated passes; inception+empty BLOCKS
#   - emit_review + FW_ALLOW_EMPTY_RECOMMENDATION=1: passes + log entry
#   - emit_review_batch: clean batch passes; any empty member refuses entire batch
#   - emit_review_batch + FW_ALLOW_EMPTY_RECOMMENDATION=1: passes + log per task

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    # Force a deterministic base URL — Layer 0 fast-path in _watchtower_url.
    export WATCHTOWER_URL="http://test-host:7777"

    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/task-audit.sh"
    source "$FRAMEWORK_ROOT/lib/review.sh"

    mkdir -p "$TEST_TEMP_DIR/.tasks/active"
    mkdir -p "$TEST_TEMP_DIR/.tasks/completed"
    mkdir -p "$TEST_TEMP_DIR/.context/working"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: write an inception task with the given Recommendation body.
# $1 = task_id, $2 = workflow_type (default: inception), $3 = rec_body (empty
# string means template-only — only the heading exists).
_write_task() {
    local task_id="$1"
    local workflow="${2:-inception}"
    local rec_body="${3:-}"
    local file="$TEST_TEMP_DIR/.tasks/active/${task_id}-test.md"
    cat > "$file" <<EOF
---
id: ${task_id}
name: "T-2206 fixture"
status: started-work
workflow_type: ${workflow}
owner: agent
horizon: now
created: 2026-06-05T00:00:00Z
last_update: 2026-06-05T00:00:00Z
---

# ${task_id}: T-2206 fixture

## Recommendation

${rec_body}

## Acceptance Criteria

### Human
- [ ] [REVIEW] decide
EOF
    echo "$file"
}

# ──────────────────────────────────────────────────────────────────────────────
# audit_inception_recommendation primitive
# ──────────────────────────────────────────────────────────────────────────────

@test "audit_inception_recommendation: populated Recommendation returns 0" {
    local file
    file=$(_write_task "T-7001" "inception" "**Recommendation:** GO
**Rationale:** evidence cited")
    run audit_inception_recommendation "$file"
    [ "$status" -eq 0 ]
}

@test "audit_inception_recommendation: empty Recommendation returns 1" {
    local file
    file=$(_write_task "T-7002" "inception" "")
    run audit_inception_recommendation "$file"
    [ "$status" -eq 1 ]
}

@test "audit_inception_recommendation: template-only HTML comment returns 1" {
    local file
    file=$(_write_task "T-7003" "inception" "<!-- REQUIRED before fw inception decide. Write here. -->")
    run audit_inception_recommendation "$file"
    [ "$status" -eq 1 ]
}

@test "audit_inception_recommendation: missing file returns 2" {
    run audit_inception_recommendation "/tmp/does/not/exist-T-7004.md"
    [ "$status" -eq 2 ]
}

# ──────────────────────────────────────────────────────────────────────────────
# emit_review — Slice C consumer-side gate
# ──────────────────────────────────────────────────────────────────────────────

@test "emit_review: non-inception (build) passes through silently — no Rec gate" {
    local file
    file=$(_write_task "T-7010" "build" "")
    run emit_review "T-7010" "$file"
    [ "$status" -eq 0 ]
    [[ "$output" != *"BLOCKED: Inception"* ]]
}

@test "emit_review: inception with populated Recommendation passes" {
    local file
    file=$(_write_task "T-7011" "inception" "**Recommendation:** GO
**Rationale:** evidence cited")
    run emit_review "T-7011" "$file"
    [ "$status" -eq 0 ]
    [[ "$output" != *"BLOCKED: Inception"* ]]
    [[ "$output" == *"T-7011"* ]]
}

@test "emit_review: inception with empty Recommendation BLOCKS (exit 1)" {
    local file
    file=$(_write_task "T-7012" "inception" "")
    run emit_review "T-7012" "$file"
    [ "$status" -eq 1 ]
    [[ "$output" == *"BLOCKED: Inception T-7012 has empty"* ]]
    # Block message must name bypass mechanism (T-1890 parity).
    [[ "$output" == *"FW_ALLOW_EMPTY_RECOMMENDATION=1"* ]]
    # Block message must name canonical fix path (edit Recommendation block).
    [[ "$output" == *"Recommendation"* ]]
    # Block message must cross-ref origin chain.
    [[ "$output" == *"T-2204"* ]] || [[ "$output" == *"T-2205"* ]] || [[ "$output" == *"T-679"* ]]
}

@test "emit_review: inception with template-only Recommendation BLOCKS" {
    local file
    file=$(_write_task "T-7013" "inception" "<!-- placeholder comment -->")
    run emit_review "T-7013" "$file"
    [ "$status" -eq 1 ]
    [[ "$output" == *"BLOCKED: Inception T-7013 has empty"* ]]
}

@test "emit_review: FW_ALLOW_EMPTY_RECOMMENDATION=1 bypass → exit 0 + NOTE + log" {
    local file
    file=$(_write_task "T-7014" "inception" "")
    FW_ALLOW_EMPTY_RECOMMENDATION=1 run emit_review "T-7014" "$file"
    [ "$status" -eq 0 ]
    # NOTE banner appears on bypass path.
    [[ "$output" == *"NOTE: Inception T-7014 has empty"* ]] || [[ "$output" == *"FW_ALLOW_EMPTY_RECOMMENDATION=1"* ]]
    # Tier-2 log entry written.
    local log="$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    grep -q "FW_ALLOW_EMPTY_RECOMMENDATION" "$log"
    grep -q "T-7014" "$log"
    grep -q "emit_review" "$log"
}

# ──────────────────────────────────────────────────────────────────────────────
# emit_review_batch — Slice C batch pre-pass
# ──────────────────────────────────────────────────────────────────────────────

@test "emit_review_batch: clean inception batch passes" {
    _write_task "T-7020" "inception" "**Recommendation:** GO
**Rationale:** evidence" >/dev/null
    _write_task "T-7021" "inception" "**Recommendation:** DEFER
**Rationale:** wait" >/dev/null
    run emit_review_batch T-7020 T-7021
    [ "$status" -eq 0 ]
    [[ "$output" != *"BLOCKED: batch"* ]]
    [[ "$output" == *"T-7020"* ]]
    [[ "$output" == *"T-7021"* ]]
}

@test "emit_review_batch: mixed build+inception clean batch passes" {
    _write_task "T-7022" "build" "" >/dev/null
    _write_task "T-7023" "inception" "**Recommendation:** GO
**Rationale:** evidence" >/dev/null
    run emit_review_batch T-7022 T-7023
    [ "$status" -eq 0 ]
    [[ "$output" != *"BLOCKED: batch"* ]]
}

@test "emit_review_batch: refuses entire batch when ANY inception has empty Recommendation" {
    _write_task "T-7024" "inception" "**Recommendation:** GO
**Rationale:** evidence" >/dev/null
    _write_task "T-7025" "inception" "" >/dev/null   # empty
    _write_task "T-7026" "inception" "**Recommendation:** DEFER
**Rationale:** wait" >/dev/null
    run emit_review_batch T-7024 T-7025 T-7026
    [ "$status" -eq 1 ]
    [[ "$output" == *"BLOCKED: batch contains inceptions with empty"* ]]
    [[ "$output" == *"T-7025"* ]]
    [[ "$output" == *"FW_ALLOW_EMPTY_RECOMMENDATION=1"* ]]
    # The good tasks must NOT have leaked their rows past the block.
    [[ "$output" != *"| T-7024 |"* ]]
}

@test "emit_review_batch: FW_ALLOW_EMPTY_RECOMMENDATION=1 bypass → exit 0 + log per task" {
    _write_task "T-7027" "inception" "" >/dev/null
    _write_task "T-7028" "inception" "" >/dev/null
    FW_ALLOW_EMPTY_RECOMMENDATION=1 run emit_review_batch T-7027 T-7028
    [ "$status" -eq 0 ]
    [[ "$output" == *"NOTE: batch contains inceptions with empty"* ]] || [[ "$output" == *"FW_ALLOW_EMPTY_RECOMMENDATION=1"* ]]
    # Table rendered.
    [[ "$output" == *"T-7027"* ]]
    [[ "$output" == *"T-7028"* ]]
    # Tier-2 log has one entry per empty task.
    local log="$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    [ "$(grep -c 'task:' "$log")" -ge 2 ]
    grep -q "T-7027" "$log"
    grep -q "T-7028" "$log"
    grep -q "emit_review_batch" "$log"
}

@test "emit_review_batch: build-only batch with empty bodies passes (no Rec gate on build)" {
    _write_task "T-7029" "build" "" >/dev/null
    _write_task "T-7030" "build" "" >/dev/null
    run emit_review_batch T-7029 T-7030
    [ "$status" -eq 0 ]
    [[ "$output" != *"BLOCKED"* ]]
}
