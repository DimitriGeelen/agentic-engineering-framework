#!/usr/bin/env bats
# T-3585: fw release status must not report "Commits since: 0" when the tag
# pattern simply matched nothing (832 OBS-451, designer-vX.Y.Z tags).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    LIB="$FRAMEWORK_ROOT/lib/release.sh"
}
teardown() { rm -rf "$TEST_TEMP_DIR"; }

commit() { echo "$1" >> "$REPO/f"; git -C "$REPO" add f; git -C "$REPO" commit -qm "$1"; }
status() { ( export PROJECT_ROOT="$REPO"; source "$LIB"; release_status ); }

@test "plain vX.Y.Z tags: tag and count are printed" {
    commit a; git -C "$REPO" tag -a v1.2.3 -m x; commit b; commit c
    run status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Latest tag:       v1.2.3"* ]]
    [[ "$output" == *"Commits since:    2"* ]]
}

@test "prefixed designer-vX.Y.Z tags are recognised with commits after" {
    commit a; git -C "$REPO" tag -a designer-v0.9.0 -m x
    commit b; git -C "$REPO" tag -a designer-v1.0.0 -m x
    commit c; commit d; commit e
    run status
    [[ "$output" == *"Latest tag:       designer-v1.0.0"* ]]
    [[ "$output" == *"Commits since:    3"* ]]
    # negative control: 0 is never printed while commits exist
    [[ "$output" != *"Commits since:    0"* ]]
}

@test "configured pattern is honoured" {
    commit a; git -C "$REPO" tag -a rel-7 -m x; commit b
    export FW_RELEASE_TAG_PATTERN='rel-*'
    run status
    [[ "$output" == *"Latest tag:       rel-7"* ]]
    [[ "$output" == *"Commits since:    1"* ]]
}

@test "no tags: reports no matching tag and UNKNOWN, never 0" {
    commit a; commit b; commit c
    run status
    [[ "$output" == *"no tag matching v[0-9]*"* ]]
    [[ "$output" == *"Commits since:    UNKNOWN"* ]]
    [[ "$output" == *"3 commits since the root"* ]]
    [[ "$output" != *"Commits since:    0"* ]]
}

@test "unrelated tag only: pattern miss is UNKNOWN, not 0" {
    commit a; git -C "$REPO" tag -a nightly -m x; commit b
    run status
    [[ "$output" == *"Commits since:    UNKNOWN"* ]]
    [[ "$output" != *"Commits since:    0"* ]]
}
