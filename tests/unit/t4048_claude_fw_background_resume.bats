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
}

teardown() { rm -rf "$TDIR"; }

# job <state> [sessionId] — write a background-job record under the fixture HOME.
job() {
    mkdir -p "${TDIR}/.claude/jobs/${ID:0:8}"
    printf '{"state":"%s","sessionId":"%s","daemonShort":"%s","backend":"daemon"}\n' \
        "$1" "${2:-$ID}" "${ID:0:8}" > "${TDIR}/.claude/jobs/${ID:0:8}/state.json"
}

launch() {
    cd "$TDIR" || return 1
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" \
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
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" FW_ALLOW_BACKGROUND_RESUME=1 \
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
