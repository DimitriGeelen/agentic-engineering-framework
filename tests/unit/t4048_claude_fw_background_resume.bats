#!/usr/bin/env bats
# T-4048 (055 T-491 proposal B) — claude-fw must not --resume a conversation that is
# a live Claude Code background job.
#
# Claude Code keeps background jobs (`claude --bg`, and a bare `claude` the agents
# view parks in the shared daemon) under ~/.claude/jobs/<first 8 of the session
# id>/state.json. `--resume <id>` of a live one becomes a `claude attach` viewer, not
# a conversation on the wrapper's tty, so claude-fw's typing path (T-4003) cannot
# reach it and the operator gains one more hidden conversation (055: 7 in one day).
# The wrapper refuses with exit 3 and names the way to foreground it.

export CLAUDE_FW_NO_SIDECAR=1

load ../test_helper

ID="0123abcd-1111-2222-3333-444455556666"

setup() {
    REPO="$FRAMEWORK_ROOT"
    WRAPPER="${FW_TEST_WRAPPER:-${REPO}/bin/claude-fw}"
    TDIR="$(mktemp -d)"
    guard_project_root "$TDIR"
    mkdir -p "${TDIR}/.context/working" "${TDIR}/stubbin"
    git -C "$TDIR" init -q
    git -C "$TDIR" config user.email t@t.t
    git -C "$TDIR" config user.name t

    cat > "${TDIR}/stubbin/claude" <<'STUB'
#!/bin/bash
root=$(git rev-parse --show-toplevel 2>/dev/null)
{ printf '%s' "$#"; for a in "$@"; do printf '\t%s' "$a"; done; printf '\n'; } >> "${root}/.stub-argv"
exit 0
STUB
    chmod +x "${TDIR}/stubbin/claude"
    ARGV="${TDIR}/.stub-argv"
    # T-5429: a job is live only while a daemon listens. Default fixture: one is
    # listening (St 01, a cc-daemon control.sock), so the T-4048 cases keep their meaning.
    NETUNIX="${TDIR}/net-unix"
    daemon_listening
}

# daemon_listening / daemon_gone — the /proc/net/unix view the guard reads.
daemon_listening() {
    printf 'Num       RefCount Protocol Flags    Type St Inode Path\n' > "$NETUNIX"
    printf '0000000000000000: 00000002 00000000 00010000 0001 01 4242 /tmp/cc-daemon-0/abcd1234/control.sock\n' >> "$NETUNIX"
}
daemon_gone() {
    printf 'Num       RefCount Protocol Flags    Type St Inode Path\n' > "$NETUNIX"
    printf '0000000000000000: 00000002 00000000 00010000 0001 01 4243 /run/systemd/private\n' >> "$NETUNIX"
}
# daemon_log <lines…> — write the daemon log the guard reads.
daemon_log() { mkdir -p "${TDIR}/.claude"; printf '%s\n' "$@" > "${TDIR}/.claude/daemon.log"; }

teardown() { rm -rf "$TDIR"; }

# job <state> [sessionId] — write a background-job record under the fixture HOME.
job() {
    mkdir -p "${TDIR}/.claude/jobs/${ID:0:8}"
    printf '{"state":"%s","sessionId":"%s","daemonShort":"%s","backend":"daemon"}\n' \
        "$1" "${2:-$ID}" "${ID:0:8}" > "${TDIR}/.claude/jobs/${ID:0:8}/state.json"
}

launch() {
    cd "$TDIR" || return 1
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" FW_CC_PROC_NET_UNIX="$NETUNIX" \
        FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 \
        timeout 120 bash "$WRAPPER" --no-restart "$@"
}

@test "--resume of a live background job is refused with exit 3 and foreground guidance" {
    job blocked
    launch --resume "$ID"
    [ "$status" -eq 3 ]
    [[ "$output" == *"BACKGROUND job"* ]]
    [[ "$output" == *"claude stop ${ID:0:8} && claude-fw --resume $ID"* ]]
    [ ! -f "$ARGV" ]
}

