#!/usr/bin/env bats
# T-3445 — the delegated close path, end to end, on two fixtures.
#
# The classifier has its own unit tests; this file pins the thing those cannot
# see: that a criterion the classifier called `deterministic` actually reaches
# `work-completed` through the real reviewer and the real close gates, with no
# human tick anywhere in the chain. Every step is the shipped code — `fw task
# delegate`, `fw reviewer` (auto-tick v1.5, T-1985), `update-task.sh`. Nothing
# is stubbed, because the defect this guards against lives at the joins.
#
# Fixture 1 — two deterministic Human criteria. Delegate converts both, takes
#             ownership, reviewer PASSes, close moves the file to completed/.
# Fixture 2 — the same two plus one taste criterion. Delegate converts two,
#             keeps the third, leaves ownership with the operator, and the close
#             is REFUSED by the sovereignty gate.
#
# On fixture 2 and the task spec: AC 3 says the mixed fixture's close "lands
# partial-complete". It cannot, and that is not a defect in this code. The
# sovereignty gate (R-033, update-task.sh:1849) runs BEFORE the P-010 AC gate
# that sets PARTIAL_COMPLETE, so a task the delegation deliberately left
# `owner: human` is refused outright rather than reaching partial-complete —
# which is reachable only from `owner: agent`. The end state the operator sees
# is the same one partial-complete produces (active/, owner: human, the Human
# criterion open), arrived at one gate earlier. Asserted as it actually is.

load ../test_helper

FW="$BATS_TEST_DIRNAME/../../bin/fw"
UPDATE_TASK="$BATS_TEST_DIRNAME/../../agents/task-create/update-task.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" \
             "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.tasks/templates" \
             "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/episodic" \
             "$PROJECT_ROOT/bin"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    # The verification line the verb writes begins `bin/fw reviewer …`, which is
    # how it must read in a real project. Give the fixture that entry point.
    ln -sf "$FRAMEWORK_ROOT/bin/fw" "$PROJECT_ROOT/bin/fw"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_deterministic_criteria() {
    echo "- [ ] [REVIEW] Doctor names the new config key"
    echo "  **Steps:**"
    echo "  1. Run \`bin/fw doctor\`"
    echo "  **Expected:** output contains the key and exit code is 0"
    echo "  **If not:** re-run and read the first failure"
    echo "- [ ] [REVIEW] Ledger row is appended"
    echo "  **Steps:**"
    echo "  1. Run the verb once"
    echo "  **Expected:** one row appended to the ledger, exit code 0"
    echo "  **If not:** check the ledger path"
}

_make_task() {
    local id="$1" with_taste="$2"
    local f="$PROJECT_ROOT/.tasks/active/${id}-delegation-fixture.md"
    {
        echo "---"
        echo "id: $id"
        echo "name: \"T-3445 delegation fixture\""
        echo "description: \"Fixture for the delegated close path\""
        echo "status: started-work"
        echo "workflow_type: build"
        echo "owner: human"
        echo "horizon: now"
        echo "tags: []"
        echo "created: 2026-09-24T00:00:00Z"
        echo "last_update: 2026-09-24T00:00:00Z"
        echo "date_finished: null"
        echo "---"
        echo ""
        echo "# $id: T-3445 delegation fixture"
        echo ""
        echo "## Acceptance Criteria"
        echo ""
        echo "### Agent"
        echo "- [x] Fixture body is in place"
        echo ""
        echo "### Human"
        _deterministic_criteria
        if [ "$with_taste" = "taste" ]; then
            echo "- [ ] [REVIEW] The summary paragraph reads clearly"
            echo "  **Steps:**"
            echo "  1. Read the paragraph"
            echo "  **Expected:** it reads as a peer briefing, not a status dump"
            echo "  **If not:** note the sentence that stalls"
        fi
        echo ""
        echo "## Verification"
        echo ""
        echo "## Recommendation"
        echo ""
        echo "**Recommendation:** GO"
        echo ""
        echo "**Rationale:** Fixture."
        echo ""
        echo "## Updates"
    } > "$f"
    echo "$f"
}

