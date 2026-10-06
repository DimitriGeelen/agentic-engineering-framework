#!/usr/bin/env bats
# T-3942 (832 G-083, ring20-manager 01a8c11d) — a handover is judged by its COMMIT.
#
# handover.sh commits LATEST.md and then pushes; on a slow remote the outer timeout killed
# the run mid-push. The commit had landed, yet the run was logged FAILED, and the budget-
# critical path (checkpoint.sh) skipped the auto-restart signal — a 95 % session ended with
# no restart and the operator read it as a crash. One predicate now decides, used by both
# checkpoint.sh and the claude-fw terminator.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    T="$(mktemp -d)"
    ROOT="$T/proj"
    mkdir -p "$ROOT/.context/handovers" "$ROOT/.context/working" "$ROOT/bin" "$ROOT/lib"
    git -C "$ROOT" init -q && git -C "$ROOT" config user.email t@t && git -C "$ROOT" config user.name t
    cp "$FRAMEWORK_ROOT/lib/handover-lock.sh" "$ROOT/lib/"
    LOG="$ROOT/.context/working/.compact-log"
    # Fake fw: commits LATEST.md, then (FAKE_PUSH=hang) hangs as a slow push would.
    cat > "$ROOT/bin/fw" <<'SH'
#!/bin/bash
[ "$1" = handover ] || exit 9
echo "handover $(date +%s)" > "$PWD/.context/handovers/LATEST.md"
git add .context/handovers/LATEST.md && git commit -qm "Session handover" -- .context/handovers/LATEST.md
[ "${FAKE_PUSH:-ok}" = hang ] && sleep 30
exit 0
SH
    chmod +x "$ROOT/bin/fw"
    source "$FRAMEWORK_ROOT/lib/handover-lock.sh"
    eval "$(awk '/^_ensure_handover_before_kill\(\) \{/,/^}/' "$FRAMEWORK_ROOT/bin/claude-fw")"
    unset FAKE_PUSH FW_TERMINATOR_HANDOVER_TIMEOUT
}

teardown() { rm -rf "$T"; }

@test "T-3942: predicate — a LATEST.md commit at/after the start counts as landed" {
    start=$(date +%s)
    echo x > "$ROOT/.context/handovers/LATEST.md"
    git -C "$ROOT" add .context/handovers/LATEST.md && git -C "$ROOT" commit -qm h
    run fw_handover_landed "$ROOT" "$start"
    [ "$status" -eq 0 ] && [ -n "$output" ]
}

@test "T-3942/control: predicate — a commit from BEFORE the start, or none, is not landed" {
    run fw_handover_landed "$ROOT" "$(date +%s)"          # no commit at all
    [ "$status" -eq 1 ]
    echo x > "$ROOT/.context/handovers/LATEST.md"
    git -C "$ROOT" add .context/handovers/LATEST.md && git -C "$ROOT" commit -qm old
    run fw_handover_landed "$ROOT" "$(( $(date +%s) + 120 ))"   # run started after it
    [ "$status" -eq 1 ]
}

@test "T-3942: terminator — commit landed, push hung past the timeout -> logged generated, not FAILED" {
    export FAKE_PUSH=hang FW_TERMINATOR_HANDOVER_TIMEOUT=3
    run _ensure_handover_before_kill "$ROOT" "$(date +%s)"
    [ "$status" -eq 0 ]
    grep -q "\[terminator\] Handover generated .*landed; push did not finish" "$LOG"
    ! grep -q "Handover FAILED" "$LOG" || false
}

@test "T-3942: checkpoint.sh uses the same predicate before writing the restart signal" {
    grep -q 'fw_handover_landed' "$FRAMEWORK_ROOT/agents/context/checkpoint.sh"
    # the landed branch sets _ah_ok=1, which is what writes .restart-requested
    awk '/fw_handover_landed/,/_ah_ok=1/' "$FRAMEWORK_ROOT/agents/context/checkpoint.sh" | grep -q '_ah_ok=1'
}
