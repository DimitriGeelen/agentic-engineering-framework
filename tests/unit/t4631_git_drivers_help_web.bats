#!/usr/bin/env bats
#
# T-4631 (SECURITY, G-121, low): ring20-dashboard round 2 (msg 9e201103) reported that
# git diff --ext-diff, git log --ext-diff -p, git show/cat-file --textconv and git help -w
# classify SAFE although they run a program named by configuration (help -w: a browser).
#
# Decision (task file, ## Decisions): git help -w / --web is refused
# (_fw_git_help_opens_browser). --ext-diff / --textconv stay admitted: measured on git
# 2.43, plain git diff already runs diff.external and plain diff/show/log -p already run
# textconv, so refusing the flags closes nothing. What IS pinned here is that the command
# line cannot choose the driver: GIT_EXTERNAL_DIFF, -c, GIT_CONFIG_* and an outside -C
# stay refused. Classification only: nothing here is executed.
#
# `! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions use
# `if cmd; then false; fi`.

load helpers/known_cwd

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    known_cwd_setup
    cd "$ROOT"
    source "$ROOT/agents/context/lib/safe-commands.sh"
}

teardown() { known_cwd_teardown; }

_refused() {
    local c
    for c in "$@"; do
        if is_bash_safe_command "$c"; then echo "SAFE (expected gated): $c"; return 1; fi
    done
}

_safe() {
    local c
    for c in "$@"; do
        is_bash_safe_command "$c" || { echo "gated (expected SAFE): $c"; return 1; }
    done
}

@test "T-4631: git help -w / --web is NOT SAFE in any spelling" {
    _refused "git help -w log" "git help --web log" "git help --we log" "git help --w log" \
        "git help -aw" "git -C . help -w log" "git help '-w' log" 'git help "$O" log' \
        "git help -{w,a} log"
}

@test "T-4631: the command line cannot choose a diff driver or textconv program" {
    _refused "GIT_EXTERNAL_DIFF=/tmp/x git diff" "git -c diff.external=/tmp/x diff" \
        "GIT_CONFIG_PARAMETERS='diff.external=/tmp/x' git diff" \
        "GIT_CONFIG_COUNT=1 git show --textconv HEAD" "git -C /tmp diff --ext-diff" \
        "git -c diff.tc.textconv=/tmp/x show --textconv HEAD"
}

@test "T-4631: the reported read forms stay SAFE (decision: configured drivers are trusted)" {
    _safe "git diff" "git diff --ext-diff" "git log --ext-diff -p -1" "git show --textconv HEAD" \
        "git cat-file --textconv HEAD:README.md"
}

@test "T-4631: other git help forms and the G-121 controls stay SAFE" {
    _safe "git help log" "git help -a" "git help --guides" "git help --all" "git help -g" \
        "git help --config" "git status" "git log --oneline -3"
}