# ── Fixture 1: fully delegable → closes with no human tick ───────────────────

@test "two deterministic Human criteria: delegate converts both and takes ownership" {
    local f; f="$(_make_task T-9001 plain)"

    run "$FW" task delegate T-9001
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "converted 2, left human 0"
    echo "$output" | grep -q "owner: human → agent"

    grep -q "^owner: agent" "$f"

    # Both criteria moved under ### Agent as [REVIEWER], unticked, verbatim.
    local agent_block
    agent_block="$(awk '/^### Agent/{f=1;next} /^### Human/{f=0} f' "$f")"
    echo "$agent_block" | grep -q '^- \[ \] \[REVIEWER\] Doctor names the new config key'
    echo "$agent_block" | grep -q '^- \[ \] \[REVIEWER\] Ledger row is appended'
    echo "$agent_block" | grep -q 'one row appended to the ledger, exit code 0'

    # Nothing left under ### Human: the count is the verdict, not a bare `!`.
    local human_left
    human_left="$(awk '/^### Human/{f=1;next} /^## /{f=0} f' "$f" | grep -c '^- \[' || true)"
    [ "$human_left" -eq 0 ]

    # The reviewer-PASS line is in ## Verification, exactly once.
    local vline
    # Anchored: the Updates entry also names the command in prose, and an
    # unanchored count would read that as a duplicate verification line.
    vline="$(grep -c '^bin/fw reviewer T-9001 >' "$f" || true)"
    [ "$vline" -eq 1 ]

    grep -q 'D-626' "$f"
    grep -q '"task":"T-9001"' "$PROJECT_ROOT/.context/working/delegations.jsonl"
}

@test "delegated task: reviewer PASS auto-ticks the converted criteria" {
    local f; f="$(_make_task T-9001 plain)"
    run "$FW" task delegate T-9001
    [ "$status" -eq 0 ]

    run "$FW" reviewer T-9001
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Overall:.*PASS"

    local ticked
    ticked="$(grep -c '^- \[x\] \[REVIEWER\]' "$f" || true)"
    [ "$ticked" -eq 2 ]
}

@test "delegated task closes with no human tick" {
    _make_task T-9001 plain > /dev/null
    run "$FW" task delegate T-9001
    [ "$status" -eq 0 ]
    run "$FW" reviewer T-9001
    [ "$status" -eq 0 ]

    run "$UPDATE_TASK" T-9001 --status work-completed
    [ "$status" -eq 0 ]

    # The file moved to completed/ — the whole point.
    local in_completed in_active
    in_completed="$(ls "$PROJECT_ROOT/.tasks/completed" | grep -c '^T-9001-' || true)"
    in_active="$(ls "$PROJECT_ROOT/.tasks/active" | grep -c '^T-9001-' || true)"
    [ "$in_completed" -eq 1 ]
    [ "$in_active" -eq 0 ]
}

@test "the close is driven by the reviewer verdict, not by delegation alone" {
    # Control leg: skip `fw reviewer`, so the converted criteria stay unticked.
    # Without this the suite could not tell "the reviewer closed it" from
    # "delegation closed it", which is the claim being made.
    _make_task T-9001 plain > /dev/null
    run "$FW" task delegate T-9001
    [ "$status" -eq 0 ]

    run "$UPDATE_TASK" T-9001 --status work-completed
    [ "$status" -ne 0 ]

    local in_active
    in_active="$(ls "$PROJECT_ROOT/.tasks/active" | grep -c '^T-9001-' || true)"
    [ "$in_active" -eq 1 ]
}

# ── Fixture 2: one carve-out → stays the operator's ──────────────────────────

