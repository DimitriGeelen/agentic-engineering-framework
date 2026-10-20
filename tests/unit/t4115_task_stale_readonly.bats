#!/usr/bin/env bats
#
# T-4115: `fw task stale` is a read-only listing (bin/fw `stale)` arm reads
# .tasks/active/ and writes nothing), and fw doctor's Task-debt WARN says
# "Run: fw task stale" — so the task gate must not refuse it at null focus.
# Mutating `fw task` sub-verbs must still reach the gate.

load helpers/known_cwd

setup() {
    known_cwd_setup
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$ROOT/agents/context/lib/safe-commands.sh"
}

teardown() {
    known_cwd_teardown
}

@test "T-4115: bin/fw task stale is SAFE" {
    is_bash_safe_command "bin/fw task stale"
}

@test "T-4115: fw task stale --days 14 is SAFE" {
    is_bash_safe_command "fw task stale --days 14"
}

@test "T-4115: .agentic-framework/bin/fw task stale is SAFE" {
    is_bash_safe_command ".agentic-framework/bin/fw task stale"
}

@test "T-4115: fw task update is still GATED" {
    ! is_bash_safe_command "bin/fw task update T-1 --status work-completed" || false
}

@test "T-4115: fw task stale redirected to a file is still a write pattern" {
    # Redirects are judged by has_bash_write_pattern on the original line
    # (check-active-task.sh), not by the allowlist — same as `fw task list`.
    has_bash_write_pattern "bin/fw task stale > out.txt"
}

@test "T-4115: the stale arm in bin/fw writes nothing" {
    # Pin the premise of the classification: the stale python block opens no
    # file for writing and runs no subprocess. If that changes, re-classify.
    block=$(sed -n "/^        stale)/,/^PYTASK_STALE/p" "$ROOT/bin/fw")
    [ -n "$block" ]
    ! echo "$block" | grep -qE "open\([^)]*['\"][wa]|subprocess|os\.(remove|rename|replace)|shutil" || false
}
