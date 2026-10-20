#!/usr/bin/env bats
# T-4500: pre-release notices say "upgrade from a NON-SHALLOW clone". A shallow
# clone of a -be tag cannot see the consumer's recorded version_sha, so fw upgrade
# refuses it as foreign-source (lib/version-relation.sh, T-3714). The notice must
# say so before the field project clones, and name the unshallow remedy.
# Temp repos only — nothing here tags or pushes the framework repo.

ROOT="${BATS_TEST_DIRNAME}/../.."

setup() {
    TMP="$(mktemp -d)"
    REPO="$TMP/repo"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b bleeding-edge
    git -C "$REPO" config user.email t@t; git -C "$REPO" config user.name t
    echo a > "$REPO/f"; git -C "$REPO" add f; git -C "$REPO" commit -qm a
    git -C "$REPO" tag -a v1.8.13 -m r
    echo b >> "$REPO/f"; git -C "$REPO" commit -qam b
    export PROJECT_ROOT="$REPO"
    unset FW_DEV_BRANCH FW_RELEASE_BRANCH FW_RELEASE_TAG_PATTERN
}
teardown() { rm -rf "$TMP"; }

rel() { ( cd "$REPO"; source "$ROOT/lib/release.sh"; "$@" ); }

render_testing() {
    python3 -c 'import sys, argparse; sys.path.insert(0, sys.argv[1]); import issues
a = argparse.Namespace(stage="available-for-testing", task=["T-1"], text="", version=sys.argv[2], test_cmd="")
sys.stdout.write(issues.render(a, "2026-10-20"))' "$ROOT/lib" "$1"
}

@test "be-tag notice says upgrade from a non-shallow clone, why, and the unshallow remedy" {
    run rel release_be_tag
    [ "$status" -eq 0 ]
    [[ "$output" == *"Tagged"*"v1.8.14-be.1"* ]]
    [[ "$output" == *"NON-SHALLOW clone"* ]]
    [[ "$output" == *"git clone --branch v1.8.14-be.1"* ]]
    [[ "$output" == *"foreign-source"* ]]
    [[ "$output" == *"fetch --unshallow"* ]]
    [[ "$output" != *"--depth 1"* ]]
}

@test "be-tag on an already-tagged HEAD repeats the notice" {
    rel release_be_tag >/dev/null
    run rel release_be_tag
    [ "$status" -eq 0 ]
    [[ "$output" == *"already tagged v1.8.14-be.1"* ]]
    [[ "$output" == *"NON-SHALLOW clone"* ]]
    [[ "$output" == *"fetch --unshallow"* ]]
}

@test "available-for-testing comment for a -be version carries the non-shallow wording" {
    run render_testing v1.8.15-be.1
    [ "$status" -eq 0 ]
    [[ "$output" == *"non-shallow clone"* ]]
    [[ "$output" == *"fetch --unshallow"* ]]
    [[ "$output" == *"foreign-source"* ]]
}

@test "available-for-testing comment for a plain release version has no clone note" {
    run render_testing v1.8.15
    [ "$status" -eq 0 ]
    [[ "$output" != *"non-shallow"* ]]
    [[ "$output" == *"available for testing in **v1.8.15**"* ]]
}
