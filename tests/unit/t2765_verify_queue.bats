#!/usr/bin/env bats
# T-2765 — `fw verify-queue`: re-run stored ## Verification for the human review queue.
#
# CTL-013 re-runs stored verification over the latest 3 files in .tasks/completed/.
# The review queue lives in .tasks/active/ — 221 tasks at filing — and was outside
# every rail's population, so a block could rot after completion and stay red until
# the operator tripped it at close (L-539; T-2764 found two, red for a week).
#
# The two properties worth pinning are not "does it run commands" but the two ways
# this rail could quietly become the defect it was built to catch:
#   * it must draw its population from the ONE predicate that defines the queue,
#   * it must extract blocks with the ONE shared extractor.
# A second copy of either is how the populations drift apart again.

load ../test_helper

VQ="$FRAMEWORK_ROOT/lib/verify_queue.py"
PORTLIB="$FRAMEWORK_ROOT/lib/verification-port.sh"

# ── helpers ───────────────────────────────────────────────────────────────────

# A queue task = one with an unchecked ### Human AC (the canonical predicate,
# count_unchecked_human_acs, shared with Watchtower /approvals since T-2075).
make_queue_task() {
    local project_dir="$1" task_id="$2" verification="$3"
    local file="$project_dir/.tasks/active/${task_id}-vq.md"
    cat > "$file" <<EOF
---
id: ${task_id}
name: "verify-queue fixture"
description: "test"
status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
related_tasks: []
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
date_finished: 2026-01-01T00:00:00Z
---

# ${task_id}: verify-queue fixture

## Context

Test.

## Acceptance Criteria

### Agent
- [x] agent criterion

### Human
- [ ] [REVIEW] human criterion

## Verification

${verification}

## Updates
EOF
    echo "$file"
}

run_vq() {   # run_vq <project> <args...>
    local project="$1"; shift
    run env PROJECT_ROOT="$project" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        FW_VERIFY_QUEUE_TIMEOUT=20 python3 "$VQ" "$@"
}

# ── the extractor fix (found by running the real queue through it) ────────────

