#!/usr/bin/env bats
# T-4899: a repo that keeps docs/releases/ must ship a committed, human-readable
# docs/releases/<version>-notes.md with every release. Without it fw release refuses
# before any tag, VERSION or master change; --dry-run reports it. The GitHub release
# leads with the notes and ranges its changelog from the previous release.
# Origin: v1.8.15's GitHub page had only an auto "Full Changelog" link (v1.8.12...v1.8.15).

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
    mkdir -p "$REPO/docs/releases"
    echo "# v1.0.0" > "$REPO/docs/releases/v1.0.0-notes.md"
    echo base > "$REPO/f"; git -C "$REPO" add f VERSION docs; git -C "$REPO" commit -qm c1
    git -C "$REPO" tag v1.0.0
    git -C "$REPO" remote add origin "$ORIGIN"
    git -C "$REPO" push -q origin master v1.0.0
    git -C "$REPO" checkout -q -b bleeding-edge
    echo dev > "$REPO/f2"; git -C "$REPO" add f2; git -C "$REPO" commit -qm "T-1: dev"
    STUB_BIN="$TEST_TEMP_DIR/bin"; mkdir -p "$STUB_BIN"
    GH_LOG="$TEST_TEMP_DIR/gh.args"
    printf '#!/bin/sh\nprintf "%%s\\n" "$@" >> "%s"\nexit 0\n' "$GH_LOG" > "$STUB_BIN/gh"; chmod +x "$STUB_BIN/gh"
    LIB="$FRAMEWORK_ROOT/lib/release.sh"
    # the decision gate is not under test here
    env PROJECT_ROOT="$REPO" bash -c "source '$LIB'; release_decide v1.0.1 --by operator --ref 'test decision'" >/dev/null 2>&1
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_fw_release() {
    run env PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" RELEASE_TAG_RETRY_SLEEP=0 \
        bash -c "source '$LIB'; release_main $*" 2>&1 </dev/null
}
_has_tag() { git -C "$1" rev-parse -q --verify "refs/tags/$2" >/dev/null 2>&1; }

_write_notes() {
    {
        echo "# v1.0.1"
        echo
        for i in $(seq 1 20); do echo "A readable line about change number $i for consumers."; done
    } > "$REPO/docs/releases/v1.0.1-notes.md"
}

@test "missing notes: release refuses, names the file, changes nothing" {
    local master_before; master_before="$(git -C "$REPO" rev-parse master)"
    _fw_release tag-and-release
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSING to release v1.0.1"* ]]
    [[ "$output" == *"docs/releases/v1.0.1-notes.md"* ]]
    if _has_tag "$REPO" v1.0.1; then false; fi
    if _has_tag "$ORIGIN" v1.0.1; then false; fi
    [ "$(git -C "$REPO" rev-parse master)" = "$master_before" ]
    [ "$(cat "$REPO/VERSION")" = "1.0.0" ]
}

@test "a stub notes file (too short) is refused like a missing one" {
    echo "# v1.0.1" > "$REPO/docs/releases/v1.0.1-notes.md"
    git -C "$REPO" add docs; git -C "$REPO" commit -qm "T-1: stub notes"
    _fw_release tag-and-release
    [ "$status" -eq 1 ]
    [[ "$output" == *"are missing"* ]]
}

@test "uncommitted notes are refused" {
    _write_notes
    _fw_release tag-and-release
    [ "$status" -eq 1 ]
    [[ "$output" == *"are uncommitted"* ]]
    if _has_tag "$REPO" v1.0.1; then false; fi
}

@test "dry-run reports missing notes without refusing" {
    _fw_release tag-and-release --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Release notes docs/releases/v1.0.1-notes.md: missing"* ]]
}

@test "committed notes: release proceeds; GitHub release gets the notes and the previous tag" {
    _write_notes
    git -C "$REPO" add docs; git -C "$REPO" commit -qm "T-1: notes"
    _fw_release tag-and-release
    [ "$status" -eq 0 ]
    [[ "$output" == *"Release notes: docs/releases/v1.0.1-notes.md"* ]]
    _has_tag "$ORIGIN" v1.0.1
    grep -qx -- "--notes-file" "$GH_LOG"
    grep -qx -- "$REPO/docs/releases/v1.0.1-notes.md" "$GH_LOG"
    grep -qx -- "--notes-start-tag" "$GH_LOG"
    grep -qx -- "v1.0.0" "$GH_LOG"
}

@test "a repo without docs/releases/ is not affected" {
    git -C "$REPO" rm -rq docs; git -C "$REPO" commit -qm "T-1: no release notes folder"
    _fw_release tag-and-release
    [ "$status" -eq 0 ]
    [[ "$output" != *"Release notes"* ]]
    _has_tag "$ORIGIN" v1.0.1
}
