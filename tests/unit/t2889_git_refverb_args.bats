#!/usr/bin/env bats
# T-2889: `git stash`, `git branch` and `git tag` were allowlisted in
# is_bash_safe_command on the sub-verb alone, so their WRITE forms (stash the
# working tree, delete/create refs) passed the task gate's fast path with no
# active task — the dangerous direction (safe-commands.sh header). They are now
# decided by argument inspection (_fw_git_refverb_is_read). Both directions are
# pinned: the write forms are gated AND the read forms stay safe, so neither a
# re-widening nor an over-tightening (null-focus deadlock) slips through.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"
}

_gated() {
    local c
    for c in "$@"; do
        if is_bash_safe_command "$c"; then
            echo "classified SAFE but writes: $c"
            return 1
        fi
    done
}

_safe() {
    local c
    for c in "$@"; do
        if ! is_bash_safe_command "$c"; then
            echo "classified GATED but only reads: $c"
            return 1
        fi
    done
}

@test "T-2889: bare git stash and its write sub-verbs are gated" {
    run _gated "git stash" "git stash push -m wip" "git stash pop" \
        "git stash apply" "git stash drop" "git stash clear" "git stash save x"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "T-2889: git stash list / show stay safe" {
    run _safe "git stash list" "git stash show" "git stash show -p stash@{0}" \
        "git stash list | head -3"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "T-2889: git branch delete/move/copy/create forms are gated" {
    run _gated "git branch -d x" "git branch -D x" "git branch -m a b" \
        "git branch -M a" "git branch -c a b" "git branch -C a b" \
        "git branch --delete x" "git branch --move a b" "git branch --copy a b" \
        "git branch -dr origin/x" "git branch newbranch" 'git branch "quoted"' \
        "git branch --set-upstream-to=origin/x" "git branch -f x HEAD"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "T-2889: git branch listing forms stay safe" {
    run _safe "git branch" "git branch -a" "git branch -r" "git branch -vv" \
        "git branch --list 'feat*'" "git branch --merged master" \
        "git branch --contains abc123" "git branch --show-current" \
        "git branch --show-current 2>/dev/null"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "T-2889: git tag delete and create forms are gated" {
    run _gated "git tag -d v1" "git tag --delete v1" "git tag v1" \
        "git tag -a v1 -m msg" "git tag -s v1" "git tag -f v1"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "T-2889: git tag listing forms stay safe" {
    run _safe "git tag" "git tag -l" "git tag --list 'v*'" \
        "git tag --contains abc123" "git tag -n5" "git tag -v v1"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
}
