#!/usr/bin/env bats
# T-3445 — the delegated close path, end to end, on two fixtures.
# Rewritten for T-4916 (operator 2026-10-30, "b"): deterministic criteria are no
# longer converted to `[REVIEWER]` Agent criteria for the static-scan auto-tick
# (T-4778 left converted criteria with no close path). They stay under ### Human,
# reviewer-judged, and close on a recorded green verdict through the verdict ledger
# (test_t3579_verdict_ledger.py pins that half). Every step here is the shipped
# code — `fw task delegate`, `fw reviewer`, `update-task.sh`. Nothing is stubbed.
#
# Fixture 1 — two deterministic Human criteria. Delegate reports both
#             reviewer-judged and writes nothing; the static scan ticks nothing;
#             the close is refused until a verdict exists.
# Fixture 2 — the same two plus one taste criterion: all three reviewer-judged,
#             ownership stays with the operator, and the close is REFUSED by the
#             sovereignty gate.
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

# ── T-4916: deterministic criteria are reviewer-judged, never converted ─────
#
# Operator ruling 2026-10-30 ("b"). These criteria used to convert to `[REVIEWER]`
# Agent criteria for the T-1985 auto-tick; T-4778 narrowed auto-tick to named
# scanner checks, which left converted criteria with no close path. They now stay
# under ### Human and close on a recorded green verdict (`fw reviewer judge` and the
# verdict ledger, pinned by test_t3579_verdict_ledger.py). Rerouting criteria an
# earlier delegation converted: t4916_delegate_reroute.bats.

@test "two deterministic Human criteria: delegate reports both reviewer-judged and writes nothing" {
    local f; f="$(_make_task T-9001 plain)"
    local before; before="$(md5sum < "$f")"

    run "$FW" task delegate T-9001
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "converted 0, reviewer-judged 2, left human 0"
    echo "$output" | grep -q "reviewer judge T-9001"
    [ "$(md5sum < "$f")" = "$before" ]
    grep -q "^owner: human" "$f"
}

@test "the static reviewer scan ticks no reviewer-judged criterion" {
    local f; f="$(_make_task T-9001 plain)"
    run "$FW" task delegate T-9001
    [ "$status" -eq 0 ]
    run "$FW" reviewer T-9001
    local ticked
    ticked="$(awk '/^### Human/{f=1;next} /^## /{f=0} f' "$f" | grep -c '^- \[x\]' || true)"
    [ "$ticked" -eq 0 ]
}

@test "the close is refused while reviewer-judged criteria have no verdict" {
    # Without a recorded green verdict nothing ticks them, so delegation alone can
    # never close the task — the claim the verdict ledger exists to make true.
    _make_task T-9001 plain > /dev/null
    run "$FW" task delegate T-9001
    [ "$status" -eq 0 ]

    run "$UPDATE_TASK" T-9001 --status work-completed
    [ "$status" -ne 0 ]

    local in_active
    in_active="$(ls "$PROJECT_ROOT/.tasks/active" | grep -c '^T-9001-' || true)"
    [ "$in_active" -eq 1 ]
}

# ── Fixture 2: taste beside deterministic → all reviewer-judged ─────────────

@test "a taste criterion beside deterministic ones: all three reviewer-judged, owner stays human" {
    local f; f="$(_make_task T-9002 taste)"

    run "$FW" task delegate T-9002
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "converted 0, reviewer-judged 3, left human 0"
    echo "$output" | grep -q "taste"

    grep -q "^owner: human" "$f"

    local human_left
    human_left="$(awk '/^### Human/{f=1;next} /^## /{f=0} f' "$f" | grep -c '^- \[ \]' || true)"
    [ "$human_left" -eq 3 ]
}

@test "a task with open reviewer-judged criteria does not close: the sovereignty gate refuses it" {
    local f; f="$(_make_task T-9002 taste)"
    run "$FW" task delegate T-9002
    [ "$status" -eq 0 ]
    run "$FW" reviewer T-9002

    run "$UPDATE_TASK" T-9002 --status work-completed
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "Sovereignty gate"

    local in_active untouched
    in_active="$(ls "$PROJECT_ROOT/.tasks/active" | grep -c '^T-9002-' || true)"
    [ "$in_active" -eq 1 ]
    untouched="$(awk '/^### Human/{f=1;next} /^## /{f=0} f' "$f" | grep -c '^- \[ \]' || true)"
    [ "$untouched" -eq 3 ]
}

