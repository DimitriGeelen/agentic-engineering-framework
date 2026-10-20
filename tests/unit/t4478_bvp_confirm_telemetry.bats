#!/usr/bin/env bats
# T-4478: `fw bvp confirm` appends one row per confirmation to an append-only NDJSON
# ledger (adapted from 010-termlink T-3176, proposal 348). The proposal is cleared on
# confirm (M3), so without this row the estimator-guess vs confirmed pair is lost.
# Every test points FW_BVP_TELEMETRY_PATH into the temp dir: the real ledger is
# append-only and a fixture row written into it could never be removed.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t4478-XXXXXX)"
    export TEST_TEMP_DIR
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.tasks/active"
    LEDGER="$TEST_TEMP_DIR/ledger.ndjson"
    export FW_BVP_TELEMETRY_PATH="$LEDGER"
    unset FW_REQUIRE_BVP_CONFIRM_APPROVAL
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# $1 = rationale line ('' = no rationale key)
_fixture() {
    local rat="$1"
    {
        cat <<'EOF'
---
id: T-9999
name: "fixture"
status: started-work
bvp_scores_proposed:
  - ts: '2026-10-20T00:00:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
EOF
        [ -n "$rat" ] && echo "    rationale: $rat"
        cat <<'EOF'
    rubric_sha: abc123
---

# T-9999 fixture
EOF
    } > "$PROJ/.tasks/active/T-9999-fixture.md"
}

_field() {  # $1 = python expression over `r` (last ledger row)
    python3 -c "import json,sys; r=[json.loads(l) for l in open(sys.argv[1])][-1]; print($1)" "$LEDGER"
}

@test "t4478:t1 agent confirm with override writes one row with proposed, delta and provenance" {
    _fixture "D1=3 (body:structural-gate); D2=0 (no-signal)"
    CLAUDECODE=1 PROJECT_ROOT="$PROJ" run "$FRAMEWORK_ROOT/bin/fw" bvp confirm T-9999 --override D2=4
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$LEDGER")" -eq 1 ]
    [ "$(_field "r['task']")" = "T-9999" ]
    [ "$(_field "r['confirmed_via']")" = "agent" ]
    [ "$(_field "r['proposed']")" = "{'D1': 3, 'D2': 0}" ]
    [ "$(_field "r['confirmed']")" = "{'D1': 3, 'D2': 4}" ]
    [ "$(_field "r['delta_vs_proposed']")" = "{'D2': [0, 4]}" ]
    [ "$(_field "r['proposer_exact']")" = "False" ]
    [ "$(_field "r['no_signal_count']")" = "1" ]
    [ "$(_field "r['driver_count']")" = "2" ]
    [ "$(_field "r['all_no_signal']")" = "False" ]
    [ "$(_field "r['estimator']")" = "bvp-estimator-v1-heuristic" ]
    [ "$(_field "r['rubric_sha']")" = "abc123" ]
}

@test "t4478:t2 all-no-signal proposal confirmed unchanged is flagged, not recorded as plain accuracy" {
    _fixture "D1=3 (no-signal); D2=0 (no-signal)"
    PROJECT_ROOT="$PROJ" run "$FRAMEWORK_ROOT/bin/fw" bvp confirm T-9999 --i-am-human
    [ "$status" -eq 0 ]
    [ "$(_field "r['confirmed_via']")" = "human" ]
    [ "$(_field "r['proposer_exact']")" = "True" ]
    [ "$(_field "r['all_no_signal']")" = "True" ]
}

@test "t4478:t3 missing rationale logs no_signal_count null (not measured), not 0" {
    _fixture ""
    PROJECT_ROOT="$PROJ" run "$FRAMEWORK_ROOT/bin/fw" bvp confirm T-9999 --i-am-human
    [ "$status" -eq 0 ]
    [ "$(_field "r['no_signal_count']")" = "None" ]
    [ "$(_field "r['all_no_signal']")" = "None" ]
}

@test "t4478:t4 sticky skip (D-661 leg 3) writes no row" {
    _fixture "D1=3 (no-signal); D2=0 (no-signal)"
    PROJECT_ROOT="$PROJ" run "$FRAMEWORK_ROOT/bin/fw" bvp confirm T-9999 --i-am-human
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$LEDGER")" -eq 1 ]
    # re-propose, then an agent confirm must yield to the human-confirmed values
    python3 - "$PROJ/.tasks/active/T-9999-fixture.md" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace("bvp_scores_proposed: []",
    "bvp_scores_proposed:\n  - scores: {D1: 1, D2: 1}\n    rationale: x")
open(p, "w").write(s)
PY
    CLAUDECODE=1 PROJECT_ROOT="$PROJ" run "$FRAMEWORK_ROOT/bin/fw" bvp confirm T-9999
    [ "$status" -eq 0 ]
    [[ "$output" == *"Existing scores kept"* ]]
    [ "$(wc -l < "$LEDGER")" -eq 1 ]
}

@test "t4478:t5 unwritable ledger exits 1 and names the ledger on stderr" {
    _fixture "D1=3 (no-signal); D2=0 (no-signal)"
    mkdir -p "$TEST_TEMP_DIR/blocker"
    export FW_BVP_TELEMETRY_PATH="$TEST_TEMP_DIR/blocker"   # a directory: open('a') fails
    PROJECT_ROOT="$PROJ" run "$FRAMEWORK_ROOT/bin/fw" bvp confirm T-9999 --i-am-human
    [ "$status" -eq 1 ]
    [[ "$output" == *"telemetry row could NOT be written"* ]]
    [[ "$output" == *"Ledger: $TEST_TEMP_DIR/blocker"* ]]
}
