#!/usr/bin/env bats
# T-5342 (G-138): at pre-push, run the unit test files the pushed range touches.
# Hermetic: each test builds a throwaway git project with its own tests/unit,
# a hand-written nightly report and baseline, and runs the audit's two pre-push
# checks (check_prepush_range_tests, then check_unit_suite_report) against it.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SEL="$REPO_ROOT/agents/audit/unit_suite_range.py"
    P="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$P/tests/unit" "$P/lib" "$P/.context/audits/unit-suite"
    git -C "$P" init -q -b main
    git -C "$P" config user.email t@example.invalid
    git -C "$P" config user.name t5342
    git -C "$P" config commit.gpgsign false
    echo 'widget() { echo ok; }' > "$P/lib/widget_core.sh"
    echo 'readme' > "$P/README.md"
    _bats ok_test 'true'
    _bats names_widget 'grep -q widget "$BATS_TEST_DIRNAME/../../lib/widget_core.sh"   # lib/widget_core.sh'
    _bats names_readme 'true   # see README.md'
    _bats unrelated 'true'
    _bats stale 'false'
    _commit base
    BASE_SHA=$(git -C "$P" rev-parse HEAD)
    FUTURE=$(date -u -d '+10 days' +%F)
    printf 'schema: unit-suite-baseline-v1\nentries:\n  - {leg: bats, name: "unrelated.bats: placeholder", owner: T-9999, expires: "%s"}\n' \
        "$FUTURE" > "$P/.context/audits/unit-suite/baseline.yaml"
    _report "$BASE_SHA" 'stale.bats: stale works'
}

# _bats NAME BODY — tests/unit/NAME.bats with one test "NAME works".
_bats() { printf '@test "%s works" {\n    %s\n}\n' "$1" "$2" > "$P/tests/unit/$1.bats"; }
_commit() { git -C "$P" add -A && git -C "$P" commit -qm "$1"; }

# _report COMMIT [RED...] — a fresh nightly report graded at COMMIT.
_report() {
    python3 - "$P/.context/audits/unit-suite/LATEST.yaml" "$@" <<'PY'
import sys, yaml, datetime
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
reds = sys.argv[3:]
yaml.safe_dump({"started": now, "finished": now, "runner_exit": 1 if reds else 0,
                "revision": {"commit": sys.argv[2], "tree": "clean"},
                "legs": {"bats": {"tests": 5, "failed_count": len(reds), "failed": reds},
                         "pytest": {"tests": 1, "failed_count": 0, "failed": []}}},
               open(sys.argv[1], "w"))
PY
}

# _audit [VAR=VALUE...] — the two pre-push checks, pre-push scope.
_audit() {
    run env -u BATS_TEST_FILENAME SECTIONS=structure PROJECT_ROOT="$P" CONTEXT_DIR="$P/.context" \
        FRAMEWORK_ROOT="$REPO_ROOT" REPO_ROOT="$REPO_ROOT" "$@" bash -c '
        source "$REPO_ROOT/lib/config.sh"
        pass() { echo "PASS|$1"; }
        info() { echo "INFO|$1"; }
        warn() { echo "WARN|$1"; echo "WARNEV|$2"; }
        fail() { echo "FAIL|$1"; echo "EVIDENCE|$2"; }
        for f in pass_over warn_unenumerable _audit_is_prepush_scope check_unit_suite_report check_prepush_range_tests; do
            eval "$(sed -n "/^$f() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        done
        _FW_RANGE_SPEC="" _FW_RANGE_PASSED=""
        check_prepush_range_tests
        check_unit_suite_report
    '
}

@test "T-5342: selection = changed tests + tests naming a changed basename; common names skipped" {
    echo 'widget() { echo changed; }' > "$P/lib/widget_core.sh"
    echo 'readme 2' > "$P/README.md"
    echo '# touched' >> "$P/tests/unit/ok_test.bats"
    echo 'x' > "$P/lib/gone_file.sh"; _commit add-gone
    git -C "$P" rm -q "$P/lib/gone_file.sh"
    _bats names_gone 'true   # gone_file.sh'
    _commit change
    run python3 "$SEL" select --root "$P" --range "$BASE_SHA..HEAD"
    [ "$status" -eq 0 ]
    echo "$output"
    [ "${lines[0]}" = "tests/unit/names_gone.bats" ]   # changed (added) first, by name
    [ "${lines[1]}" = "tests/unit/ok_test.bats" ]
    [ "${lines[2]}" = "tests/unit/names_widget.bats" ] # names lib/widget_core.sh
    [ "${#lines[@]}" -eq 3 ]                          # README.md is common; gone_file.sh was removed
    ! echo "$output" | grep -q names_readme || false
    ! echo "$output" | grep -q unrelated || false
    # deterministic and bounded
    run python3 "$SEL" select --root "$P" --range "$BASE_SHA..HEAD" --max 1
    [ "$output" = "tests/unit/names_gone.bats" ]
}

