#!/usr/bin/env bats
# T-1425 / G-059: Cross-project triple dedup in lib/pickup.sh
#
# Envelope-hash dedup misses 'same bug, different bytes' retries from
# external sources. Triple dedup keys on (source.project, source.task_id, type)
# and routes matches to auto-deferred/ with a breadcrumb. Empty task_id falls
# through; `supersedes: T-XXX` bypasses.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    export PICKUP_DIR="$TEST_TEMP_DIR/.context/pickup"
    export PICKUP_INBOX="$PICKUP_DIR/inbox"
    export PICKUP_PROCESSED="$PICKUP_DIR/processed"
    export PICKUP_REJECTED="$PICKUP_DIR/rejected"
    export PICKUP_AUTO_DEFERRED="$PICKUP_DIR/auto-deferred"
    export PICKUP_DEDUP_LOG="$PICKUP_DIR/dedup.log"

    mkdir -p "$PICKUP_INBOX" "$PICKUP_PROCESSED" "$PICKUP_REJECTED" \
             "$PICKUP_AUTO_DEFERRED" "$TEST_TEMP_DIR/.tasks/active"

    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/pickup.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build an envelope with explicit triple fields
_envelope() {
    local file="$1" type="$2" project="$3" task_id="$4" supersedes="${5:-}"
    {
        echo "pickup_id: P-001"
        echo "version: 1"
        echo "type: $type"
        [ -n "$supersedes" ] && echo "supersedes: $supersedes"
        echo "source:"
        echo "  project: \"$project\""
        echo "  task_id: \"$task_id\""
        echo "  agent: \"claude-code\""
        echo "  timestamp: \"2026-04-24T12:00:00Z\""
        echo "payload:"
        echo "  summary: \"retry envelope\""
        echo "  priority: medium"
    } > "$file"
}

# Seed an active inception task as if a prior envelope had been processed.
# Frontmatter mirrors what pickup_inject_origin_frontmatter produces.
_seed_active_task() {
    local id="$1" type="$2" project="$3" task_id="$4"
    local path="$TEST_TEMP_DIR/.tasks/active/${id}-pickup-retry.md"
    cat > "$path" <<EOF
---
id: $id
name: "Pickup: retry envelope (from $project)"
status: captured
workflow_type: inception
owner: agent
horizon: next
tags: [pickup, $type]
components: []
related_tasks: []
created: 2026-04-22T10:00:00Z
last_update: 2026-04-22T10:00:00Z
date_finished: null
source_task_id_in_origin: $task_id
source_project_in_origin: "$project"
---

# $id: Prior pickup
EOF
}

@test "triple dedup: matching triple returns the blocking T-XXX" {
    _seed_active_task "T-900" "bug-report" "termlink" "T-1125"

    local env="$PICKUP_INBOX/P-retry.yaml"
    _envelope "$env" "bug-report" "termlink" "T-1125"

    run pickup_dedup_triple_check "$env"
    [ "$status" -eq 0 ]
    [ "$output" = "T-900" ]
}

@test "triple dedup: no match returns 1 (not a collision)" {
    _seed_active_task "T-900" "bug-report" "termlink" "T-1125"

    local env="$PICKUP_INBOX/P-new.yaml"
    _envelope "$env" "bug-report" "termlink" "T-9999"  # different task_id

    run pickup_dedup_triple_check "$env"
    [ "$status" -eq 1 ]
}

@test "triple dedup: empty source.task_id falls through (returns 1)" {
    _seed_active_task "T-900" "bug-report" "vinix24" ""

    local env="$PICKUP_INBOX/P-empty.yaml"
    _envelope "$env" "bug-report" "vinix24" ""

    run pickup_dedup_triple_check "$env"
    [ "$status" -eq 1 ]
}

@test "triple dedup: supersedes: T-XXX bypasses check (returns 1)" {
    _seed_active_task "T-900" "bug-report" "termlink" "T-1125"

    local env="$PICKUP_INBOX/P-super.yaml"
    _envelope "$env" "bug-report" "termlink" "T-1125" "T-900"

    run pickup_dedup_triple_check "$env"
    [ "$status" -eq 1 ]
}

@test "triple dedup: different type with same project+task is NOT a collision" {
    _seed_active_task "T-900" "bug-report" "termlink" "T-1125"

    local env="$PICKUP_INBOX/P-other.yaml"
    _envelope "$env" "learning" "termlink" "T-1125"

    run pickup_dedup_triple_check "$env"
    [ "$status" -eq 1 ]
}

@test "process: triple-collision envelope routes to auto-deferred with breadcrumb" {
    _seed_active_task "T-900" "bug-report" "termlink" "T-1125"

    local env="$PICKUP_INBOX/P-050-bug.yaml"
    _envelope "$env" "bug-report" "termlink" "T-1125"

    run pickup_process_one "$env" false
    [ "$status" -eq 0 ]

    # Envelope moved to auto-deferred
    [ -f "$PICKUP_AUTO_DEFERRED/P-050-bug.yaml" ]
    [ ! -f "$env" ]

    # Breadcrumb exists and names the blocking task
    local crumb="$PICKUP_AUTO_DEFERRED/P-050-bug.yaml.breadcrumb.yaml"
    [ -f "$crumb" ]
    grep -q "^blocking_task: T-900$" "$crumb"
    grep -q "^reason: triple-dedup$" "$crumb"
}

@test "process: supersedes bypass routes through to normal processing (not auto-deferred)" {
    _seed_active_task "T-900" "bug-report" "termlink" "T-1125"

    local env="$PICKUP_INBOX/P-051-super.yaml"
    _envelope "$env" "bug-report" "termlink" "T-1125" "T-900"

    # Dry-run avoids the fw task create path in the test harness
    run pickup_process_one "$env" true
    [ "$status" -eq 0 ]
    # Not in auto-deferred (bypass worked)
    [ ! -f "$PICKUP_AUTO_DEFERRED/P-051-super.yaml" ]
    # Output should NOT mention AUTO-DEFER
    [[ "$output" != *"AUTO-DEFER"* ]]
}

# T-1426 / B3: operator list surface for auto-deferred envelopes

@test "do_pickup auto-deferred: empty directory shows explicit empty message" {
    run do_pickup auto-deferred
    [ "$status" -eq 0 ]
    [[ "$output" == *"Empty — no envelopes auto-deferred"* ]]
}

@test "do_pickup auto-deferred: lists envelope with blocking task, reason, timestamp" {
    _seed_active_task "T-900" "bug-report" "termlink" "T-1125"
    local env="$PICKUP_INBOX/P-070-dup.yaml"
    _envelope "$env" "bug-report" "termlink" "T-1125"

    # Drive the real process path (not dry-run) to land breadcrumb + file
    pickup_process_one "$env" false

    run do_pickup auto-deferred
    [ "$status" -eq 0 ]
    [[ "$output" == *"P-070-dup.yaml"* ]]
    [[ "$output" == *"blocked-by=T-900"* ]]
    [[ "$output" == *"reason=triple-dedup"* ]]
    # Breadcrumb sidecar must NOT appear as a separate list entry
    [[ "$output" != *"P-070-dup.yaml.breadcrumb.yaml"* ]]
}

@test "do_pickup status: counts auto-deferred envelopes separately" {
    _seed_active_task "T-900" "bug-report" "termlink" "T-1125"
    local env="$PICKUP_INBOX/P-080-dup.yaml"
    _envelope "$env" "bug-report" "termlink" "T-1125"
    pickup_process_one "$env" false

    run do_pickup status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-deferred: 1"* ]]
}
