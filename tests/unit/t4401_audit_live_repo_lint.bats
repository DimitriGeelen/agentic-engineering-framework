#!/usr/bin/env bats
# T-4401: no unit test may run a sectioned audit against the real repo.
#
# audit.sh takes the repo-wide flock $CONTEXT_DIR/locks/audit.lock for every
# `--section` run and exits 75 when it is held (audit.sh:614-631). A test that
# runs one without a fixture PROJECT_ROOT shares that lock with every cron
# audit, pre-push gate and sibling worker, so it skips (`ok ... # skip`, green,
# nothing measured) or pays the whole live section. tools/audit-live-repo-lint.py
# refuses that shape; this file runs it over tests/unit and pins its controls.
# Offender lines below are built from pieces so this file never lints itself red.

REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
LINT="$REPO/tools/audit-live-repo-lint.py"

_case() {
    # _case NAME LINE... — writes a one-test bats file whose body is the lines.
    local f="$BATS_TEST_TMPDIR/$1.bats"; shift
    { echo '@test "case" {'; printf '    %s\n' "$@"; echo '}'; } > "$f"
    echo "$f"
}

AUD='"$FRAMEWORK_ROOT/agents/audit/audit''.sh"'
SEC='--sec''tion structure'

@test "T-4401: tests/unit holds no sectioned audit against the real repo" {
    run python3 "$LINT" "$REPO/tests/unit"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"audit-live-repo-lint: clean"* ]]
}

@test "T-4401 control: a bare live call is flagged (positive control)" {
    local f; f=$(_case bare "run $AUD $SEC")
    run python3 "$LINT" "$f"
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"bare.bats:2: sectioned audit in the real repo"* ]]
}

@test "T-4401 control: PROJECT_ROOT pointed at the repo is still live" {
    local f; f=$(_case repo "run env PROJECT_ROOT=\"\$FRAMEWORK_ROOT\" $AUD $SEC")
    run python3 "$LINT" "$f"
    [ "$status" -eq 1 ]
}

@test "T-4401 control: a prefix PROJECT_ROOT elsewhere does not excuse a bare call" {
    # The pre-T-4401 audit.bats shape: one fixture helper, eight live calls.
    local f; f=$(_case mixed \
        "PROJECT_ROOT=\"\$root\" $AUD --sec""tion tree" \
        "run $AUD $SEC")
    run python3 "$LINT" "$f"
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"mixed.bats:3:"* ]]
    [[ "$output" != *"mixed.bats:2:"* ]]
}

@test "T-4401 control: fixture-rooted calls pass (statement prefix, export, continuation)" {
    local f1 f2 f3
    f1=$(_case prefix "run env PROJECT_ROOT=\"\$BATS_TEST_TMPDIR/p\" $AUD $SEC")
    f2=$(_case export "export PROJECT_ROOT=\"\$TEST_ROOT\"" "run $AUD $SEC")
    f3=$(_case cont "PROJECT_ROOT=\"\$TMPREPO\" TASKS_DIR= \\" "    run bash $AUD $SEC")
    run python3 "$LINT" "$f1" "$f2" "$f3"
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "T-4401 control: the lockless --check path and prose mentions pass" {
    local f; f=$(_case check \
        "run $AUD --check fabric-coverage" \
        "# run $AUD $SEC" \
        "echo \"try: $AUD $SEC\"")
    run python3 "$LINT" "$f"
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "T-4401 control: the live-audit-ok marker needs a reason" {
    local ok bad
    ok=$(_case marked "# live-audit-ok: measures this repo's own section cost" "run $AUD $SEC")
    bad=$(_case noreason "# live-audit-ok:" "run $AUD $SEC")
    run python3 "$LINT" "$ok"
    [ "$status" -eq 0 ]
    run python3 "$LINT" "$bad"
    [ "$status" -eq 1 ]
}

@test "T-4401 control: a python test without a fixture PROJECT_ROOT is flagged" {
    local d="$BATS_TEST_TMPDIR/py"; mkdir -p "$d"
    printf 'import subprocess\nsubprocess.run([FW, "audit", "--sec''tion", "oe-daily"])\n' > "$d/test_live.py"
    printf 'env["PROJECT_ROOT"] = str(tmp_path)\nsubprocess.run([FW, "audit", "--sec''tion", "oe-daily"], env=env)\n' > "$d/test_fixture.py"
    run python3 "$LINT" "$d"
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"test_live.py:2:"* ]]
    [[ "$output" != *"test_fixture.py"* ]]
}
