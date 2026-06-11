#!/usr/bin/env bats
# T-2331 (T-2330 S1): `fw bvp driver --propose` non-Sovereign verb.
#
# Verifies the propose-queue write primitive that lands proposals into
# .context/bvp-driver-proposals.jsonl as append-only rows. The Sovereign
# Approve action (Watchtower /bvp/proposed → `fw bvp driver --add
# --from-watchtower`) is S2's job; this slice ships the storage primitive
# and bats coverage.
#
# Covers: append behaviour, non-Sovereign under CLAUDECODE=1, race-free
# append for same driver-id, rationale length validation, weight validation,
# slug validation, JSON well-formedness.

load ../test_helper

setup() {
    unset PROJECT_ROOT
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    # Seed a minimal policy file so PROJECT_ROOT resolves cleanly.
    mkdir -p "$TEST_TEMP_DIR/policy"
    env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --init >/dev/null 2>&1 || true
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ------------------------------------------------------------------ append shape

@test "T-2331: propose appends a JSON row to .context/bvp-driver-proposals.jsonl" {
    run env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --propose "V_TEST_DRIVER" --weight 5 --rationale "Test driver for the T-2331 bats suite ≥30 chars."
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "proposal P-"
    echo "$output" | grep -q "state: pending"

    [ -f "$TEST_TEMP_DIR/.context/bvp-driver-proposals.jsonl" ]
    # Single line, valid JSON
    [ "$(wc -l < "$TEST_TEMP_DIR/.context/bvp-driver-proposals.jsonl")" -eq 1 ]
    python3 -c "import json,sys; row=json.loads(open('$TEST_TEMP_DIR/.context/bvp-driver-proposals.jsonl').read().strip()); assert row['name']=='V_TEST_DRIVER'; assert row['weight']==5; assert row['state']=='pending'; assert row['id'].startswith('P-'); assert len(row['rationale'])>=30"
}

# ----------------------------------------------------- non-Sovereign under agent

@test "T-2331: propose succeeds under CLAUDECODE=1 without --i-am-human (non-Sovereign)" {
    run env CLAUDECODE=1 PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --propose "V_AGENT_PROPOSED" --weight 3 --rationale "Agent proposes under CLAUDECODE=1, no Sovereign refusal."
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "proposal P-"
    # Author tagged as agent
    python3 -c "import json; row=json.loads(open('$TEST_TEMP_DIR/.context/bvp-driver-proposals.jsonl').read().strip()); assert row['author'].startswith('agent:'), row['author']"
}

@test "T-2331: --add still refuses under CLAUDECODE=1 (Sovereign rail unchanged)" {
    run env CLAUDECODE=1 PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --add "V_SHOULD_REFUSE" --weight 3 --rationale "Sovereign refusal proof — must NOT land driver."
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "CLAUDECODE\|Sovereignty\|approves" || echo "$output" | grep -q "human"
}

# ---------------------------------------------------------- race-free same-name

@test "T-2331: two proposals for same driver-id append 2 distinct rows (race-free)" {
    env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --propose "V_RACEY" --weight 4 --rationale "Agent A proposes weight 4; race-free append test." >/dev/null
    env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --propose "V_RACEY" --weight 6 --rationale "Agent B proposes weight 6; same name, different rationale + weight." >/dev/null

    [ "$(wc -l < "$TEST_TEMP_DIR/.context/bvp-driver-proposals.jsonl")" -eq 2 ]
    # Distinct ids
    python3 -c "import json; rows=[json.loads(l) for l in open('$TEST_TEMP_DIR/.context/bvp-driver-proposals.jsonl')]; assert rows[0]['id']!=rows[1]['id']; assert rows[0]['name']==rows[1]['name']=='V_RACEY'; assert rows[0]['weight']==4; assert rows[1]['weight']==6"
}

# --------------------------------------------------------- validation contracts

@test "T-2331: rationale <30 chars rejected with exit 2" {
    run env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --propose "V_SHORT" --weight 3 --rationale "too short"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "30"
    # File should NOT have grown
    [ ! -s "${TEST_TEMP_DIR}/.context/bvp-driver-proposals.jsonl" ] || \
        [ "$(wc -l < "$TEST_TEMP_DIR/.context/bvp-driver-proposals.jsonl")" -eq 0 ]
}

@test "T-2331: --weight out of range (0-9) rejected with exit 2" {
    run env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --propose "V_BAD_WEIGHT" --weight 99 --rationale "Weight out of range — should be rejected at validation."
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "weight"
}

@test "T-2331: invalid name slug rejected with exit 2" {
    run env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --propose "1_starts_with_digit" --weight 3 --rationale "Slug starting with digit violates the validator shape — rejected."
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi "name\|invalid"
}

# ---------------------------------------------------------------- optional refs

@test "T-2331: --task T-XXX persists into the JSONL row" {
    run env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver --propose "V_TASK_REF" --weight 5 --rationale "Proposal references a task — round-trip the task id." --task "T-2331"
    [ "$status" -eq 0 ]
    python3 -c "import json; row=json.loads(open('$TEST_TEMP_DIR/.context/bvp-driver-proposals.jsonl').read().strip()); assert row['task']=='T-2331'"
}

# ---------------------------------------------------------- usage advertised

@test "T-2331: usage line advertises --propose" {
    run env PROJECT_ROOT="$TEST_TEMP_DIR" "$FRAMEWORK_ROOT/bin/fw" bvp driver
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "propose"
}
