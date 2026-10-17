#!/usr/bin/env bats
# T-3746 (832 T-1005): has_bash_write_pattern missed file writes that carry no
# plain `>` — `2>FILE`, `&>FILE`, sed's `w` command / `s///w` flag, and
# `sort -o`/`--output`. check-active-task.sh consults this scan first, so each
# one passed the task gate as a read. The fd-duplication and /dev/null forms
# must stay reads.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"
}

assert_write() {
    run has_bash_write_pattern "$1"
    [ "$status" -eq 0 ] || { echo "expected WRITE: $1"; return 1; }
}

assert_read() {
    run has_bash_write_pattern "$1"
    [ "$status" -eq 1 ] || { echo "expected read: $1"; return 1; }
}

@test "T-3746: 2>FILE is a write" {
    assert_write 'ls 2>err.log'
    assert_write 'ls 2> err.log'
    assert_write 'ls 2>>err.log'
}

@test "T-3746: &>FILE is a write" {
    assert_write 'ls &>out.log'
    assert_write 'ls &>>out.log'
}

@test "T-3746: sed w command and s///w flag are writes" {
    assert_write "sed -n '/x/w out.txt' f"
    assert_write "sed 's/a/b/w out.txt' f"
    assert_write "sed 's/a/b/gw out.txt' f"
}

@test "T-3746: sort -o / --output are writes" {
    assert_write 'sort -o out.txt f'
    assert_write 'sort -uo out.txt f'
    assert_write 'sort --output=out.txt f'
    assert_write 'sort --output out.txt f'
}

@test "T-3746: fd duplication and /dev/null stay reads" {
    assert_read 'ls 2>&1'
    assert_read 'ls 2>/dev/null'
    assert_read 'ls &>/dev/null'
    assert_read 'ls >&2'
    assert_read 'ls 1>&2'
    assert_read 'git log 2>&1 | sort | head'
}

@test "T-3746: plain sort, sed -n, git log stay reads" {
    assert_read 'sort f'
    assert_read 'sort -n -k2 f'
    assert_read 'sort f | grep -o x'
    assert_read "sed -n '1,5p' f"
    assert_read "sed 's/foo/new world/' f"
    assert_read 'git log --oneline -5'
}
