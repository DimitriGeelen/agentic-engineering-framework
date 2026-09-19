#!/usr/bin/env bats
# T-3393 — the §13 invariant traceability matrix resolves, and its fence bites.
#
# The Arc 0 headline mechanic promises an operator can pick any pilot invariant
# and reach a contract, a refusal scenario, a component and a runnable fence.
# This suite pins that the matrix covers all 20 invariants and that
# tools/ewcr-trace-check.py goes red on each way the trace can rot.
#
# Every green assertion has a control leg on a tampered copy (L-668) — a check
# that cannot fail is not a check.

load ../test_helper

TOOL="$FRAMEWORK_ROOT/tools/ewcr-trace-check.py"
MATRIX="$FRAMEWORK_ROOT/docs/research/executable-workflow/contracts/v1/traceability.yaml"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    COPY="$TEST_TEMP_DIR/traceability.yaml"
    cp "$MATRIX" "$COPY"
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# Rewrite one row's field in the copy. Usage: _mutate <id> <field> <value>
_mutate() {
    python3 - "$COPY" "$1" "$2" "$3" <<'PY'
import sys, yaml
path, rid, field, value = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
d = yaml.safe_load(open(path))
for r in d["invariants"]:
    if r["id"] == rid:
        r[field] = value
yaml.safe_dump(d, open(path, "w"))
PY
}

_check() { run python3 "$TOOL" --file "$COPY"; }

@test "T-3393: the real matrix resolves — 20 invariants, every reference live" {
    run python3 "$TOOL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"20 invariants traced"* ]]
}

@test "T-3393: the matrix accounts for every architecture §13 scenario" {
    run python3 -c "
import yaml,sys
d=yaml.safe_load(open('$MATRIX'))
ids=sorted(r['id'] for r in d['invariants'])
sys.exit(0 if ids==list(range(1,21)) else 1)"
    [ "$status" -eq 0 ]
}

@test "T-3393: an untouched copy is green (control for the tamper legs)" {
    _check
    [ "$status" -eq 0 ]
}

@test "T-3393: red when a covered row points at a section that does not exist" {
    _mutate 13 section "## 99. Nonexistent section"
    _check
    [ "$status" -ne 0 ]
    [[ "$output" == *"not present in"* ]]
}

@test "T-3393: red when an invariant row is missing entirely" {
    python3 - "$COPY" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
d["invariants"] = [r for r in d["invariants"] if r["id"] != 7]
yaml.safe_dump(d, open(sys.argv[1], "w"))
PY
    _check
    [ "$status" -ne 0 ]
    [[ "$output" == *"missing invariant id"* ]]
}

@test "T-3393: red when a gap is left silent — no reason stated" {
    _mutate 8 reason ""
    _check
    [ "$status" -ne 0 ]
    [[ "$output" == *"states no reason"* ]]
}

@test "T-3393: red when a statement drifts from architecture §13" {
    _mutate 3 statement "A human gate can be skipped sometimes."
    _check
    [ "$status" -ne 0 ]
    [[ "$output" == *"verbatim"* ]]
}

@test "T-3393: red when a reason_code is not in the frozen refusal enum" {
    _mutate 5 reason_code "definitely_not_a_code"
    _check
    [ "$status" -ne 0 ]
    [[ "$output" == *"frozen refusal.schema.json enum"* ]]
}

@test "T-3393: red when a covered row names a fence script that does not exist" {
    _mutate 3 fence "tools/does-not-exist.py"
    _check
    [ "$status" -ne 0 ]
    [[ "$output" == *"fence script not found"* ]]
}

@test "T-3393: red when status is neither covered nor gap" {
    _mutate 1 status "maybe"
    _check
    [ "$status" -ne 0 ]
    [[ "$output" == *"must be 'covered' or 'gap'"* ]]
}
