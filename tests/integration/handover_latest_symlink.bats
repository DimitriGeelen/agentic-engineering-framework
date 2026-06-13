#!/usr/bin/env bats
# T-2374 — handover LATEST.md integrity.
#
# Two silent-failure points produced a dangling LATEST.md after /compact:
#   1. handover.sh updated the LATEST symlink unconditionally, even when the body
#      file was not written → LATEST pointed at nothing.
#   2. fw doctor had no check for it, so the dangle was invisible until a resuming
#      session silently read no handover.
#
# These tests pin the fix:
#   - handover.sh leaves the previous LATEST untouched (and exits non-zero) when the
#     generated body is missing/empty, instead of repointing to a nonexistent file.
#   - fw doctor WARNs on a dangling LATEST.md handover symlink.

setup() {
    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    HANDOVER_SH="$FRAMEWORK_ROOT/agents/handover/handover.sh"
    FW="$FRAMEWORK_ROOT/bin/fw"
    [ -f "$HANDOVER_SH" ] || skip "handover.sh not found"
}

@test "handover.sh: guard refuses to update LATEST when body is empty (no dangling)" {
    # The guard is the last-line invariant: if HANDOVER_FILE is empty, LATEST is
    # left untouched and the script exits non-zero. Verify the guard text exists
    # and is wired before the ln (defense the unit test below exercises directly).
    run grep -n 'if \[ ! -s "\$HANDOVER_FILE" \]' "$HANDOVER_SH"
    [ "$status" -eq 0 ]
    # The guard must appear BEFORE the ln -sf that updates LATEST.md.
    guard_line=$(grep -n 'if \[ ! -s "\$HANDOVER_FILE" \]' "$HANDOVER_SH" | head -1 | cut -d: -f1)
    ln_line=$(grep -n 'ln -sf "\$(basename "\$HANDOVER_FILE")"' "$HANDOVER_SH" | head -1 | cut -d: -f1)
    [ -n "$guard_line" ] && [ -n "$ln_line" ]
    [ "$guard_line" -lt "$ln_line" ]
}

@test "handover guard logic: empty body → LATEST untouched, rc!=0 (extracted invariant)" {
    # Exercise the guard's exact behavior in isolation (the real handover.sh body
    # generation is large; the invariant under test is the guard around ln -sf).
    HDIR="$(mktemp -d)"
    # Pre-existing valid LATEST → a real previous handover.
    echo "previous handover body" > "$HDIR/S-prev.md"
    ln -sf "S-prev.md" "$HDIR/LATEST.md"
    # Simulate a failed generation: HANDOVER_FILE empty.
    HANDOVER_FILE="$HDIR/S-new.md"
    : > "$HANDOVER_FILE"   # zero bytes

    run bash -c '
        HANDOVER_FILE="'"$HANDOVER_FILE"'"; HANDOVER_DIR="'"$HDIR"'"
        if [ ! -s "$HANDOVER_FILE" ]; then
            echo "guard fired" >&2
            exit 1
        fi
        ln -sf "$(basename "$HANDOVER_FILE")" "$HANDOVER_DIR/LATEST.md"
    '
    [ "$status" -eq 1 ]
    # LATEST still points at the previous valid handover, not the empty new one.
    [ "$(readlink "$HDIR/LATEST.md")" = "S-prev.md" ]
    [ -e "$HDIR/LATEST.md" ]   # resolves
    rm -rf "$HDIR"
}

@test "fw doctor: WARNs on a dangling LATEST.md handover symlink" {
    [ -f "$FW" ] || skip "bin/fw not found"
    PROJ="$(mktemp -d)"
    ( cd "$PROJ" && git init -q && git config user.email t@t && git config user.name t \
        && git commit -q --allow-empty -m init )
    mkdir -p "$PROJ/.context/handovers"
    # Dangling: LATEST -> a file that does not exist.
    ln -sf "S-does-not-exist.md" "$PROJ/.context/handovers/LATEST.md"

    run bash -c "cd '$PROJ' && PROJECT_ROOT='$PROJ' '$FW' doctor 2>&1"
    # Doctor is allowed to exit non-zero (warnings); we assert the message fires.
    echo "$output" | grep -qi "Handover LATEST.md is dangling"
    rm -rf "$PROJ"
}
