#!/usr/bin/env bats
# T-4364: an unattended `fw release` refuses without a recorded release decision for that
# version, before any tag / VERSION / master change. Dry-run and interactive runs are not refused.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    ORIGIN="$TEST_TEMP_DIR/origin.git"
    REPO="$TEST_TEMP_DIR/repo"
    git init -q --bare -b master "$ORIGIN"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    git -C "$REPO" config commit.gpgsign false
    echo 1.0.0 > "$REPO/VERSION"
    echo base > "$REPO/f"; git -C "$REPO" add f VERSION; git -C "$REPO" commit -qm c1
    git -C "$REPO" tag v1.0.0
    git -C "$REPO" remote add origin "$ORIGIN"
    git -C "$REPO" push -q origin master v1.0.0
    git -C "$REPO" checkout -q -b bleeding-edge
    echo dev > "$REPO/f2"; git -C "$REPO" add f2; git -C "$REPO" commit -qm "T-1: dev"
    STUB_BIN="$TEST_TEMP_DIR/bin"; mkdir -p "$STUB_BIN"
    printf '#!/bin/sh\nexit 0\n' > "$STUB_BIN/gh"; chmod +x "$STUB_BIN/gh"
    LIB="$FRAMEWORK_ROOT/lib/release.sh"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

# stdin is /dev/null (no TTY) => unattended
_fw_release() {
    run env PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" RELEASE_TAG_RETRY_SLEEP=0 \
        bash -c "source '$LIB'; release_main $*" 2>&1 </dev/null
}
_has_tag() { git -C "$1" rev-parse -q --verify "refs/tags/$2" >/dev/null 2>&1; }

@test "unattended release without a decision refuses and changes nothing" {
    local master_before head_before
    master_before="$(git -C "$REPO" rev-parse master)"
    head_before="$(git -C "$REPO" rev-parse HEAD)"
    _fw_release tag-and-release
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSING to release v1.0.1"* ]]
    [[ "$output" == *"fw release decide v1.0.1"* ]]
    [[ "$output" == *"T-4146"* ]]
    if _has_tag "$REPO" v1.0.1; then false; fi
    if _has_tag "$ORIGIN" v1.0.1; then false; fi
    [ "$(git -C "$REPO" rev-parse master)" = "$master_before" ]
    [ "$(git -C "$REPO" rev-parse HEAD)" = "$head_before" ]
    [ "$(cat "$REPO/VERSION")" = "1.0.0" ]
}

@test "a decision for another version does not cover this one" {
    run env PROJECT_ROOT="$REPO" bash -c "source '$LIB'; release_decide v1.0.5 --by operator --ref 'ship it now please'"
    [ "$status" -eq 0 ]
    _fw_release tag-and-release
    [ "$status" -eq 1 ]
    if _has_tag "$REPO" v1.0.1; then false; fi
}

@test "unattended release with a recorded decision proceeds" {
    run env PROJECT_ROOT="$REPO" bash -c "source '$LIB'; release_decide v1.0.1 --by field-evidence --ref 'T-4345'"
    [ "$status" -eq 0 ]
    grep -q '"version": "v1.0.1"' "$REPO/.context/releases/decisions.jsonl"
    _fw_release tag-and-release
    [ "$status" -eq 0 ]
    [[ "$output" == *"Release decision covering v1.0.1"* ]]
    _has_tag "$ORIGIN" v1.0.1
}

@test "dry-run is never refused and reports the missing decision" {
    _fw_release tag-and-release --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"No recorded release decision for v1.0.1"* ]]
    if _has_tag "$REPO" v1.0.1; then false; fi
}

@test "FW_UNATTENDED=1 refuses even when the shell is otherwise interactive-looking" {
    run env FW_UNATTENDED=1 PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" \
        bash -c "source '$LIB'; release_main tag-and-release" 2>&1 </dev/null
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSING"* ]]
}

@test "agent cannot record a bare-id operator decision" {
    run env CLAUDECODE=1 PROJECT_ROOT="$REPO" bash -c "source '$LIB'; release_decide v1.0.1 --by operator --ref T-1"
    [ "$status" -eq 1 ]
    [ ! -e "$REPO/.context/releases/decisions.jsonl" ]
}
