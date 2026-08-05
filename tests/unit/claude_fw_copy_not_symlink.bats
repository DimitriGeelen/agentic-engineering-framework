#!/usr/bin/env bats
# T-2807 — claude-fw on PATH must be a COPY, not a symlink into $INSTALL_DIR.
#
# install.sh puts two things on PATH and used to treat them differently: the
# router was copied, claude-fw was `ln -sf "$INSTALL_DIR/bin/claude-fw"`. That
# was correct while $INSTALL_DIR was permanent. T-2800 makes the fetched
# framework temporary, so the symlink dangles — and what dangles is the T-179
# auto-restart wrapper, whose failure mode is a session that never recovers at
# budget-critical. Nothing errors; supervision just stops.
#
# Test 3 is the one that is easy to leave out. A `cp` onto an existing symlink
# follows it and writes THROUGH to the target — so an installer that "copies"
# without removing first silently overwrites the global install's own
# bin/claude-fw. That is not hypothetical: it is precisely how T-2793's router
# corruption happened, in this same function.
#
# Test 4 is the non-vacuity pair for 1-3: if install_claude_fw wrote nothing at
# all, 1 and 3 would both pass (no symlink, no modification) and 2 would fail
# for the wrong reason. It pins that the file we asserted about is the wrapper.

bats_require_minimum_version 1.5.0

FWROOT() { (cd "$BATS_TEST_DIRNAME/../.." && pwd); }

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR

    INSTALL_SRC="$(FWROOT)/install.sh"
    [ -f "$INSTALL_SRC" ] || skip "install.sh missing"

    # Source install.sh's function definitions without running main. The file
    # ends in `main "$@"`; strip that one line. Assert the shape first — if the
    # entry point ever moves, this test must fail loudly rather than quietly
    # source a file that no longer defines what it claims to.
    [ "$(tail -1 "$INSTALL_SRC")" = 'main "$@"' ] \
        || fail "install.sh no longer ends in 'main \"\$@\"' — update this harness"

    LIB="$TEST_TEMP_DIR/install-lib.sh"
    sed '$d' "$INSTALL_SRC" > "$LIB"

    # Fake global install holding the wrapper we are about to put on PATH.
    INSTALL_DIR="$TEST_TEMP_DIR/global"
    mkdir -p "$INSTALL_DIR/bin"
    printf '#!/bin/bash\n# fake claude-fw (T-2807 fixture)\necho WRAPPER\n' \
        > "$INSTALL_DIR/bin/claude-fw"
    chmod +x "$INSTALL_DIR/bin/claude-fw"

    LOCAL_BIN="$TEST_TEMP_DIR/bin"
    mkdir -p "$LOCAL_BIN"

    export INSTALL_DIR
    # shellcheck disable=SC1090
    set +u; source "$LIB"; set -u
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

@test "installed claude-fw is a regular file, not a symlink" {
    install_claude_fw "$INSTALL_DIR/bin/claude-fw" "$LOCAL_BIN"
    [ -f "$LOCAL_BIN/claude-fw" ]
    [ ! -L "$LOCAL_BIN/claude-fw" ]
    [ -x "$LOCAL_BIN/claude-fw" ]
}

@test "installed claude-fw survives removal of the global install" {
    install_claude_fw "$INSTALL_DIR/bin/claude-fw" "$LOCAL_BIN"
    rm -rf "$INSTALL_DIR"
    # The whole point: T-2800 deletes this directory.
    [ -x "$LOCAL_BIN/claude-fw" ]
    run "$LOCAL_BIN/claude-fw"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'WRAPPER'
}

@test "installing over a pre-existing symlink does not write through it" {
    # The state every migrating host is actually in: ~/.local/bin/claude-fw is
    # today a symlink into the global install. Without rm -f, `cp` follows it.
    ln -sf "$INSTALL_DIR/bin/claude-fw" "$LOCAL_BIN/claude-fw"
    local before_md5
    before_md5="$(md5sum "$INSTALL_DIR/bin/claude-fw" | cut -d' ' -f1)"

    # A source that differs from the link target, so a write-through is visible.
    local newsrc="$TEST_TEMP_DIR/new-claude-fw"
    printf '#!/bin/bash\n# NEWER wrapper\necho NEWER\n' > "$newsrc"
    chmod +x "$newsrc"

    install_claude_fw "$newsrc" "$LOCAL_BIN"

    [ ! -L "$LOCAL_BIN/claude-fw" ]
    # The global's copy must be byte-identical to what it was.
    [ "$(md5sum "$INSTALL_DIR/bin/claude-fw" | cut -d' ' -f1)" = "$before_md5" ]
    run "$LOCAL_BIN/claude-fw"
    echo "$output" | grep -q 'NEWER'
}

@test "the installed file is the wrapper, byte for byte" {
    # Non-vacuity for 1-3 (see header).
    install_claude_fw "$INSTALL_DIR/bin/claude-fw" "$LOCAL_BIN"
    cmp -s "$INSTALL_DIR/bin/claude-fw" "$LOCAL_BIN/claude-fw"
}

@test "install.sh no longer symlinks claude-fw anywhere" {
    # Both branches of link_fw had their own `ln -sf ... claude-fw`. Catching
    # only the one we remembered is how the second branch survives a refactor.
    #
    # Anchored to exclude comment lines: the fix's own comment quotes the old
    # `ln -sf "$INSTALL_DIR/bin/claude-fw"` line to explain why it went, and an
    # unanchored grep reads that prose as the code it is describing.
    run grep -nE '^[^#]*ln -s.*claude-fw' "$INSTALL_SRC"
    [ "$status" -ne 0 ]
}
