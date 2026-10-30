#!/usr/bin/env bats
# T-4916 — delegated deterministic criteria had no close path (ring20-dashboard,
# msg 616b90f3, ~153 criteria). `fw task delegate` converted them to `[REVIEWER]`
# Agent criteria for the T-1985 auto-tick; T-4778 narrowed auto-tick to named scanner
# checks; judge and the verdict ledger read only `### Human`. Operator ruling
# 2026-10-30 ("b"): deterministic criteria are reviewer-judged from the start, and
# the ones already converted go back with `fw task delegate --reroute-converted`.

load ../test_helper

FW="$BATS_TEST_DIRNAME/../../bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/bin"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    ln -sf "$FRAMEWORK_ROOT/bin/fw" "$PROJECT_ROOT/bin/fw"
    F="$PROJECT_ROOT/.tasks/active/T-9101-converted.md"
    LEDGER="$PROJECT_ROOT/.context/working/delegations.jsonl"
}

teardown() { [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"; }

# A task in the state a pre-T-4916 `fw task delegate` left it: two criteria
# converted to [REVIEWER] Agent criteria, one authored [REVIEWER] Agent criterion
# that delegation never touched, owner moved human -> agent, the reviewer-PASS line.
_converted_task() {
    cat > "$F" <<'EOF'
---
id: T-9101
name: "converted fixture"
status: started-work
workflow_type: build
owner: agent
horizon: now
created: 2026-09-24T00:00:00Z
last_update: 2026-09-24T00:00:00Z
---

## Acceptance Criteria

### Agent
- [x] Fixture body is in place
- [ ] [REVIEWER] Authored check names `tautology` with no findings
- [ ] [REVIEWER] Doctor names the new config key
  **Steps:**
  1. Run `bin/fw doctor`
  **Expected:** output contains the key and exit code is 0
  **If not:** re-run and read the first failure
- [ ] [REVIEWER] Ledger row is appended
  **Steps:**
  1. Run the verb once
  **Expected:** one row appended to the ledger, exit code 0
  **If not:** check the ledger path

### Human

## Verification

bin/fw reviewer T-9101 > /tmp/.fw-reviewer-T-9101.out 2>&1 && grep -q "Overall:.*PASS" /tmp/.fw-reviewer-T-9101.out

## Updates
EOF
    printf '%s\n' '{"ts":"2026-10-01T00:00:00Z","task":"T-9101","ruling":"D-626","dry_run":false,"owner_before":"human","owner_after":"agent","converted":[{"index":1,"title":"[REVIEW] Doctor names the new config key","reason":"x"},{"index":2,"title":"[REVIEW] Ledger row is appended","reason":"x"}],"refused":[]}' > "$LEDGER"
}

_human_block() { awk '/^### Human/{f=1;next} /^## /{f=0} f' "$F"; }
_agent_block() { awk '/^### Agent/{f=1;next} /^### Human/{f=0} f' "$F"; }

@test "a deterministic Human criterion is reviewer-judged and not converted" {
    cat > "$PROJECT_ROOT/.tasks/active/T-9102-plain.md" <<'EOF'
---
id: T-9102
name: "plain"
status: started-work
workflow_type: build
owner: human
horizon: now
---

## Acceptance Criteria

### Agent
- [x] body

### Human
- [ ] [REVIEW] Doctor names the new config key
  **Expected:** output contains the key and exit code is 0

## Verification

## Updates
EOF
    local before; before="$(cksum < "$PROJECT_ROOT/.tasks/active/T-9102-plain.md")"
    run "$FW" task delegate T-9102
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "reviewer-judged (fw reviewer judge)"
    echo "$output" | grep -q "converted 0, reviewer-judged 1, left human 0"
    echo "$output" | grep -q "reviewer judge T-9102"
    [ "$(cksum < "$PROJECT_ROOT/.tasks/active/T-9102-plain.md")" = "$before" ]
}

@test "--reroute-converted --dry-run lists the delegated criteria and writes nothing" {
    _converted_task
    local before; before="$(cksum < "$F")"
    run "$FW" task delegate T-9101 --reroute-converted --dry-run
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Agent AC#3 .*→ ### Human"
    echo "$output" | grep -q "Agent AC#4 .*→ ### Human"
    [[ "$output" != *"AC#2 "*"→"* ]]                    # authored [REVIEWER] stays
    echo "$output" | grep -q "owner: agent → human"
    [ "$(cksum < "$F")" = "$before" ]
    [ "$(wc -l < "$LEDGER")" -eq 1 ]
}

@test "--reroute-converted moves only delegated criteria, verbatim, and restores the owner" {
    _converted_task
    run "$FW" task delegate T-9101 --reroute-converted
    [ "$status" -eq 0 ]
    _human_block | grep -q '^- \[ \] \[REVIEWER\] Doctor names the new config key'
    _human_block | grep -q '^  \*\*Expected:\*\* one row appended to the ledger, exit code 0'
    _agent_block | grep -q 'Authored check names `tautology`'
    ! _agent_block | grep -q 'Doctor names the new config key' || false
    grep -q '^owner: human' "$F"
    ! grep -q '^bin/fw reviewer T-9101 >' "$F" || false   # the conversion's PASS line is gone
    grep -q 'delegate reroute \[fw-task-delegate\]' "$F"
    tail -1 "$LEDGER" | grep -q '"class":"reroute"'
}

@test "--reroute-converted is idempotent" {
    _converted_task
    "$FW" task delegate T-9101 --reroute-converted >/dev/null
    local after; after="$(cksum < "$F")"
    run "$FW" task delegate T-9101 --reroute-converted
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "nothing to reroute"
    [ "$(cksum < "$F")" = "$after" ]
}

@test "--reroute-converted without a delegation record moves nothing" {
    _converted_task
    : > "$LEDGER"
    local before; before="$(cksum < "$F")"
    run "$FW" task delegate T-9101 --reroute-converted
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "nothing to reroute"
    [ "$(cksum < "$F")" = "$before" ]
}

@test "rerouted criteria are classified reviewer-judged (the class judge and the ledger accept)" {
    _converted_task
    "$FW" task delegate T-9101 --reroute-converted >/dev/null
    run python3 - "$FRAMEWORK_ROOT" "$F" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
from lib.delegation import human_criteria, classify, REVIEWER_JUDGES
crits = human_criteria(open(sys.argv[2]).read())
assert len(crits) == 2, crits
assert all(classify(c).delegation_class == REVIEWER_JUDGES for c in crits)
PY
    [ "$status" -eq 0 ]
}

@test "judge brief: a stale literal gets amber with a proposed restatement (decision i)" {
    grep -q "PROPOSED RESTATEMENT" "$FRAMEWORK_ROOT/lib/reviewer/judge_cli.py"
    grep -q "do NOT return green on what it probably" "$FRAMEWORK_ROOT/lib/reviewer/judge_cli.py"
}

@test "after a reroute, fw reviewer judge --dry-run plans both criteria" {
    _converted_task
    "$FW" task delegate T-9101 --reroute-converted >/dev/null
    git -C "$PROJECT_ROOT" init -q
    git -C "$PROJECT_ROOT" -c user.email=t@example.invalid -c user.name=t add -A
    git -C "$PROJECT_ROOT" -c user.email=t@example.invalid -c user.name=t commit -qm "T-9101: fixture"
    run bash -c "cd '$PROJECT_ROOT' && timeout 120 '$FW' reviewer judge T-9101 --dry-run"
    [[ "$output" != *"No REVIEWER_JUDGES criteria found"* ]]
    echo "$output" | grep -q "Criteria: 2 REVIEWER_JUDGES"
}
