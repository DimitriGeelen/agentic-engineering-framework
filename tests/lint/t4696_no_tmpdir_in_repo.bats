#!/usr/bin/env bats
# T-4696 — a bats run's temp root must never be inside the framework checkout.
#
# A worker ran `TMPDIR=$PWD/.context/working/t4662tmp bats -j 6 ...`; a fixture
# project in that run wrote a handover under the repo and the next real handover
# commit (0b514d2c4) committed it. Two legs now stop that:
#   1. tests/{unit,lint,integration,governance}/setup_suite.bash refuse the run
#      (tests/tmpdir_outside_repo.bash) — catches an operator/agent invocation.
#   2. this lint refuses a test SOURCE that points TMPDIR / BATS_TMPDIR /
#      BATS_RUN_TMPDIR / `mktemp -p|--tmpdir` / `bats --tempdir` at a repo path.

REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"

# A value is repo-relative when it names the checkout ($PWD, $FRAMEWORK_ROOT,
# $PROJECT_ROOT, $REPO_ROOT, $BATS_TEST_DIRNAME) or a .context/ path.
_REPO_REF='(\$\{?(PWD|FRAMEWORK_ROOT|PROJECT_ROOT|REPO_ROOT|BATS_TEST_DIRNAME)\b|\.context/)'
_SINK='(\b(TMPDIR|BATS_TMPDIR|BATS_RUN_TMPDIR)=["'"'"']?|mktemp\b[^|;&]*(-p|--tmpdir=?)[[:space:]]*["'"'"']?|--tempdir[= ]["'"'"']?)'

_scan() { grep -nE "${_SINK}${_REPO_REF}" "$@"; }

@test "no test source points a temp root at the repo" {
    local hits
    hits="$(cd "$REPO" && find tests -type f \( -name '*.bats' -o -name '*.bash' \) \
        ! -path tests/lint/t4696_no_tmpdir_in_repo.bats \
        ! -path tests/tmpdir_outside_repo.bash -print0 | xargs -0 grep -nE "${_SINK}${_REPO_REF}" || true)"
    if [ -n "$hits" ]; then
        echo "temp root inside the repo (T-4696) — use \$BATS_TEST_TMPDIR or \$(mktemp -d):" >&2
        echo "$hits" >&2
        return 1
    fi
}

@test "the static scan is red on in-repo sinks and green on out-of-repo ones" {
    local f="$BATS_TEST_TMPDIR/src.bats"
    printf '%s\n' 'TMPDIR=$PWD/.context/working/x bats a.bats' > "$f"
    _scan "$f"
    printf '%s\n' 'export BATS_TMPDIR="$FRAMEWORK_ROOT/tmp"' > "$f"
    _scan "$f"
    printf '%s\n' 'd=$(mktemp -d -p "$PROJECT_ROOT")' > "$f"
    _scan "$f"
    printf '%s\n' 'bats --tempdir "$BATS_TEST_DIRNAME/t" x.bats' > "$f"
    _scan "$f"
    printf '%s\n' 'TMPDIR="$(mktemp -d)"' 'export TMPDIR="$BATS_TEST_TMPDIR/tmp"' \
        'export BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"' 'd=$(mktemp -d -p /var/tmp x-XXXX)' > "$f"
    ! _scan "$f" || false
}

@test "tmpdir_inside_repo: repo, descendant, prefix-sibling, outside" {
    source "$REPO/tests/tmpdir_outside_repo.bash"
    mkdir -p "$BATS_TEST_TMPDIR/r/sub" "$BATS_TEST_TMPDIR/r-other"
    tmpdir_inside_repo "$BATS_TEST_TMPDIR/r" "$BATS_TEST_TMPDIR/r"
    tmpdir_inside_repo "$BATS_TEST_TMPDIR/r" "$BATS_TEST_TMPDIR/r/sub/not-yet-created"
    ! tmpdir_inside_repo "$BATS_TEST_TMPDIR/r" "$BATS_TEST_TMPDIR/r-other" || false
    ! tmpdir_inside_repo "$BATS_TEST_TMPDIR/r" "$BATS_TEST_TMPDIR" || false
}

@test "every bats dir under tests/ has the setup_suite refusal" {
    local d
    for d in $(cd "$REPO" && find tests -name '*.bats' -printf '%h\n' | sort -u); do
        [ "$(dirname "$d")" = tests ] || continue
        grep -q 'refuse_tmpdir_inside_repo' "$REPO/$d/setup_suite.bash" || {
            echo "missing $d/setup_suite.bash refusal" >&2; return 1; }
    done
}

@test "end to end: a bats run with TMPDIR inside the checkout is refused, outside runs" {
    # Fixture checkout carrying the real guard and setup_suite, so the nested
    # run exercises the same files the suite uses.
    local fx="$BATS_TEST_TMPDIR/fx"
    mkdir -p "$fx/tests/unit" "$fx/inside" "$BATS_TEST_TMPDIR/outside"
    cp "$REPO/tests/tmpdir_outside_repo.bash" "$fx/tests/"
    cp "$REPO/tests/unit/setup_suite.bash" "$fx/tests/unit/"
    printf '%s\n' '@test "t" { touch "$BATS_TEST_TMPDIR/f"; }' > "$fx/tests/unit/x.bats"

    run env TMPDIR="$fx/inside" bats "$fx/tests/unit/x.bats"
    [ "$status" -ne 0 ]
    [[ "$output" == *"TMPDIR INSIDE THE REPO (T-4696)"* ]]
    [[ "$output" == *"not ok 1 setup_suite"* ]]

    run env TMPDIR="$BATS_TEST_TMPDIR/outside" bats "$fx/tests/unit/x.bats"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok 1 t"* ]]
}
