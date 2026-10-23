#!/usr/bin/env bats
# T-4703: .context/scratch reached 28 GB of release work dirs (v1811, v1812, v1813,
# hotfix) that nothing removed and nothing measured. Two legs:
#   1. release_scratch_prune (lib/release.sh) removes shipped release lanes.
#   2. fw_scratch_size_verdict (lib/scratch-size.sh) backs fw doctor's size WARN.
# Every "kept" assertion sits beside a "removed" one over the same fixture, so a
# prune that never fires cannot pass. Sizes are KB-scale: never write GBs here.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$REPO/.context/scratch"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    echo base > "$REPO/f"; git -C "$REPO" add f; git -C "$REPO" commit -qm c1
    git -C "$REPO" tag v1.8.11
    echo b2 > "$REPO/f"; git -C "$REPO" commit -qam c1b
    git -C "$REPO" tag v1.8.12
    git -C "$REPO" tag v1.8.14-be.1   # pre-release only: v1.8.14 never shipped
    S="$REPO/.context/scratch"
    mkdir -p "$S/v1811/base" "$S/v1812/hf" "$S/hf1812" "$S/v1813" "$S/v1814" \
             "$S/hotfix" "$S/t4489" "$S/v1811-notes" "$TEST_TEMP_DIR/outside"
    echo keep > "$TEST_TEMP_DIR/outside/precious"
    ln -s "$TEST_TEMP_DIR/outside" "$S/hf1811"
    LIB="$FRAMEWORK_ROOT/lib/release.sh"
    STUB_BIN="$TEST_TEMP_DIR/bin"; mkdir -p "$STUB_BIN"
    printf '#!/bin/sh\nexit 0\n' > "$STUB_BIN/gh"; chmod +x "$STUB_BIN/gh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_prune() {
    run bash -c "source '$LIB'; release_scratch_prune '$REPO' '$1' '$2'" 2>&1
}

@test "prune removes the work dirs of releases older than the one being cut" {
    _prune v1.8.13 false
    [ "$status" -eq 0 ]
    [ ! -e "$S/v1811" ]
    [ ! -e "$S/v1812" ]
    [ ! -e "$S/hf1812" ]
    [[ "$output" == *"pruned .context/scratch/v1811"* ]]
}

@test "prune keeps the current release, future, -be-only and unversioned dirs" {
    _prune v1.8.13 false
    [ "$status" -eq 0 ]
    [ -d "$S/v1813" ]        # the release being cut
    [ -d "$S/v1814" ]        # only a -be tag exists
    [ -d "$S/hotfix" ]
    [ -d "$S/t4489" ]
    [ -d "$S/v1811-notes" ]  # name is not exactly v<digits>
    [ ! -e "$S/v1811" ]      # control: the same run did prune
}

@test "prune never follows a symlinked lane name" {
    _prune v1.8.13 false
    [ -L "$S/hf1811" ]
    [ -f "$TEST_TEMP_DIR/outside/precious" ]
    [ ! -e "$S/v1811" ]      # control
}

@test "dry-run names what it would prune and deletes nothing" {
    _prune v1.8.13 true
    [ "$status" -eq 0 ]
    [[ "$output" == *"would prune release work dir"*".context/scratch/v1811"* ]]
    [[ "$output" == *".context/scratch/v1812"* ]]
    [[ "$output" != *"v1813"* ]]
    [ -d "$S/v1811/base" ]
    [ -d "$S/v1812/hf" ]
}

@test "no scratch dir is a quiet no-op" {
    rm -rf "$S"
    _prune v1.8.13 false
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "tag-and-release prunes shipped lanes after a published release" {
    echo more > "$REPO/g"; git -C "$REPO" add g; git -C "$REPO" commit -qm c2
    # bats stdin is no TTY, so the run is unattended: record the decision (T-4364)
    mkdir -p "$REPO/.context/releases"
    echo '{"version": "v1.8.13", "decided_by": "operator", "ref": "t4703 fixture", "ts": "x"}' \
        > "$REPO/.context/releases/decisions.jsonl"
    run env PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" \
        bash -c "source '$LIB'; release_tag_and_release --offline" 2>&1
    git -C "$REPO" rev-parse -q --verify refs/tags/v1.8.13 >/dev/null
    [[ "$output" == *"pruned .context/scratch/v1811"* ]]
    [ ! -e "$S/v1811" ]
    [ ! -e "$S/v1812" ]
    [ -d "$S/v1813" ]
}

# ── size verdict ────────────────────────────────────────────────────────────

_verdict() {
    run bash -c "source '$FRAMEWORK_ROOT/lib/scratch-size.sh'; fw_scratch_size_verdict '$1' '$2'"
}

@test "size verdict WARNs over the threshold and names the largest subdirs" {
    head -c 200000 /dev/zero > "$S/v1813/blob"
    head -c 50000 /dev/zero > "$S/hotfix/blob"
    _verdict "$S" 100
    [ "$status" -eq 1 ]
    [[ "$output" == WARN$'\t'* ]]
    [[ "$output" == *"v1813 "* ]]
    [[ "$output" == *"hotfix "* ]]
}

@test "size verdict is OK under the threshold" {
    head -c 200000 /dev/zero > "$S/v1813/blob"
    _verdict "$S" 1000000
    [ "$status" -eq 0 ]
    [[ "$output" == OK$'\t'* ]]
}

@test "size verdict: missing dir is OK, bad threshold is ERROR" {
    _verdict "$TEST_TEMP_DIR/nope" 10
    [ "$status" -eq 0 ]
    _verdict "$S" 1.5
    [ "$status" -eq 2 ]
    [[ "$output" == ERROR* ]]
}

@test "SCRATCH_WARN_GB is registered with default 10 and wired into fw doctor" {
    run bash -c "source '$FRAMEWORK_ROOT/lib/config.sh'; fw_config SCRATCH_WARN_GB; FW_SCRATCH_WARN_GB=3 fw_config SCRATCH_WARN_GB"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "10" ]
    [ "${lines[1]}" = "3" ]
    grep -q 'fw_scratch_size_verdict "${FW_DOCTOR_SCRATCH_DIR:-$PROJECT_ROOT/.context/scratch}"' "$FRAMEWORK_ROOT/bin/fw"
}