# Task files written before the `#`-comment template used <!-- ... --> blocks in
# this section. The shared extractor did not strip them, so every line of that
# prose came back as a command: T-558 reported "5/5 commands failing" for a
# section that is empty. The gate (update-task.sh) and CTL-013 both strip it —
# this helper's own comment claimed parity with the gate and did not have it.
@test "T-2765: extract_verification_block strips HTML comment blocks" {
    PROJECT="$(create_test_project)"
    local f
    f="$(make_queue_task "$PROJECT" T-9001 '<!-- Shell commands that MUST pass.
     Lines starting with # are comments.
-->')"
    run bash -c "source '$PORTLIB'; extract_verification_block '$f'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-2765: extract_verification_block still returns real commands" {
    PROJECT="$(create_test_project)"
    local f
    f="$(make_queue_task "$PROJECT" T-9002 '<!-- template prose -->
true')"
    run bash -c "source '$PORTLIB'; extract_verification_block '$f'"
    [ "$output" = "true" ]
}

# ── reuse, not reimplementation ───────────────────────────────────────────────

# This is the AC that matters six months from now. If someone "simplifies" the
# subprocess hop into an inline regex, this rail becomes the fourth extractor and
# starts disagreeing with the gate — the exact shape of the bug it was built to
# find. Pinned structurally: the module must call the shared function, and must
# not carry its own block-slicing.
@test "T-2765: verify_queue calls the shared extractor rather than copying it" {
    grep -q 'extract_verification_block' "$VQ"
    grep -q 'verification-port.sh' "$VQ"
    ! grep -q "## Verification'\?,/\^## " "$VQ"
}

@test "T-2765: population comes from review-queue --ids, not a local status scan" {
    grep -q 'review-queue' "$VQ"
    grep -q -- '--ids' "$VQ"
    # No second definition of "awaiting human review" inside this module.
    ! grep -q 'owner:\\s*human' "$VQ"
}

@test "T-2765: review-queue --ids emits bare task ids only" {
    run bash -c "cd '$FRAMEWORK_ROOT' && bin/fw review-queue --ids"
    [ "$status" -eq 0 ]
    # Every non-empty line is a bare T-NNN — no verdict columns, no ANSI.
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        [[ "$line" =~ ^T-[0-9]+$ ]]
    done <<< "$output"
}

# ── verdicts ──────────────────────────────────────────────────────────────────

@test "T-2765: a green block reports PASS and exits 0" {
    PROJECT="$(create_test_project)"
    make_queue_task "$PROJECT" T-9010 'true' > /dev/null
    run_vq "$PROJECT" --task T-9010
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
    [[ "$output" == *"T-9010"* ]]
}

@test "T-2765: a red block exits 1 and names the failing command" {
    PROJECT="$(create_test_project)"
    make_queue_task "$PROJECT" T-9011 'test 1 = 2' > /dev/null
    run_vq "$PROJECT" --task T-9011
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
    # Actionable without re-deriving which line broke.
    [[ "$output" == *"test 1 = 2"* ]]
}

@test "T-2765: an empty block reports NONE, not a pass and not a failure" {
    PROJECT="$(create_test_project)"
    make_queue_task "$PROJECT" T-9012 '<!-- nothing here -->' > /dev/null
    run_vq "$PROJECT" --task T-9012
    [ "$status" -eq 0 ]
    [[ "$output" == *"NONE"* ]]
}

# A skip that reads as a pass is the vacuous-green class this rail removes.
@test "T-2765: an unsafe line is SKIPPED, never counted as passed" {
    PROJECT="$(create_test_project)"
    make_queue_task "$PROJECT" T-9013 'fw audit' > /dev/null
    run_vq "$PROJECT" --task T-9013
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
    [[ "$output" != *"PASS"* ]]
}

# A timeout is absence of evidence, not evidence of failure. Collapsing the two
# would put L-539's own defect inside the rail built to report it.
@test "T-2765: a timeout is reported over-budget and not counted red" {
    PROJECT="$(create_test_project)"
    make_queue_task "$PROJECT" T-9014 'sleep 30' > /dev/null
    run env PROJECT_ROOT="$PROJECT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        FW_VERIFY_QUEUE_TIMEOUT=2 python3 "$VQ" --task T-9014
    [ "$status" -eq 0 ]
    [[ "$output" == *"TIME"* ]]
    [[ "$output" == *"0 red"* ]]
}

@test "T-2765: verification runs from PROJECT_ROOT so self-references resolve (L-356)" {
    PROJECT="$(create_test_project)"
    make_queue_task "$PROJECT" T-9015 'test -f .tasks/active/T-9015-vq.md' > /dev/null
    run_vq "$PROJECT" --task T-9015
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
}

# ── rotation ──────────────────────────────────────────────────────────────────

# A fixed head-of-list is how CTL-013's top-3 window let the tail rot. The cursor
# has to advance, and it has to survive the process that wrote it.
@test "T-2765: rotation state is written and advances between runs" {
    PROJECT="$(create_test_project)"
    make_queue_task "$PROJECT" T-9020 'true' > /dev/null
    make_queue_task "$PROJECT" T-9021 'true' > /dev/null
    run_vq "$PROJECT" --task T-9020
    [ "$status" -eq 0 ]
    local state="$PROJECT/.context/working/.verify-queue-state.json"
    [ -f "$state" ]
    grep -q 'T-9020' "$state"
    if grep -q 'T-9021' "$state"; then false; fi
    run_vq "$PROJECT" --task T-9021
    grep -q 'T-9021' "$state"
}

@test "T-2765: select() puts never-checked tasks ahead of checked ones" {
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT/lib')
import verify_queue as vq
ids = ['T-1', 'T-2', 'T-3']
state = {'T-1': {'ts': 500}, 'T-2': {'ts': 100}}
print(','.join(vq.select(ids, state, 3)))
"
    [ "$status" -eq 0 ]
    # T-3 never checked (ts 0) → first; then T-2 (older) then T-1.
    [ "$output" = "T-3,T-2,T-1" ]
}
