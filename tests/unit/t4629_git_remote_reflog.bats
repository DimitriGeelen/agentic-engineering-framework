#!/usr/bin/env bats
#
# T-4629 (SECURITY, G-121): the read-only allowlist admitted `git remote` and
# `git reflog` by verb name. remote add|remove|set-url|... writes .git/config;
# reflog expire|delete|drop destroys history. Reported by ring20-dashboard round 2
# (msg 9e201103).
#
# Fix: agents/context/lib/safe-commands.sh _fw_git_mixed_verb_is_read — decided on the
# sub-verb (dequoted words). Classification only: nothing here is executed.
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

@test "T-4629: the probe's git remote and git reflog lines are NOT SAFE" {
    _refused "git remote add x /tmp/y" "git remote remove origin" \
        "git remote set-url origin /tmp/y" "git reflog expire --expire=now --all" \
        "git reflog delete HEAD@{0}"
}

@test "T-4629: every other git remote write sub-verb, and -v before one, is NOT SAFE" {
    _refused "git remote rm origin" "git remote rename origin x" "git remote set-head origin -a" \
        "git remote set-branches origin x" "git remote prune origin" "git remote update" \
        "git remote -v add x y" "git remote --verbose set-url origin y" "git remote --bogus" \
        "git -C . remote add x y"
}

@test "T-4629: git reflog drop and write sub-verbs behind options are NOT SAFE" {
    _refused "git reflog drop" "git reflog --all expire" "git -C . reflog expire --all"
}

@test "T-4629: quoted or expanded spellings are NOT SAFE" {
    _refused "git remote 'add' x y" "git remote a\"dd\" x y" 'git remote "$V" x y' \
        "git reflog 'expire' --all" 'git reflog "$V"' "git remote {add,x} y"
}

@test "T-4629: read forms and the G-121 controls stay SAFE" {
    _safe "git remote" "git remote -v" "git remote --verbose" "git remote show origin" \
        "git remote -v show origin" "git remote get-url origin" "git remote get-url --push origin" \
        "git reflog" "git reflog show HEAD" "git reflog list" "git reflog exists HEAD" \
        "git reflog -n 5" "git reflog --date=iso" "git status" "git log --oneline -3"
}
