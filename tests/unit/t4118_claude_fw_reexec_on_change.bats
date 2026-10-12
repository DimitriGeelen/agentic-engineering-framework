#!/usr/bin/env bats
# T-4118 — a claude-fw wrapper re-execs its on-disk copy at the restart boundary.
#
# Field reports 832 T-1140 and ring20-dashboard T-2509: a wrapper started before an
# upgrade kept its old bash functions in memory across its own restart loop, so the
# T-4032 "wait for the turn to end" terminator never ran and both sessions were killed
# mid-tool-call. The wrapper now fingerprints itself at start and, between two claude
# runs, execs the file on disk if it changed.
#
# The stub `claude` plays the upgrade: on its FIRST run it writes a fresh restart signal
# and (per $STUB_MODE) rewrites, deletes or breaks the wrapper copy, then exits. Each run
# logs the CFW_TEST_GEN marker the wrapper exported and its argv, so "the second launch
# ran under the new code" is a fact on disk, not an inference.

export CLAUDE_FW_NO_SIDECAR=1

load ../test_helper

setup() {
    REPO="$FRAMEWORK_ROOT"
    SRC="${FW_TEST_WRAPPER:-${REPO}/bin/claude-fw}"
    TDIR="$(mktemp -d)"
    guard_project_root "$TDIR"
    mkdir -p "${TDIR}/.context/working" "${TDIR}/stubbin" "${TDIR}/w"
    git -C "$TDIR" init -q
    git -C "$TDIR" config user.email t@t.t
    git -C "$TDIR" config user.name t

    # The wrapper under test is a COPY, so the stub can "upgrade" it.
    WRAPPER="${TDIR}/w/claude-fw"
    cp "$SRC" "$WRAPPER"
    chmod +x "$WRAPPER"

    cat > "${TDIR}/stubbin/claude" <<'STUB'
#!/bin/bash
root=$(git rev-parse --show-toplevel 2>/dev/null)
n=$(( $(cat "$root/.stub-runs" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$root/.stub-runs"
{ printf 'run=%s gen=%s pid=%s' "$n" "${CFW_TEST_GEN:-old}" "$PPID"
  for a in "$@"; do printf '\t%s' "$a"; done; printf '\n'; } >> "$root/.stub-log"
env | grep -c '^FW_CFW_REEXEC_' >> "$root/.stub-reexec-env" || true
if [ "$n" -eq 1 ]; then
    printf '{"session_id":"s1","tokens":300000}\n' > "$root/.context/working/.restart-requested"
    case "${STUB_MODE:-}" in
        upgrade)
            # Same rename-over shape as an upgrade: a NEW file, the old inode stays with bash.
            sed '1a export CFW_TEST_GEN=new; printf "%s\\n" "$@" > "${PWD}/.reexec-argv"' \
                "$STUB_WRAPPER" > "$STUB_WRAPPER.new"
            mv "$STUB_WRAPPER.new" "$STUB_WRAPPER" ;;
        delete) rm -f "$STUB_WRAPPER" ;;
        broken) printf '\nif then fi ((\n' >> "$STUB_WRAPPER" ;;
    esac
fi
exit 0
STUB
    chmod +x "${TDIR}/stubbin/claude"
    LOG="${TDIR}/.stub-log"
    COMPACT="${TDIR}/.context/working/.compact-log"
    LEDGER="${TDIR}/.context/working/continuous-run.jsonl"
}

teardown() { rm -rf "$TDIR"; }

run_wrapper() {
    local mode="$1"; shift
    cd "$TDIR" || return 1
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" \
        STUB_MODE="$mode" STUB_WRAPPER="$WRAPPER" \
        FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 FW_CLAUDE_FW_NO_TMUX=1 \
        FW_MAX_RESTARTS=3 FW_RESTART_WINDOW=3600 \
        timeout 120 bash "$WRAPPER" "$@"
}

@test "changed on disk: the relaunch runs the NEW wrapper code" {
    run_wrapper upgrade --model "two words"
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$LOG")" -eq 2 ]
    sed -n 1p "$LOG" | grep -q '^run=1 gen=old'
    sed -n 2p "$LOG" | grep -q '^run=2 gen=new'
}

@test "changed on disk: original argv handed to the new copy, restart state carried" {
    run_wrapper upgrade --model "two words"
    # The re-exec'd script saw the user's ORIGINAL argv, word boundaries intact.
    [ "$(cat "${TDIR}/.reexec-argv")" = "$(printf '%s\n' --model 'two words')" ]
    # The relaunch is still restart #1 (T-3629 names it -r1): the count survived exec.
    sed -n 2p "$LOG" | grep -qE $'\t-n\tfw-[^\t]*-r1$'
    # Same pid across the exec: both claude runs are children of one wrapper process.
    [ "$(sed -n 1p "$LOG" | grep -o 'pid=[0-9]*')" = "$(sed -n 2p "$LOG" | grep -o 'pid=[0-9]*')" ]
    # The hand-over env never leaks into claude.
    [ "$(sort -u "${TDIR}/.stub-reexec-env")" = "0" ]
}