@test "a taste criterion is not converted and ownership stays human" {
    local f; f="$(_make_task T-9002 taste)"

    run "$FW" task delegate T-9002
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "converted 2, left human 1"
    echo "$output" | grep -q "taste"

    grep -q "^owner: human" "$f"

    local human_left
    human_left="$(awk '/^### Human/{f=1;next} /^## /{f=0} f' "$f" | grep -c '^- \[' || true)"
    [ "$human_left" -eq 1 ]
    awk '/^### Human/{f=1;next} /^## /{f=0} f' "$f" | grep -q 'reads clearly'

    # And the refusal is named in the task's own Updates entry.
    grep -q 'taste: AC#3' "$f"
}

@test "a partially delegated task does not close: the sovereignty gate refuses it" {
    local f; f="$(_make_task T-9002 taste)"
    run "$FW" task delegate T-9002
    [ "$status" -eq 0 ]
    run "$FW" reviewer T-9002
    [ "$status" -eq 0 ]

    # The reviewer still ticks what was delegated …
    local ticked
    ticked="$(grep -c '^- \[x\] \[REVIEWER\]' "$f" || true)"
    [ "$ticked" -eq 2 ]

    # … and the task is still the operator's, so the close is refused.
    run "$UPDATE_TASK" T-9002 --status work-completed
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "Sovereignty gate"

    local in_active untouched
    in_active="$(ls "$PROJECT_ROOT/.tasks/active" | grep -c '^T-9002-' || true)"
    [ "$in_active" -eq 1 ]
    untouched="$(awk '/^### Human/{f=1;next} /^## /{f=0} f' "$f" | grep -c '^- \[ \]' || true)"
    [ "$untouched" -eq 1 ]
}

# ── Refusals ─────────────────────────────────────────────────────────────────

@test "delegate refuses an inception task with exit 2" {
    local f="$PROJECT_ROOT/.tasks/active/T-9003-inception.md"
    printf -- '---\nid: T-9003\nname: "inception fixture"\nstatus: started-work\nworkflow_type: inception\nowner: human\nhorizon: now\ncreated: 2026-09-24T00:00:00Z\nlast_update: 2026-09-24T00:00:00Z\n---\n\n## Acceptance Criteria\n\n### Agent\n\n### Human\n- [ ] [REVIEW] Doctor names the key\n  **Expected:** exit code 0\n\n## Verification\n' > "$f"

    run "$FW" task delegate T-9003
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "inception"

    # Nothing was written.
    local converted
    converted="$(grep -c 'REVIEWER' "$f" || true)"
    [ "$converted" -eq 0 ]
}

@test "delegate refuses a completed task with exit 2" {
    local f="$PROJECT_ROOT/.tasks/completed/T-9004-done.md"
    printf -- '---\nid: T-9004\nname: "completed fixture"\nstatus: work-completed\nworkflow_type: build\nowner: human\n---\n\n## Acceptance Criteria\n\n### Human\n- [ ] [REVIEW] Doctor names the key\n  **Expected:** exit code 0\n\n## Verification\n' > "$f"

    run "$FW" task delegate T-9004
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "completed"
}

@test "--dry-run classifies and writes nothing" {
    local f; f="$(_make_task T-9001 taste)"
    local before; before="$(md5sum "$f" | cut -d' ' -f1)"

    run "$FW" task delegate T-9001 --dry-run
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "converted 2, left human 1"
    echo "$output" | grep -q "nothing written"

    local after; after="$(md5sum "$f" | cut -d' ' -f1)"
    [ "$before" = "$after" ]

    local ledger
    ledger="$(ls "$PROJECT_ROOT/.context/working" | grep -c '^delegations.jsonl$' || true)"
    [ "$ledger" -eq 0 ]
}

@test "delegate is idempotent: a second run converts nothing and adds no second verification line" {
    local f; f="$(_make_task T-9001 plain)"
    run "$FW" task delegate T-9001
    [ "$status" -eq 0 ]

    run "$FW" task delegate T-9001
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "converted 0"

    local vline
    # Anchored: the Updates entry also names the command in prose, and an
    # unanchored count would read that as a duplicate verification line.
    vline="$(grep -c '^bin/fw reviewer T-9001 >' "$f" || true)"
    [ "$vline" -eq 1 ]
}
