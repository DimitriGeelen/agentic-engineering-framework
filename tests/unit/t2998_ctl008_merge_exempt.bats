#!/usr/bin/env bats
# T-2998 — CTL-008 must not count git-generated merge subjects as task-less.
#
# The commit-msg hook admits any commit made with MERGE_HEAD set
# (agents/git/lib/hooks.sh), so `git merge --no-ff <branch>` lands with git's
# default subject `Merge branch '<branch>'`. CTL-008 counted that subject as a
# traceability offender (consumer 001-CashWeb, G-008: 2/20 → 90%).
#
# Both directions: a merge is exempt, and a real task-less commit still counts —
# the negative control keeps a "fix" that disables the check from passing.

load ../test_helper

setup() {
    TMPREPO=$(mktemp -d)
    export TMPREPO
    mkdir -p "$TMPREPO/.tasks/completed" "$TMPREPO/.tasks/active" \
             "$TMPREPO/.context/episodic"
    git -C "$TMPREPO" init -q -b main
    git -C "$TMPREPO" config user.email "t2998@localhost"
    git -C "$TMPREPO" config user.name "T-2998 fixture"
    git -C "$TMPREPO" config core.hooksPath /dev/null
    git -C "$TMPREPO" commit -q --allow-empty -m "T-001: first"
    git -C "$TMPREPO" checkout -q -b feature
    git -C "$TMPREPO" commit -q --allow-empty -m "T-002: feature work"
    git -C "$TMPREPO" checkout -q main
    git -C "$TMPREPO" commit -q --allow-empty -m "T-003: main moves on"
    # git-default merge subject: "Merge branch 'feature'"
    git -C "$TMPREPO" merge -q --no-ff --no-edit feature
}

teardown() {
    [ -d "${TMPREPO:-}" ] && rm -rf "$TMPREPO"
    return 0
}

run_ctl008() {
    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section oe-hourly 2>&1
}

@test "fixture holds a two-parent commit with git's default merge subject" {
    run git -C "$TMPREPO" log -1 --format='%p|%s'
    [[ "$output" == *" "*"|Merge branch 'feature'"* ]]
}

@test "git-default merge subject is not a CTL-008 offender" {
    run_ctl008
    [[ "$output" == *"CTL-008: Task reference traceability 100% (0/"*" without T-XXX)"* ]]
    [[ "$output" != *"Merge branch"* ]]
}

@test "negative control: a task-less non-merge commit still counts" {
    git -C "$TMPREPO" commit -q --allow-empty -m "fix typo without task"
    run_ctl008
    [[ "$output" == *"CTL-008: Task reference traceability"*"(1/"*" without T-XXX)"* ]]
}