# ── Refusals ─────────────────────────────────────────────────────────────────

@test "T-3557: a reviewer-judged criterion is reported judgeable, never converted or ticked" {
    local f; f="$(_make_task T-9002 taste)"
    local before; before="$(md5sum < "$f")"

    run "$FW" task delegate T-9002 --dry-run
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "reviewer-judged (fw reviewer judge)"
    [ "$(md5sum < "$f")" = "$before" ]

    run "$FW" task delegate T-9002 --dry-run --json
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['reviewer_judgeable']==[1,2,3], d"

    # The judged criterion stays unticked under ### Human after a real run.
    run "$FW" task delegate T-9002
    [ "$status" -eq 0 ]
    awk '/^### Human/{f=1;next} /^## /{f=0} f' "$f" | grep -q '^- \[ \].*reads clearly'
}

@test "delegate classifies an inception task (dry-run --json): valid JSON, no mutation, none converted" {
    local f="$PROJECT_ROOT/.tasks/active/T-9003-inception.md"
    printf -- '---\nid: T-9003\nname: "inception fixture"\nstatus: started-work\nworkflow_type: inception\nowner: human\nhorizon: now\ncreated: 2026-09-24T00:00:00Z\nlast_update: 2026-09-24T00:00:00Z\n---\n\n## Acceptance Criteria\n\n### Agent\n\n### Human\n- [ ] [REVIEW] Doctor names the key\n  **Expected:** exit code 0\n- [ ] [REVIEW] Force push the release branch\n  **Expected:** remote updated\n\n## Verification\n' > "$f"
    local before; before="$(cksum < "$f")"

    run "$FW" task delegate T-9003 --dry-run --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c '
import json, sys
r = json.load(sys.stdin)
assert r["task"] == "T-9003"
assert r["dry_run"] is True
assert r["converted"] == [], r["converted"]
assert len(r["refused"]) == 2, r["refused"]
# routine criterion: reviewer-judged (inception-decision), never converted
assert r["refused"][0]["delegation_class"] == "REVIEWER-JUDGES", r["refused"][0]
# risky criterion: risk class outranks the inception routing, stays operator-only
assert r["refused"][1]["delegation_class"] == "OPERATOR-ONLY", r["refused"][1]
assert r["reviewer_judged_count"] == 1
'
    [ "$(cksum < "$f")" = "$before" ]
}

@test "delegate on an inception task (real run) converts nothing and writes nothing" {
    local f="$PROJECT_ROOT/.tasks/active/T-9004-inception.md"
    printf -- '---\nid: T-9004\nname: "inception fixture 2"\nstatus: started-work\nworkflow_type: inception\nowner: human\nhorizon: now\ncreated: 2026-09-24T00:00:00Z\nlast_update: 2026-09-24T00:00:00Z\n---\n\n## Acceptance Criteria\n\n### Agent\n\n### Human\n- [ ] [REVIEW] Doctor names the key\n  **Expected:** exit code 0\n\n## Verification\n' > "$f"
    local before; before="$(cksum < "$f")"

    run "$FW" task delegate T-9004
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "reviewer-judged 1"
    [ "$(cksum < "$f")" = "$before" ]
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
    echo "$output" | grep -q "converted 0, reviewer-judged 3, left human 0"
    echo "$output" | grep -q "nothing written"

    local after; after="$(md5sum "$f" | cut -d' ' -f1)"
    [ "$before" = "$after" ]

    local ledger
    ledger="$(ls "$PROJECT_ROOT/.context/working" | grep -c '^delegations.jsonl$' || true)"
    [ "$ledger" -eq 0 ]
}

@test "delegate is idempotent and never writes a reviewer-PASS verification line (T-4916)" {
    local f; f="$(_make_task T-9001 plain)"
    run "$FW" task delegate T-9001
    [ "$status" -eq 0 ]

    run "$FW" task delegate T-9001
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "converted 0"

    local vline
    vline="$(grep -c '^bin/fw reviewer T-9001 >' "$f" || true)"
    [ "$vline" -eq 0 ]
}
