#!/usr/bin/env bats
# T-3242: VERSION file was non-monotonic and disagreed with release tags.
#
# VERSION was synced from _derive_version's resetting commit counter
# (major.minor.<commits-since-newest-tag>), so at the last five release tags it
# read 1.6.121, 1.6.499, 1.6.430, 1.6.176, 1.6.72 while the tags climbed
# v1.6.764..v1.6.768 monotonically — a DECREASE of 176 → 72 across consecutive
# releases. The ruling: the TAG is canonical, VERSION mirrors it.
#
# Three rails, all pinned here against hermetic fixture repos (never the real
# repo state — the real repo's tags would make these tests time bombs):
#   1. release-time reconciliation (lib/release.sh release_reconcile_version)
#   2. release refusal when the tag would DECREASE VERSION (T-3190 refuse-family)
#   3. doctor parity predicate (release_version_tag_parity), FAIL on behind,
#      silent when no tags / no .git / no VERSION.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$BATS_TEST_TMPDIR/t3242"
    REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b bleeding-edge
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    git -C "$REPO" config commit.gpgsign false
    echo base > "$REPO/f"
    echo "1.0.0" > "$REPO/VERSION"
    git -C "$REPO" add f VERSION
    git -C "$REPO" commit -qm "T-0: seed"
    git -C "$REPO" tag v1.0.0
    # Release-train shape: master (install surface) behind bleeding-edge.
    git -C "$REPO" branch master
    echo dev > "$REPO/f2"; git -C "$REPO" add f2; git -C "$REPO" commit -qm "T-0: work"

    # Stub gh so the best-effort GitHub Release leg never reaches the network.
    STUB_BIN="$TEST_TEMP_DIR/bin"; mkdir -p "$STUB_BIN"
    printf '#!/bin/sh\nexit 0\n' > "$STUB_BIN/gh"; chmod +x "$STUB_BIN/gh"

    LIB="$FRAMEWORK_ROOT/lib/release.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_release() {
    run env PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" \
        bash -c "source '$LIB'; release_tag_and_release $*" 2>&1
}

_parity() {
    run bash -c "source '$LIB'; release_version_tag_parity '$1'"
}

_has_tag() { git -C "$REPO" rev-parse -q --verify "refs/tags/$1" >/dev/null 2>&1; }
_no_tag()  { ! git -C "$REPO" rev-parse -q --verify "refs/tags/$1" >/dev/null 2>&1; }

# ── release_version_lt: the compare must be numeric, not lexical ─────────

@test "version_lt: 1.6.72 < 1.6.176 (the origin pair — lexical compare inverts it)" {
    run bash -c "source '$LIB'; release_version_lt 1.6.72 1.6.176"
    [ "$status" -eq 0 ]
}

@test "version_lt: 1.6.176 is NOT < 1.6.72" {
    run bash -c "source '$LIB'; release_version_lt 1.6.176 1.6.72"
    [ "$status" -ne 0 ]
}

@test "version_lt: equal versions are not less" {
    run bash -c "source '$LIB'; release_version_lt 1.6.72 1.6.72"
    [ "$status" -ne 0 ]
}

@test "version_lt: minor boundary 1.5.999 < 1.6.0" {
    run bash -c "source '$LIB'; release_version_lt 1.5.999 1.6.0"
    [ "$status" -eq 0 ]
}

@test "version_lt: non-numeric input is not-less, not an error" {
    run bash -c "source '$LIB'; release_version_lt garbage 1.0.0"
    [ "$status" -ne 0 ]
}

# ── A1/A3: monotonic release reconciles; decreasing release refuses ──────

@test "monotonic release passes and reconciles VERSION to the new tag" {
    _release
    [ "$status" -eq 0 ]
    _has_tag v1.0.1
    [ "$(cat "$REPO/VERSION")" = "1.0.1" ]
}

@test "the TAGGED COMMIT carries the reconciled VERSION (not just the worktree)" {
    _release
    [ "$status" -eq 0 ]
    [ "$(git -C "$REPO" show v1.0.1:VERSION)" = "1.0.1" ]
}

@test "the reconcile commit rides into the master fast-forward" {
    _release
    [ "$status" -eq 0 ]
    [ "$(git -C "$REPO" rev-parse master)" = "$(git -C "$REPO" rev-parse bleeding-edge)" ]
    [ "$(git -C "$REPO" show master:VERSION)" = "1.0.1" ]
}

@test "vendored .agentic-framework/VERSION is reconciled alongside" {
    mkdir -p "$REPO/.agentic-framework"
    echo "0.9.9" > "$REPO/.agentic-framework/VERSION"
    git -C "$REPO" add .agentic-framework/VERSION
    git -C "$REPO" commit -qm "T-0: vendored"
    _release
    [ "$status" -eq 0 ]
    [ "$(cat "$REPO/.agentic-framework/VERSION")" = "1.0.1" ]
}

@test "REFUSES when the tag would DECREASE VERSION" {
    echo "2.0.0" > "$REPO/VERSION"
    git -C "$REPO" add VERSION; git -C "$REPO" commit -qm "T-0: ahead"
    _release
    [ "$status" -ne 0 ]
    [[ "$output" =~ "REFUSING to release" ]]
    [[ "$output" =~ "DECREASE" ]]
}

