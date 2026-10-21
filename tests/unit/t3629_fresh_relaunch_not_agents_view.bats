#!/usr/bin/env bats
# T-3629 — a fresh relaunch must never hand `claude` an empty argv.
#
# Claude Code 2.1.28x opens its AGENTS OVERVIEW, not a conversation, when it is
# started with no arguments and the user's ~/.claude.json has
# `defaultToAgentsView: true` (binary: the agents-view branch is gated on an argv
# that is empty apart from debug flags). T-3166 relaunches fresh sessions with
# CLAUDE_ARGS=(), so on such a host every restarted fleet agent sat idle in the
# overview — 9 of 13 on 055's .107 — with the injected handover and directive
# addressed to a session that did not exist. Any real argument takes the
# conversation path; `-n <name>` is the one 055 measured.
#
# The stub records argv one argument per field (argc first), so a name that
# contains a space — which the TermLink path would split, since it joins
# CLAUDE_ARGS with spaces — is visible as an extra field rather than hidden.

# T-3747: since T-3684 every claude-fw launch starts an always-on sidecar for
# its project; under a fixture it outlives the test, writes into the deleted
# tmpdir (teardown "Directory not empty") and slowed files past the suite cap.
export CLAUDE_FW_NO_SIDECAR=1

load ../test_helper

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

    SIGNAL="${TDIR}/.context/working/.restart-requested"
    ARGV="${TDIR}/.stub-argv"
}

teardown() { rm -rf "$TDIR"; }

write_signal() {
    cat > "$SIGNAL" <<EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","session_id":"s1","reason":"critical_budget_auto_handover","tokens":300000}
EOF
}

arm() { printf 'enabled: true\ncurrent_iteration: 0\n' \
        > "${TDIR}/.context/working/.continuous-mode.yaml"; }

run_interactive() {
    cd "$TDIR" || return 1
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" \
        FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 \
        FW_MAX_RESTARTS=2 FW_RESTART_WINDOW=3600 \
        timeout 180 bash "$WRAPPER" "$@"
}

relaunch_argv() { [ -f "$ARGV" ] && tail -n +2 "$ARGV" || true; }

# assert_named_relaunches — at least one relaunch, and every one is exactly
# `-n <name>` with a whitespace-free name.
assert_named_relaunches() {
    [ "$(relaunch_argv | wc -l)" -ge 1 ]
    local argc a1 a2 rest
    while IFS=$'\t' read -r argc a1 a2 rest; do
        [ "$argc" = "2" ]
        [ "$a1" = "-n" ]
        [ -n "$a2" ]
        [[ "$a2" != *[[:space:]]* ]]
        [[ "$a2" != -* ]]
    done < <(relaunch_argv)
}

@test "budget restart relaunches with -n <name>, never an empty argv" {
    write_signal
    run_interactive
    assert_named_relaunches
}

@test "armed re-arm relaunches with -n <name>, never an empty argv" {
    arm
    run_interactive
    assert_named_relaunches
}

@test "the first launch keeps the user's own argv untouched" {
    run_interactive --model sonnet
    [ "$(head -1 "$ARGV")" = "$(printf '2\t--model\tsonnet')" ]
}

# T-4048 (055 T-491 proposal A): a bare FIRST launch hit the same agents view and
# parked the conversation as a tty-less background job, so it is named too.
@test "a bare first launch is named -n fw-<dir>, never an empty argv (T-4048)" {
    run_interactive
    base=$(printf '%s' "${TDIR##*/}" | tr -c 'A-Za-z0-9._-' '-')
    [ "$(head -1 "$ARGV")" = "$(printf '2\t-n\tfw-%s' "$base")" ]
}

@test "mutation (T-4048): with the first-launch leg removed the bare launch argv is empty" {
    pre="${TDIR}/claude-fw.firstlaunch"
    sed 's/^        CLAUDE_ARGS=("-n" "fw-\${base}")$/        :/' "$REPO/bin/claude-fw" > "$pre"
    if cmp -s "$pre" "$REPO/bin/claude-fw"; then
        echo "mutation did not land"; false
    fi
    bash -n "$pre"
    WRAPPER="$pre" run_interactive
    [ "$(head -1 "$ARGV")" = "0" ]
}

# Since T-4497 a continue relaunch never hands claude a bare -c: it becomes
# --resume <id> (covered by t4497_claude_fw_continue_not_worker.bats), or, with no
# interactive transcript to continue — this fixture has none — a fresh, named run.
@test "FW_RESTART_MODE=continue with nothing to continue relaunches named, never bare -c or empty" {
    write_signal
    cd "$TDIR" || return 1
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" \
        FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 FW_RESTART_MODE=continue \
        FW_MAX_RESTARTS=2 FW_RESTART_WINDOW=3600 \
        timeout 180 bash "$WRAPPER"
    assert_named_relaunches
}

@test "mutation: without the guard the relaunch argv is empty (the suite can fail)" {
    pre="${TDIR}/claude-fw.prefix"
    sed '/_name_fresh_relaunch # T-3629/d' "$REPO/bin/claude-fw" > "$pre"
    if cmp -s "$pre" "$REPO/bin/claude-fw"; then
        echo "mutation did not land"; false
    fi
    bash -n "$pre"
    write_signal
    WRAPPER="$pre" run_interactive
    [ "$(relaunch_argv | head -1)" = "0" ]
}
