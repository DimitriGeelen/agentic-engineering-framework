#!/usr/bin/env bats
# T-3526 — end-to-end reachability of `fw bvp judge` on the real entry point.
#
# AC: "Reachable on the path an agent actually takes. Verified by running the
# real entry point with no override flags, not with --i-am-human." Twice in
# this session a guard was written that no live path reached; a pass obtained
# with an override flag proved nothing. These tests run the actual `bin/fw bvp
# judge` command — no --i-am-human, no FW_ALLOW_*, no mocks — against real
# probe task files dropped into .tasks/active/, mirroring the existing
# convention in tests/unit/bvp_auto_promote.bats.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw not found"
    cd "$FRAMEWORK_ROOT"

    GREEN_ID="T-99981"
    GREEN_FILE=".tasks/active/${GREEN_ID}-bvp-judge-probe-green.md"
    cat > "$GREEN_FILE" <<'EOF'
---
id: T-99981
status: started-work
description: "A real, specific probe objective for the bvp-judge entrypoint test."
bvp_scores_proposed:
  - ts: '2026-09-27T00:00:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 1
    rationale: "D1=2 (body:local-fix); D2=1 (body:incidental)"
---

## Acceptance Criteria

### Agent
- [ ] The probe endpoint returns HTTP 200 with the expected payload shape.
- [ ] A regression test pins the fix so it cannot silently regress.
EOF

    RED_ID="T-99982"
    RED_FILE=".tasks/active/${RED_ID}-bvp-judge-probe-red.md"
    cat > "$RED_FILE" <<'EOF'
---
id: T-99982
status: started-work
description: "Another probe task, but with no acceptance criteria at all."
bvp_scores_proposed:
  - ts: '2026-09-27T00:00:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
    rationale: "D1=3 (body:local-fix)"
---

## Acceptance Criteria

### Agent
<!-- none yet -->
EOF

    CLOSED_ID="T-99983"
    CLOSED_FILE=".tasks/completed/${CLOSED_ID}-bvp-judge-probe-closed.md"
    cat > "$CLOSED_FILE" <<'EOF'
---
id: T-99983
status: work-completed
description: "A closed probe task — must never be rescored."
bvp_scores_proposed:
  - ts: '2026-09-27T00:00:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 5
    rationale: "D1=5 (body:new-mechanism)"
---

## Acceptance Criteria

### Agent
- [ ] Irrelevant — task is closed.
EOF
}

teardown() {
    rm -f "$GREEN_FILE" "$RED_FILE" "$CLOSED_FILE"
}

@test "fw bvp judge --help exits 0 with no flags at all" {
    run bin/fw bvp judge --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"judge"* ]]
}

@test "fw bvp judge on a well-formed open task returns green, no override flags" {
    run bin/fw bvp judge "$GREEN_ID" --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"state": "green"'* ]]
    [[ "$output" != *'"state": "unknown"'* ]]
}

@test "fw bvp judge on a criteria-free open task returns red, no override flags" {
    run bin/fw bvp judge "$RED_ID" --json
    [ "$status" -eq 1 ]
    [[ "$output" == *'"state": "red"'* ]]
    [[ "$output" == *'"guidance"'* ]]
    # A non-empty guidance string, not a bare colour with nothing to act on.
    [[ "$output" != *'"guidance": ""'* ]]
}

@test "fw bvp judge on a closed task is skipped, never rescored" {
    run bin/fw bvp judge "$CLOSED_ID" --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"skipped": true'* ]]
    [[ "$output" == *"closed"* ]]
}

@test "fw bvp judge --dispatch routes to the isolated-worker CLI, no override flag needed" {
    # A real spawn (fw termlink dispatch -> claude -p) is exercised by the
    # mocked unit tests in test_bvp_judge_dispatch.py — this only pins that
    # the real `bin/fw bvp judge --dispatch` argv reaches
    # lib.bvp_judge_dispatch_cli without requiring --i-am-human or any other
    # override flag, by checking the recursive-dispatch guard fires on the
    # REAL entry point (proves this exact command line reaches that module).
    FW_BVP_JUDGE_IN_DISPATCH=1 run bin/fw bvp judge "$GREEN_ID" --dispatch
    [ "$status" -eq 3 ]
    [[ "$output" == *"FW_BVP_JUDGE_IN_DISPATCH"* ]]
}