@test "changed on disk: one .compact-log line names old and new, ledger records reexec" {
    run_wrapper upgrade
    [ "$(grep -c 're-exec at restart boundary' "$COMPACT")" -eq 1 ]
    grep 're-exec at restart boundary' "$COMPACT" | grep -qE '[0-9a-f]{12} -> [0-9a-f]{12}'
    grep -q '"event": "start", "reason": "reexec"' "$LEDGER"
    # First-launch-only `start armed` is recorded once, not again by the new copy.
    [ "$(grep -c '"reason": "armed"' "$LEDGER")" -eq 1 ]
}

@test "unchanged: no re-exec, no log line" {
    run_wrapper none
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$LOG")" -eq 2 ]
    sed -n 2p "$LOG" | grep -q '^run=2 gen=old'
    if [ -f "$COMPACT" ] && grep -q 're-exec' "$COMPACT"; then false; fi
    if grep -q '"reason": "reexec"' "$LEDGER"; then false; fi
}

@test "script deleted: loud warning, loop continues on in-memory code" {
    run_wrapper delete
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING: cannot read"* ]]
    grep -q 'missing or unreadable' "$COMPACT"
    [ "$(wc -l < "$LOG")" -eq 2 ]
    sed -n 2p "$LOG" | grep -q '^run=2 gen=old'
}

@test "new copy fails bash -n: refused with a warning, loop continues" {
    run_wrapper broken
    [ "$status" -eq 0 ]
    [[ "$output" == *"does not parse"* ]]
    grep -q 're-exec refused' "$COMPACT"
    [ "$(wc -l < "$LOG")" -eq 2 ]
}

@test "FW_CLAUDE_FW_NO_REEXEC=1 opts out" {
    cd "$TDIR" || return 1
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" \
        STUB_MODE=upgrade STUB_WRAPPER="$WRAPPER" FW_CLAUDE_FW_NO_REEXEC=1 \
        FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 FW_CLAUDE_FW_NO_TMUX=1 \
        FW_MAX_RESTARTS=3 FW_RESTART_WINDOW=3600 \
        timeout 120 bash "$WRAPPER"
    [ "$status" -eq 0 ]
    sed -n 2p "$LOG" | grep -q '^run=2 gen=old'
}

@test "a stray FW_CFW_REEXEC_* for another pid is ignored at startup" {
    cd "$TDIR" || return 1
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" \
        STUB_MODE=none STUB_WRAPPER="$WRAPPER" \
        FW_CFW_REEXEC_PID=1 FW_CFW_REEXEC_COUNT=4 \
        FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 FW_CLAUDE_FW_NO_TMUX=1 \
        FW_MAX_RESTARTS=3 FW_RESTART_WINDOW=3600 \
        timeout 120 bash "$WRAPPER"
    [ "$status" -eq 0 ]
    grep -q '"reason": "armed"' "$LEDGER"
    sed -n 2p "$LOG" | grep -qE $'\t-n\tfw-[^\t]*-r1$'
}

@test "resumed copy keeps the restart count and sliding-window budget, skips first-launch steps" {
    # Play the re-exec'd side directly: exec keeps the pid, so FW_CFW_REEXEC_PID=$$ of the
    # exec'ing shell is exactly what the old wrapper hands over. Three restarts already
    # inside the window with FW_MAX_RESTARTS=3 means the carried budget is spent: the run
    # must stop at the budget instead of relaunching, which it would if times were lost.
    cd "$TDIR" || return 1
    now=$(date +%s)
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" \
        STUB_MODE=none STUB_WRAPPER="$WRAPPER" W="$WRAPPER" \
        FW_CFW_REEXEC_COUNT=3 FW_CFW_REEXEC_TIMES="$now $now $now" \
        FW_CFW_REEXEC_OLD_ID=0123456789abcdef \
        FW_CFW_REEXEC_TL_SESSION=claude-master-1 FW_CFW_REEXEC_TL_ENABLED=0 \
        FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 FW_CLAUDE_FW_NO_TMUX=1 \
        FW_MAX_RESTARTS=3 FW_RESTART_WINDOW=3600 \
        timeout 120 bash -c 'exec env FW_CFW_REEXEC_PID=$$ bash "$W"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"now running the updated wrapper (restart #3"* ]]
    [[ "$output" == *"Restart budget exhausted"* ]]
    [ "$(wc -l < "$LOG")" -eq 1 ]
    # restart_count=3 carried: the first launch of the resumed copy is named -r3.
    sed -n 1p "$LOG" | grep -qE $'\t-n\tfw-[^\t]*-r3$'
    # First-launch-only `start armed` is not re-recorded; the reexec event names the old id.
    if grep -q '"reason": "armed"' "$LEDGER"; then false; fi
    grep '"reason": "reexec"' "$LEDGER" | grep -q '0123456789ab ->'
}
