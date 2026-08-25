#!/usr/bin/env bats
# T-2796 — `fw --version` must not ship a bare counter with no anchor.
#
# ── What the number actually is ────────────────────────────────────────────────
#
# `_derive_version` (bin/fw:16) renders `git describe` as
# major.minor.<commits-since-the-newest-tag-THIS-CLONE-KNOWS>, discarding the
# tag's own patch: `v1.6.764-132-g74bade82e` becomes `1.6.132`. So the number
# resets to near-zero at every tag AND depends on which tags the clone happens to
# have fetched. Two installs of the same history report incomparable numbers.
#
# Measured 2026-08-04: a global install three commits behind master reported
# 1.6.432 while master reported 1.6.132. The bigger number was the stale one. The
# operator's onboarding agent read 432 as "current, skip the installer"; this
# session read it as "130 commits behind, update it". Both were reading a
# distance as a version, because the string is shaped like a semver patch and
# nothing next to it says otherwise (OBS-150, OBS-156).
#
# The counter is deliberately NOT changed here — it is load-bearing for the
# `.framework.yaml` pin, `fw version sync`, and self-audit's VERSION comparison.
# What changes is that it no longer travels alone.
#
# ── The second defect at the same site ─────────────────────────────────────────
#
# T-2713 replaced `pinned != installed -> WARN` at three sites, because `sort -V`
# on a resetting counter is "a guess wearing the costume of a comparison". This
# was a fourth, still open-coded — and the most-read one, since it fires on every
# `fw --version`. L-536: a line that PRINTS a direction is a decision site.

bats_require_minimum_version 1.5.0

FW() { echo "$BATS_TEST_DIRNAME/../../bin/fw"; }
REPO() { cd "$BATS_TEST_DIRNAME/../.." && pwd; }

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    # Deliberately NOT exporting FRAMEWORK_ROOT/PROJECT_ROOT here: bin/fw honours
    # them ("env wins", T-2391/T-2446), so a setup-level export leaks into every
    # test that invokes the real CLI and silently reframes what is under test.
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

@test "version output carries the commit the counter is a distance from" {
    run env -u FRAMEWORK_ROOT -u PROJECT_ROOT "$(FW)" --version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^Commit:'
}

@test "the printed commit is really this checkout's HEAD" {
    local expected
    expected="$(git -C "$(REPO)" rev-parse --short=9 HEAD)"
    # Non-vacuity: a blank expectation would make the grep below pass on anything.
    [ -n "$expected" ]
    [ "${#expected}" -eq 9 ]
    run env -u FRAMEWORK_ROOT -u PROJECT_ROOT "$(FW)" --version
    echo "$output" | grep -q "^Commit:  *${expected}"
}

@test "the commit line names the branch" {
    local branch
    branch="$(git -C "$(REPO)" rev-parse --abbrev-ref HEAD)"
    [ -n "$branch" ]
    run env -u FRAMEWORK_ROOT -u PROJECT_ROOT "$(FW)" --version
    echo "$output" | grep -q "(${branch})"
}

@test "a framework root with no .git says so instead of printing nothing" {
    # The vendored case. `_derive_version` falls back to the VERSION file there,
    # so the counter is all the identity that exists — which is exactly the fact
    # the operator needs told, not hidden behind an absent line.
    mkdir -p "$TEST_TEMP_DIR/nogit"
    run env -u PROJECT_ROOT FRAMEWORK_ROOT="$TEST_TEMP_DIR/nogit" "$(FW)" --version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^Commit:.*none'
    echo "$output" | grep -q 'VERSION file is the only identity'
}

@test "a pin whose sha is an ancestor is reported BEHIND, by ancestry" {
    local anc
    anc="$(git -C "$(REPO)" rev-parse HEAD~5)"
    [ -n "$anc" ]
    mkdir -p "$TEST_TEMP_DIR/consumer"
    printf 'version: 1.6.999\nversion_sha: %s\n' "$anc" \
        > "$TEST_TEMP_DIR/consumer/.framework.yaml"
    run env -u FRAMEWORK_ROOT PROJECT_ROOT="$TEST_TEMP_DIR/consumer" "$(FW)" --version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'BEHIND'
    # 1.6.999 is numerically larger than the installed counter, so the replaced
    # string compare would have called this drift in the wrong direction — or,
    # under sort -V, "ahead". Ancestry says behind. Pin the old wording as gone.
    ! echo "$output" | grep -q 'differs from installed'
}

@test "a legacy pin with no sha is undecidable, not drift" {
    # No version_sha (pre-T-2713) and no tag v9.9.9 in the repo: there is nothing
    # to compare. The old code printed "differs from installed", which reads as a
    # direction and gets acted on. Saying "undetermined" is the whole point.
    mkdir -p "$TEST_TEMP_DIR/legacy"
    printf 'version: 9.9.9\n' > "$TEST_TEMP_DIR/legacy/.framework.yaml"
    run env -u FRAMEWORK_ROOT PROJECT_ROOT="$TEST_TEMP_DIR/legacy" "$(FW)" --version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'undetermined'
    [[ "$output" != *"BEHIND"* ]]
    ! echo "$output" | grep -q 'AHEAD'
}

@test "a pin naming a commit this repo lacks is called out as foreign, not behind" {
    # T-2762's field failure: a stale source that cannot see the consumer's
    # history must not claim authority over it.
    mkdir -p "$TEST_TEMP_DIR/foreign"
    printf 'version: 1.6.999\nversion_sha: %s\n' "0000000000000000000000000000000000000000" \
        > "$TEST_TEMP_DIR/foreign/.framework.yaml"
    run env -u FRAMEWORK_ROOT PROJECT_ROOT="$TEST_TEMP_DIR/foreign" "$(FW)" --version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'does not contain'
}

@test "a pin equal to the installed counter prints no relation line and exits 0" {
    # Regression pin: the relation branch is built from a case that yields an
    # empty phrase for `same`. Written as `[ -n "$p" ] && echo`, that AND-list
    # returns 1 — and this file runs under `set -e`, so the whole CLI would exit
    # non-zero on the most common path of all. Caught by running it, not reading it.
    local installed
    installed="$(env -u FRAMEWORK_ROOT -u PROJECT_ROOT "$(FW)" --version | head -1 | sed 's/^fw v//')"
    [ -n "$installed" ]
    mkdir -p "$TEST_TEMP_DIR/same"
    printf 'version: %s\n' "$installed" > "$TEST_TEMP_DIR/same/.framework.yaml"
    run env -u FRAMEWORK_ROOT PROJECT_ROOT="$TEST_TEMP_DIR/same" "$(FW)" --version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^Pinned:  *${installed}"
    ! echo "$output" | grep -qi 'behind\|ahead\|diverged\|undetermined\|differs'
}

@test "line 1 stays byte-identical for anything that greps it" {
    run env -u FRAMEWORK_ROOT -u PROJECT_ROOT "$(FW)" --version
    echo "$output" | head -1 | grep -qE '^fw v[0-9]+\.[0-9]+\.[0-9]+'
}
