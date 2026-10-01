#!/usr/bin/env bats
# T-3650: the unit-suite audit line must name the directory the report
# actually measured (its own suite_dir), not a hard-coded "tests/unit".
#
# Port of 055-agentic-fleet-cockpit's finding (framework:pickup offset 225,
# their commit 2926e85). In a consumer with a flat tests/ layout the line read
# "Unit suite (tests/unit) green" — a directory that does not exist there — and
# produced two urgent observations and two false blockers.
#
# Pins the INVARIANT (label == report suite_dir relative to PROJECT_ROOT) over
# two layouts, plus: paths with no report name no directory rather than guess.
# Hermetic: fixture reports; the check is EXTRACTED from the shipped audit.sh.

load ../test_helper

setup() {
    REPO_ROOT="$FRAMEWORK_ROOT"
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    WORK="$TEST_TEMP_DIR/t3650"
    mkdir -p "$WORK"
    FAKE_ROOT="$WORK/proj"
}

_run_audit_check() {
    run env FW_UNIT_SUITE_REPORT="$1" REPO_ROOT="$REPO_ROOT" PROJECT_ROOT="$FAKE_ROOT" bash -c '
        pass() { echo "PASS|$1"; }
        info() { echo "INFO|$1"; }
        warn() { echo "WARN|$1"; echo "WARNEV|$2"; echo "WARNMIT|$3"; }
        fail() { echo "FAIL|$1"; echo "EVIDENCE|$2"; echo "MITIGATION|$3"; }
        eval "$(sed -n "/^pass_over() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^warn_unenumerable() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^_audit_is_prepush_scope() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^check_unit_suite_report() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        CONTEXT_DIR="/nonexistent-t3650"
        check_unit_suite_report
    '
}

# _write_report <path> <suite_dir-line-or-empty> <failed_count> <finished>
_write_report() {
    local path="$1" sd="$2" nfail="$3" fin="${4:-$(date -u +%FT%TZ)}"
    local failed="[]"
    [ "$nfail" -gt 0 ] && failed="[x.bats]"
    {
        echo "schema: unit-suite-report-v2"
        echo "task: T-3650"
        echo "finished: '$fin'"
        [ -n "$sd" ] && echo "suite_dir: $sd"
        echo "timed_out: false"
        echo "runner_exit: $([ "$nfail" -gt 0 ] && echo 1 || echo 0)"
        cat <<EOF
legs:
  bats:
    files: 2
    files_completed: 2
    files_timed_out: []
    files_not_run: 0
    tests: 10
    failed_count: $nfail
    failed: $failed
    error: null
  pytest:
    files: 1
    files_completed: 1
    files_timed_out: []
    files_not_run: 0
    tests: 5
    failed_count: 0
    failed: []
    error: null
EOF
    } > "$path"
}

@test "flat layout: green line names (tests), never tests/unit" {
    _write_report "$WORK/r.yaml" "$FAKE_ROOT/tests" 0
    _run_audit_check "$WORK/r.yaml"
    [[ "$output" == *"Unit suite (tests) green"* ]]
    [[ "$output" != *"tests/unit"* ]]
}

@test "flat layout: red line names (tests), never tests/unit" {
    _write_report "$WORK/r.yaml" "$FAKE_ROOT/tests" 1
    _run_audit_check "$WORK/r.yaml"
    [[ "$output" == *"FAIL|Unit suite (tests): 1 of 15"* ]]
    [[ "$output" != *"tests/unit"* ]]
}

@test "flat layout: stale line names (tests), never tests/unit" {
    _write_report "$WORK/r.yaml" "$FAKE_ROOT/tests" 0 "2020-01-01T00:00:00Z"
    _run_audit_check "$WORK/r.yaml"
    [[ "$output" == *"WARN|Unit suite (tests) report STALE"* ]]
    [[ "$output" != *"tests/unit"* ]]
}

@test "invariant: label equals report suite_dir for a second layout" {
    _write_report "$WORK/r.yaml" "$FAKE_ROOT/spec/fast" 0
    _run_audit_check "$WORK/r.yaml"
    [[ "$output" == *"Unit suite (spec/fast) green"* ]]
    [[ "$output" != *"tests/unit"* ]]
}

@test "our own layout still reads (tests/unit)" {
    _write_report "$WORK/r.yaml" "$FAKE_ROOT/tests/unit" 0
    _run_audit_check "$WORK/r.yaml"
    [[ "$output" == *"Unit suite (tests/unit) green"* ]]
}

@test "report without suite_dir names no directory" {
    _write_report "$WORK/r.yaml" "" 0
    _run_audit_check "$WORK/r.yaml"
    [[ "$output" == *"PASS|Unit suite green"* ]]
    [[ "$output" != *"tests/unit"* ]]
}

@test "missing report names no directory" {
    _run_audit_check "$WORK/absent.yaml"
    [[ "$output" == *"WARN|Unit suite NOT CHECKED"* ]]
    [[ "$output" != *"tests/unit"* ]]
}

@test "unparseable report names no directory" {
    printf 'legs: [\n' > "$WORK/bad.yaml"
    _run_audit_check "$WORK/bad.yaml"
    [[ "$output" == *"Unit suite"* ]]
    [[ "$output" != *"tests/unit"* ]]
}
