#!/usr/bin/env bats
# T-3791: bin/fw refuses a PROJECT_ROOT that does not exist, for EVERY verb.
# Origin: T-3790 — test-leaked cron files ran `PROJECT_ROOT=<torn-down tmp> fw docs --all`
# (and fw audit / oe sections) daily; bin/fw re-resolved the missing root to the
# cwd walk / FRAMEWORK_ROOT and ran the job against the wrong project. T-3790 only
# guarded `audit.sh schedule install`.

FW="$BATS_TEST_DIRNAME/../../bin/fw"

setup() {
    MISSING="${BATS_TEST_TMPDIR}/gone-$$"
    REAL="$(mktemp -d "${BATS_TEST_TMPDIR}/real-XXXXXX")"
    mkdir -p "$REAL/.tasks/active" "$REAL/.context"
}

@test "missing PROJECT_ROOT: 'fw docs --all' (non-audit verb, cron shape) exits non-zero with a one-line message" {
    cd /
    run env -u CLAUDE_PROJECT_DIR PROJECT_ROOT="$MISSING" bash "$FW" docs --all
    [ "$status" -eq 2 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "${lines[0]}" == *"PROJECT_ROOT does not exist: $MISSING"* ]]
}

@test "missing PROJECT_ROOT: 'fw version' and 'fw audit' are refused too" {
    cd /
    run env -u CLAUDE_PROJECT_DIR PROJECT_ROOT="$MISSING" bash "$FW" version
    [ "$status" -eq 2 ]
    run env -u CLAUDE_PROJECT_DIR PROJECT_ROOT="$MISSING" bash "$FW" audit --section structure --cron
    [ "$status" -eq 2 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "control: an existing fresh temp PROJECT_ROOT still works" {
    cd /
    run env -u CLAUDE_PROJECT_DIR PROJECT_ROOT="$REAL" bash "$FW" version
    [ "$status" -eq 0 ]
    [[ "$output" == *"Project:"*"$REAL"* ]]
}

@test "control: no PROJECT_ROOT at all still resolves from cwd" {
    cd "$REAL"
    run env -u CLAUDE_PROJECT_DIR -u PROJECT_ROOT bash "$FW" version
    [ "$status" -eq 0 ]
    [[ "$output" == *"Project:"*"$REAL"* ]]
}