@test "T-5342: a red in a selected file FAILs the push, naming file and test" {
    _bats names_widget 'grep -q nonexistent-string "$BATS_TEST_DIRNAME/../../lib/widget_core.sh"   # lib/widget_core.sh'
    _commit break
    echo 'widget() { echo changed; }' > "$P/lib/widget_core.sh"; _commit change
    _report "$(git -C "$P" rev-parse HEAD)"
    _audit FW_PUSH_RANGE="$BASE_SHA..HEAD" FW_PREPUSH_RANGE_TEST_BUDGET=60
    echo "$output"
    echo "$output" | grep -q '^FAIL|Range unit tests .*1 red(s) not in the ratchet baseline'
    echo "$output" | grep -q '^EVIDENCE|.*names_widget.bats: names_widget works'
}

@test "T-5342: a selected file that passes clears its stale-report red for this push" {
    # control: with range tests off, the stale red is a NEW red and FAILs
    _audit FW_PUSH_RANGE="$BASE_SHA..HEAD" FW_PREPUSH_RANGE_TEST_BUDGET=0
    echo "$output"
    echo "$output" | grep -q '^FAIL|Unit suite.*1 NEW red'
    _bats stale 'true'; _commit fix-stale
    _audit FW_PUSH_RANGE="$BASE_SHA..HEAD" FW_PREPUSH_RANGE_TEST_BUDGET=60
    echo "$output"
    ! echo "$output" | grep -q '^FAIL|' || false
    echo "$output" | grep -q '^INFO|Unit suite.*1 stale red(s) not counted for this push.*stale.bats'
    echo "$output" | grep -q '^PASS|Range unit tests .*all 1 green'
}

@test "T-5342: budget overrun WARNs naming the files not run, never a silent pass" {
    _bats slow_one 'sleep 20   # lib/widget_core.sh'
    _bats slow_two 'sleep 20   # lib/widget_core.sh'
    _commit slow
    _report "$(git -C "$P" rev-parse HEAD)"
    _audit FW_PUSH_RANGE="$BASE_SHA..HEAD" FW_PREPUSH_RANGE_TEST_BUDGET=3
    echo "$output"
    echo "$output" | grep -q '^WARN|Range unit tests .*NOT RUN or not finished within the budget'
    echo "$output" | grep -q '^WARNEV|.*slow_one.bats'
    echo "$output" | grep -q '^WARNEV|.*slow_two.bats'
    ! echo "$output" | grep -q '^PASS|Range unit tests'
}

@test "T-5342: the ratchet line names the report commit and how many pushed commits are newer" {
    echo 'one' > "$P/lib/a_file.sh"; _commit one
    echo 'two' > "$P/lib/a_file.sh"; _commit two
    _report "$BASE_SHA"
    _audit FW_PUSH_RANGE="$BASE_SHA..HEAD" FW_PREPUSH_RANGE_TEST_BUDGET=60
    echo "$output"
    echo "$output" | grep -q "^PASS|Unit suite.*\[report commit ${BASE_SHA:0:9}, 2 pushed commit(s) newer than it\]"
    # no selected files → one INFO line
    echo "$output" | grep -q '^INFO|Range unit tests .*no unit test file is changed by or names a file changed in the range'
}

@test "T-5342: the pre-push hook template hands the audit FW_PUSH_RANGE" {
    grep -q '^export FW_PUSH_RANGE$' "$REPO_ROOT/agents/git/lib/hooks.sh"
    grep -q '^check_prepush_range_tests$' "$REPO_ROOT/agents/audit/audit.sh"
    grep -q '^    "PREPUSH_RANGE_TEST_BUDGET|120|' "$REPO_ROOT/lib/config.sh"
}
