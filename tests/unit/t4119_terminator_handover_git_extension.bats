#!/usr/bin/env bats
# T-4119 (832 T-1140): the terminator's handover limit is a floor, not a ceiling.
# Measured in 832: the agent's commit spent 59 s in post-commit hooks, then the push ran;
# the terminator's fw handover --commit hit a fixed 180 s limit at 'Auto-committing
# handover' (rc=124) and claude was killed mid-push. The limit now extends while a git
# process of the project is still running, up to FW_TERMINATOR_HANDOVER_MAX.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    T="$(mktemp -d)"
    ROOT="$T/proj"
    mkdir -p "$ROOT/.context/handovers" "$ROOT/.context/working" "$ROOT/bin" "$T/stubbin" "$T/elsewhere"
    LOG="$ROOT/.context/working/.compact-log"
    # Stub git: a process named `git` (so /proc comm is "git") that lives GIT_STUB_SECS in
    # GIT_STUB_DIR — stands in for a commit whose post-commit hooks or push are running.
    cat > "$T/stubbin/git" <<'SH'
#!/bin/bash
cd "${GIT_STUB_DIR:-.}" && sleep "${GIT_STUB_SECS:-1}"
SH
    chmod +x "$T/stubbin/git"
    export PATH="$T/stubbin:$PATH"
    # Fake fw: `handover --commit` does its git work (the stub), then writes LATEST.md.
    cat > "$ROOT/bin/fw" <<'SH'
#!/bin/bash
[ "$1" = handover ] || exit 9
case "${FAKE_HANDOVER:-git}" in
    hang) sleep 60 ;;
    git)  git ;;
esac
echo "handover $(date +%s)" > "$PWD/.context/handovers/LATEST.md"
SH
    chmod +x "$ROOT/bin/fw"
    eval "$(awk '/^_ensure_handover_before_kill\(\) \{/,/^}/' "$FRAMEWORK_ROOT/bin/claude-fw")"
    eval "$(awk '/^_handover_git_busy\(\) \{/,/^}/' "$FRAMEWORK_ROOT/bin/claude-fw")"
    eval "$(awk '/^_bounded_handover\(\) \{/,/^}/' "$FRAMEWORK_ROOT/bin/claude-fw")"
    unset FW_TERMINATOR_HANDOVER_TIMEOUT FW_TERMINATOR_HANDOVER_MAX GIT_STUB_DIR GIT_STUB_SECS
}

teardown() {
    rm -rf "$T"
}

@test "T-4119: git still running at the limit is NOT cut there — handover completes" {
    # T-4300: at a 2 s limit this test went red under CPU overload (the fw stub had not
    # reached its git call when /proc was checked, so there was no git to extend for). The
    # limit is a timing fixture, not the behaviour under test; 6 s / 12 s keeps the assertion
    # (git alive at the limit → handover completes) and survives a loaded host.
    export FW_TERMINATOR_HANDOVER_TIMEOUT=6 FW_TERMINATOR_HANDOVER_MAX=60 GIT_STUB_SECS=12
    run _ensure_handover_before_kill "$ROOT" "$(date +%s)"
    [ "$status" -eq 0 ]
    [ -f "$ROOT/.context/handovers/LATEST.md" ]
    grep -q "\[terminator\] Handover generated" "$LOG"
}

@test "T-4119: no git in flight at the limit — a hang is still cut at the limit" {
    export FAKE_HANDOVER=hang FW_TERMINATOR_HANDOVER_TIMEOUT=1 FW_TERMINATOR_HANDOVER_MAX=60
    start=$(date +%s)
    run _ensure_handover_before_kill "$ROOT" "$(date +%s)"
    [ "$status" -eq 1 ]
    [ $(( $(date +%s) - start )) -lt 15 ]
    grep -q "\[terminator\] Handover FAILED (rc=124)" "$LOG"
}

@test "T-4119: git still running past FW_TERMINATOR_HANDOVER_MAX is cut at the ceiling" {
    export FW_TERMINATOR_HANDOVER_TIMEOUT=1 FW_TERMINATOR_HANDOVER_MAX=3 GIT_STUB_SECS=60
    start=$(date +%s)
    run _ensure_handover_before_kill "$ROOT" "$(date +%s)"
    [ "$status" -eq 1 ]
    [ $(( $(date +%s) - start )) -lt 20 ]
    grep -q "\[terminator\] Handover FAILED (rc=124)" "$LOG"
}

@test "T-4119: a git process outside the project root does not extend the limit" {
    export FW_TERMINATOR_HANDOVER_TIMEOUT=1 FW_TERMINATOR_HANDOVER_MAX=60 \
        GIT_STUB_SECS=60 GIT_STUB_DIR="$T/elsewhere"
    start=$(date +%s)
    run _ensure_handover_before_kill "$ROOT" "$(date +%s)"
    [ "$status" -eq 1 ]
    [ $(( $(date +%s) - start )) -lt 15 ]
    grep -q "\[terminator\] Handover FAILED (rc=124)" "$LOG"
}
