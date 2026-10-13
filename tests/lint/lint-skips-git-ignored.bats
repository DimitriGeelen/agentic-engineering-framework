#!/usr/bin/env bats
#
# T-4122 — `fw test lint` must not lint git-ignored trees.
#
# `.context/scratch/` (T-4112) holds full repo clones: several GB, ~4k .sh
# files. The shellcheck pass enumerated with a bare `find`, so it linted every
# clone, reported their findings as this repo's FAILs, and ran past the 600 s
# timeout of tests/lint/bats-silent-skip.bats — which turned the pre-push
# invariant suite red.
#
# Every fixture is a throwaway project in BATS_TEST_TMPDIR; nothing is planted
# in the real scratch dir. Git discovery is fenced at the temp root so a fixture
# that is NOT a repo cannot resolve to one above it (T-3610).
#
# `! cmd` at statement position is INERT in bats (L-628) — this file uses
# `if cmd; then false; fi`.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    P="$BATS_TEST_TMPDIR/proj"
    export GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR"
    command -v shellcheck >/dev/null || skip "shellcheck not installed"
}

# A minimal framework-shaped project running THIS checkout's bin/fw. lib/ is a
# symlink (git lists it as one entry, not as .sh files), so only the planted
# files are lint candidates and the run takes well under a second.
_project() {
    mkdir -p "$P/bin" "$P/agents" "$P/tools" "$P/.context/scratch/clone"
    cp "$ROOT/bin/fw" "$P/bin/fw"
    ln -s "$ROOT/lib" "$P/lib"
    : > "$P/FRAMEWORK.md"
    printf 'project_name: t4122\n' > "$P/.framework.yaml"
    printf '.context/scratch/\n' > "$P/.gitignore"
    # SC1073: a parse error, so shellcheck reports it at error severity (FAIL).
    printf 'echo $((\n' > "$P/.context/scratch/clone/ignored_probe.sh"
    printf 'echo $((\n' > "$P/tools/tracked_probe.sh"
}

_lint() {
    run env -u FRAMEWORK_ROOT -u PROJECT_ROOT bash -c "cd '$P' && bin/fw test lint 2>&1"
}

@test "shellcheck pass skips a git-ignored scratch clone, still reports a tracked file" {
    _project
    git -C "$P" init -q
    _lint
    echo "$output" | grep -q 'tracked_probe.sh'        # control: the pass did lint
    if echo "$output" | grep -q 'ignored_probe.sh'; then false; fi
    echo "$output" | grep -q '(1 files)'
}

@test "outside a git work tree the find fallback still prunes .context/scratch" {
    _project
    _lint
    echo "$output" | grep -q 'tracked_probe.sh'
    if echo "$output" | grep -q 'ignored_probe.sh'; then false; fi
}

# ── silent-skip pass ─────────────────────────────────────────────────────────
# Fixture `skip` calls are spelled SKIPCALL and sed-rewritten: a literal call
# here would be a real call site in tests/, which that lint scans.

_bats_fixture() {
    mkdir -p "$(dirname "$1")"
    printf 'BATSTEST "x" {\n    SKIPCALL "not written yet"\n}\n' \
        | sed -e 's/^BATSTEST /@test /' -e 's/SKIPCALL /skip /' > "$1"
}

@test "silent-skip lint ignores a git-ignored .bats under the scanned dir" {
    mkdir -p "$P/tests"
    printf 'tests/scratch/\n' > "$P/.gitignore"
    _bats_fixture "$P/tests/scratch/clone/x.bats"
    # an optional-dependency skip: a call site the lint accepts, so a clean
    # scan exits 0 rather than 2 ("examined nothing")
    printf 'BATSTEST "ok" {\n    command -v docker >/dev/null || SKIPCALL "no docker"\n}\n' \
        | sed -e 's/^BATSTEST /@test /' -e 's/SKIPCALL /skip /' > "$P/tests/clean.bats"
    git -C "$P" init -q
    run python3 "$ROOT/tools/bats-silent-skip-lint.py" "$P/tests"
    [ "$status" -eq 0 ]
    if echo "$output" | grep -q 'UNCONDITIONAL'; then false; fi

    # control: the same file at a path git does not ignore IS reported
    _bats_fixture "$P/tests/kept/x.bats"
    run python3 "$ROOT/tools/bats-silent-skip-lint.py" "$P/tests"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'UNCONDITIONAL'
}
