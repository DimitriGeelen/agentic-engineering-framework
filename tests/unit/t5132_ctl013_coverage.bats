#!/usr/bin/env bats
# T-5132 (832 T-764 / RA-053, operator ruling): the CTL-013 spot-check keeps a ledger and
# reports its own coverage. A task whose re-run failed is re-checked after newer closes push it
# out of the latest-3 window, until it passes; an earlier failure not re-checked is named.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"; export TEST_TEMP_DIR
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    TASKS_DIR="$TEST_TEMP_DIR/tasks"; mkdir -p "$TASKS_DIR/completed"
    CTX="$TEST_TEMP_DIR/ctx"; mkdir -p "$CTX/audits"
    BLOCK="$TEST_TEMP_DIR/ctl013.sh"
    awk '/^# CTL-013 OE:/{f=1} f{print} f && /^shopt -u nullglob$/{exit}' "$AUDIT" > "$BLOCK"
    grep -q 'T-5132' "$BLOCK" || { echo "T-5132 code not inside the extracted CTL-013 block" >&2; return 1; }
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

task() {  # id verification-cmd age-minutes
    local f="$TASKS_DIR/completed/$1-fixture.md"
    printf -- '---\nid: %s\n---\n\n## Verification\n\n%s\n\n## Updates\n' "$1" "$2" > "$f"
    touch -d "$3 minutes ago" "$f"
}

ctl013() {
    TASKS_DIR="$TASKS_DIR" PROJECT_ROOT="$TEST_TEMP_DIR" CONTEXT_DIR="$CTX" \
    CTL013_RECHECK_CAP="${CAP:-3}" bash -c '
        pass() { echo "PASS: $1"; }
        warn() { echo "WARN: $1"; }
        source "$1"
    ' _ "$BLOCK"
}

ledger() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get(sys.argv[2],{}).get("verdict",""))' "$CTX/audits/ctl013-spotcheck.json" "$1"; }

@test "a run prints its coverage and records each checked task" {
    task T-9001 'true' 10
    task T-9002 'true' 20
    run ctl013
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS: CTL-013 coverage: checked 2 of 2 completed"* ]]
    [ "$(ledger T-9001)" = "PASS" ]
}

@test "a failing task is re-checked after newer closes push it out of the latest-3 window" {
    task T-9001 'false' 10
    run ctl013
    [[ "$output" == *"WARN: CTL-013: T-9001 verification re-run"* ]]
    [ "$(ledger T-9001)" = "WARN" ]
    task T-9002 'true' 3; task T-9003 'true' 2; task T-9004 'true' 1   # three newer closes
    run ctl013
    [[ "$output" == *"WARN: CTL-013: T-9001 verification re-run"* ]]   # still checked
    [[ "$output" == *"checked 4 of 4 completed"* ]]
}

@test "once it passes it is recorded PASS and leaves the re-check set" {
    task T-9001 'false' 10
    run ctl013
    task T-9002 'true' 3; task T-9003 'true' 2; task T-9004 'true' 1
    task T-9001 'true' 10                                              # fixed
    run ctl013
    [ "$(ledger T-9001)" = "PASS" ]
    run ctl013
    [[ "$output" != *"T-9001 verification re-run"* ]]                  # out of the window, not WARN
    [[ "$output" == *"PASS: CTL-013 coverage: checked 3 of 4 completed"* ]]
}

@test "an earlier failure not re-checked this run is named as a WARN with its date" {
    task T-9001 'false' 10
    run ctl013
    task T-9002 'true' 3; task T-9003 'true' 2; task T-9004 'true' 1
    CAP=0 run ctl013
    [[ "$output" == *"WARN: CTL-013 coverage: checked 3 of 4 completed; not re-checked this run: T-9001 last checked $(date +%F), last verdict WARN"* ]]
}
