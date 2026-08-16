#!/usr/bin/env bats
# T-3027 (OBS-276): `tasks_active:` must mean active.
#
# The field was built by listing `.tasks/active/*.md` and reading `id:`, never
# `status:`. But `.tasks/active/` is a directory, not a state — it holds captured,
# started-work, issues, and partial-complete (work-completed, awaiting a human)
# side by side. The field therefore asserted ~119 tasks were active when ~37 were
# in flight.
#
# These tests build a real `.tasks/active/` with one task per status and assert
# each lands in exactly one bucket. The union check is the important one: it is
# what stops a future "just filter it" change from silently dropping the parked
# and awaiting-review tasks on the floor.

setup() {
    TMP="$(mktemp -d)"
    export TMP
    export TASKS_DIR="$TMP/.tasks"
    mkdir -p "$TASKS_DIR/active"

    # One task per status the directory actually contains.
    _mk T-9001 started-work
    _mk T-9002 issues
    _mk T-9003 captured
    _mk T-9004 work-completed

    # Source only the classifier out of handover.sh. The function is
    # self-contained (reads $TASKS_DIR, sets four globals), so extracting it
    # avoids running the whole generator for a unit test.
    HANDOVER_SH="${BATS_TEST_DIRNAME}/../../agents/handover/handover.sh"
    eval "$(sed -n '/^classify_active_tasks() {/,/^}/p' "$HANDOVER_SH")"
}

teardown() {
    cd / || true
    rm -rf "$TMP"
}

_mk() {
    cat > "$TASKS_DIR/active/$1-slug.md" <<EOF
---
id: $1
name: fixture $1
status: $2
workflow_type: build
---
EOF
}

# A task file with no status: line at all — a parse failure, not a state.
_mk_no_status() {
    cat > "$TASKS_DIR/active/$1-slug.md" <<EOF
---
id: $1
name: fixture $1
workflow_type: build
---
EOF
}

@test "the classifier extracts cleanly from handover.sh" {
    # Guards the sed extraction above: if the function is renamed or reshaped,
    # every other test would pass vacuously against an empty eval.
    run type -t classify_active_tasks
    [ "$output" = "function" ]
}

@test "started-work and issues are the only things called active" {
    classify_active_tasks
    [ "$ACTIVE_TASKS" = "T-9001, T-9002" ]
}

@test "a captured task is parked, not active" {
    classify_active_tasks
    [ "$PARKED_TASKS" = "T-9003" ]
    [[ "$ACTIVE_TASKS" != *"T-9003"* ]]
}

@test "a partial-complete task is awaiting review, not active" {
    # work-completed still sitting in active/ is the partial-complete state:
    # agent ACs done, human ACs outstanding. It is not live work.
    classify_active_tasks
    [ "$AWAITING_REVIEW_TASKS" = "T-9004" ]
    [[ "$ACTIVE_TASKS" != *"T-9004"* ]]
}

@test "a missing status is reported as unknown, never defaulted to active" {
    # The whole point: a parse failure must not become a live-work assertion.
    _mk_no_status T-9005
    classify_active_tasks
    [ "$UNKNOWN_STATUS_TASKS" = "T-9005" ]
    [[ "$ACTIVE_TASKS" != *"T-9005"* ]]
}

@test "the four buckets partition the directory — nothing dropped, nothing doubled" {
    _mk_no_status T-9005
    classify_active_tasks
    all="$ACTIVE_TASKS, $PARKED_TASKS, $AWAITING_REVIEW_TASKS, $UNKNOWN_STATUS_TASKS"
    # shellcheck disable=SC2001
    got=$(echo "$all" | tr ',' '\n' | sed 's/ //g' | grep -c '^T-')
    want=$(ls "$TASKS_DIR/active"/*.md | wc -l | tr -d ' ')
    [ "$got" -eq "$want" ]

    for t in T-9001 T-9002 T-9003 T-9004 T-9005; do
        n=$(echo "$all" | tr ',' '\n' | sed 's/ //g' | grep -c "^${t}$")
        [ "$n" -eq 1 ]
    done
}

@test "an empty active directory yields four empty lists, not an error" {
    rm -f "$TASKS_DIR/active"/*.md
    classify_active_tasks
    [ -z "$ACTIVE_TASKS" ]
    [ -z "$PARKED_TASKS" ]
    [ -z "$AWAITING_REVIEW_TASKS" ]
    [ -z "$UNKNOWN_STATUS_TASKS" ]
}

@test "both emission sites carry the sibling fields" {
    # Guards the wiring, not just the classifier. The checkpoint handover and the
    # full handover are separate heredocs ~350 lines apart; fixing one and not the
    # other is exactly how this defect would come back.
    run grep -c '^tasks_parked: \[\$PARKED_TASKS\]' \
        "${BATS_TEST_DIRNAME}/../../agents/handover/handover.sh"
    [ "$output" -eq 2 ]

    run grep -c '^tasks_awaiting_review: \[\$AWAITING_REVIEW_TASKS\]' \
        "${BATS_TEST_DIRNAME}/../../agents/handover/handover.sh"
    [ "$output" -eq 2 ]
}

@test "against the real .tasks/active, active count equals started-work + issues" {
    # The fixtures above prove the rule; this proves it holds on the actual corpus,
    # which is where the 119-vs-37 discrepancy lived. Independent oracle: the
    # classifier's output is compared against a grep that does not go through it.
    real="${BATS_TEST_DIRNAME}/../../.tasks"
    [ -d "$real/active" ] || skip "no .tasks/active in this checkout"

    TASKS_DIR="$real"
    classify_active_tasks

    got=$(echo "$ACTIVE_TASKS" | grep -o 'T-[0-9]*' | wc -l | tr -d ' ')
    sw=$(grep -l '^status: started-work' "$real/active"/*.md 2>/dev/null | wc -l | tr -d ' ')
    iss=$(grep -l '^status: issues' "$real/active"/*.md 2>/dev/null | wc -l | tr -d ' ')
    [ "$got" -eq "$((sw + iss))" ]
}

@test "no emission site rebuilds the list by directory listing" {
    # The old shape was a bare `for f in $TASKS_DIR/active/*.md` accumulating into
    # ACTIVE_TASKS. If it reappears anywhere, the classifier is being bypassed.
    run grep -c 'ACTIVE_TASKS="\$ACTIVE_TASKS\$task_id, "' \
        "${BATS_TEST_DIRNAME}/../../agents/handover/handover.sh"
    [ "$output" -eq 1 ]   # only inside classify_active_tasks
}