@test "the DECREASE refusal leaves NO tag behind and VERSION untouched" {
    echo "2.0.0" > "$REPO/VERSION"
    git -C "$REPO" add VERSION; git -C "$REPO" commit -qm "T-0: ahead"
    _release
    _no_tag v1.0.1
    [ "$(cat "$REPO/VERSION")" = "2.0.0" ]
}

@test "--dry-run REPORTS the reconciliation it would perform" {
    _release --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "would reconcile VERSION" ]]
    [[ "$output" =~ "1.0.0" ]]
    [[ "$output" =~ "1.0.1" ]]
}

@test "--dry-run reconciles NOTHING (VERSION and tags untouched)" {
    _release --dry-run
    [ "$(cat "$REPO/VERSION")" = "1.0.0" ]
    _no_tag v1.0.1
}

@test "--dry-run also refuses the decreasing case (refusal fires before the report)" {
    echo "2.0.0" > "$REPO/VERSION"
    git -C "$REPO" add VERSION; git -C "$REPO" commit -qm "T-0: ahead"
    _release --dry-run
    [ "$status" -ne 0 ]
    [[ "$output" =~ "REFUSING to release" ]]
}

@test "SCOPE: a repo with NO VERSION file releases without reconciling (consumer shape)" {
    git -C "$REPO" rm -q VERSION
    git -C "$REPO" commit -qm "T-0: drop VERSION"
    _release
    [ "$status" -eq 0 ]
    _has_tag v1.0.1
    [ ! -f "$REPO/VERSION" ]
}

# ── A2: doctor parity predicate ──────────────────────────────────────────

@test "parity: VERSION below tag -> behind (the FAIL state)" {
    echo "0.5.0" > "$REPO/VERSION"
    _parity "$REPO"
    [ "$output" = "behind 0.5.0 1.0.0" ]
}

@test "parity: VERSION equals tag -> ok" {
    _parity "$REPO"
    [ "$output" = "ok 1.0.0 1.0.0" ]
}

@test "parity: VERSION above tag -> ahead (allowed, not a FAIL)" {
    echo "1.0.5" > "$REPO/VERSION"
    _parity "$REPO"
    [ "$output" = "ahead 1.0.5 1.0.0" ]
}

@test "parity: no tags reachable -> no-tags (doctor stays silent)" {
    NOTAG="$TEST_TEMP_DIR/notag"; mkdir -p "$NOTAG"
    git -C "$NOTAG" init -q -b main
    git -C "$NOTAG" config user.email t@t.t; git -C "$NOTAG" config user.name t
    echo "1.0.0" > "$NOTAG/VERSION"
    git -C "$NOTAG" add VERSION; git -C "$NOTAG" commit -qm "T-0: seed"
    _parity "$NOTAG"
    [ "$output" = "no-tags" ]
}

@test "parity: no .git -> no-git (vendored consumer copy stays silent)" {
    NOGIT="$TEST_TEMP_DIR/nogit"; mkdir -p "$NOGIT"
    echo "1.0.0" > "$NOGIT/VERSION"
    _parity "$NOGIT"
    [ "$output" = "no-git" ]
}

@test "parity: no VERSION file -> no-version (nothing to disagree)" {
    git -C "$REPO" rm -q VERSION >/dev/null
    git -C "$REPO" commit -qm "T-0: drop VERSION"
    rm -f "$REPO/VERSION"
    _parity "$REPO"
    [ "$output" = "no-version" ]
}

@test "doctor WIRING: bin/fw's doctor calls the parity predicate and can FAIL on it" {
    grep -q "release_version_tag_parity" "$FRAMEWORK_ROOT/bin/fw"
    grep -A6 'behind)' "$FRAMEWORK_ROOT/bin/fw" | grep -q 'issues=\$((issues + 1))'
}

# ── fw version sync downgrade guard (the regression vector) ──────────────

@test "version sync REFUSES to write a counter below the latest tag" {
    # FW_VERSION is the resetting counter (1.0.2); the tag floor is v1.5.0.
    git -C "$REPO" tag v1.5.0
    echo "1.5.0" > "$REPO/VERSION"
    run env FW_VERSION="1.0.2" NO_COLOR=1 bash -c "
        FRAMEWORK_ROOT='$REPO' PROJECT_ROOT='$REPO'
        source '$FRAMEWORK_ROOT/lib/version.sh'
        do_version_sync"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "REFUSING to sync" ]]
    [ "$(cat "$REPO/VERSION")" = "1.5.0" ]
}

@test "CONTROL: version sync above the tag floor still syncs" {
    echo "0.9.0" > "$REPO/VERSION"
    run env FW_VERSION="1.2.0" NO_COLOR=1 bash -c "
        FRAMEWORK_ROOT='$REPO' PROJECT_ROOT='$REPO'
        source '$FRAMEWORK_ROOT/lib/version.sh'
        do_version_sync"
    [ "$status" -eq 0 ]
    [ "$(cat "$REPO/VERSION")" = "1.2.0" ]
}

# ── Hygiene ──────────────────────────────────────────────────────────────

@test "bash -n clean on every edited file" {
    bash -n "$FRAMEWORK_ROOT/lib/release.sh"
    bash -n "$FRAMEWORK_ROOT/lib/version.sh"
    bash -n "$FRAMEWORK_ROOT/bin/fw"
}