@test "-r <id> and --resume=<id> are refused the same way" {
    job running
    launch -r "$ID"
    [ "$status" -eq 3 ]
    [ ! -f "$ARGV" ]
    launch "--resume=$ID"
    [ "$status" -eq 3 ]
    [ ! -f "$ARGV" ]
}

@test "a stopped (or done/failed) job resumes normally" {
    for st in stopped done failed; do
        job "$st"
        rm -f "$ARGV"
        launch --resume "$ID"
        [ "$status" -eq 0 ]
        [ "$(head -1 "$ARGV")" = "$(printf '2\t--resume\t%s' "$ID")" ]
    done
}

@test "no job record, or a record for another session, resumes normally" {
    launch --resume "$ID"
    [ "$status" -eq 0 ]
    [ "$(head -1 "$ARGV")" = "$(printf '2\t--resume\t%s' "$ID")" ]
    rm -f "$ARGV"
    job blocked "0123abcd-ffff-ffff-ffff-ffffffffffff"
    launch --resume "$ID"
    [ "$status" -eq 0 ]
    [ -f "$ARGV" ]
}

@test "FW_ALLOW_BACKGROUND_RESUME=1 overrides with a warning" {
    job blocked
    cd "$TDIR" || return 1
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" FW_CC_PROC_NET_UNIX="$NETUNIX" FW_ALLOW_BACKGROUND_RESUME=1 \
        FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 \
        timeout 120 bash "$WRAPPER" --no-restart --resume "$ID"
    [ "$status" -eq 0 ]
    [[ "$output" == *"resuming anyway"* ]]
    [ "$(head -1 "$ARGV")" = "$(printf '2\t--resume\t%s' "$ID")" ]
}

@test "mutation: without the guard call the live job is resumed (the suite can fail)" {
    pre="${TDIR}/claude-fw.noguard"
    sed '/_background_job_guard "\$_id" || return 1   # T-4048/d' "$REPO/bin/claude-fw" > "$pre"
    if cmp -s "$pre" "$REPO/bin/claude-fw"; then
        echo "mutation did not land"; false
    fi
    bash -n "$pre"
    job blocked
    WRAPPER="$pre" launch --resume "$ID"
    [ "$status" -eq 0 ]
    [ -f "$ARGV" ]
}


# ── T-5429 (055 T-774): state.json is not rewritten when the daemon settles a job ──

@test "T-5429: no daemon listening (after a host restart) — a 'blocked' job resumes normally" {
    job blocked
    daemon_gone
    launch --resume "$ID"
    [ "$status" -eq 0 ]
    [ "$(head -1 "$ARGV")" = "$(printf '2\t--resume\t%s' "$ID")" ]
}

@test "T-5429: daemon listening but the log settled the job after its last start — resumes" {
    job blocked
    daemon_log "[2026-09-21T19:00:44.914Z] [bg] bg spawned ${ID:0:8} (spare)" \
               "[2026-09-21T20:34:10.707Z] [bg] bg retire ${ID:0:8}: idle-prompt, idle 61m" \
               "[2026-09-21T20:34:11.320Z] [bg] bg settled ${ID:0:8} (done)"
    launch --resume "$ID"
    [ "$status" -eq 0 ]
    [ -f "$ARGV" ]
}

@test "T-5429: settled earlier but started again afterwards — still live, refused" {
    job blocked
    daemon_log "[2026-09-21T19:00:00Z] [bg] bg spawned ${ID:0:8} (spare)" \
               "[2026-09-21T20:00:00Z] [bg] bg settled ${ID:0:8} (done)" \
               "[2026-09-22T08:00:00Z] [bg] bg claimed-spare ${ID:0:8} (slash)"
    launch --resume "$ID"
    [ "$status" -eq 3 ]
    [ ! -f "$ARGV" ]
}

@test "T-5429: neither source readable — the state decides as before (refused)" {
    job blocked
    NETUNIX="${TDIR}/does-not-exist"
    launch --resume "$ID"
    [ "$status" -eq 3 ]
    [ ! -f "$ARGV" ]
}
