#!/usr/bin/env bats
# T-1843 / T-1829 — lib/mirror.sh stderr capture on push-failed.
#
# Origin: T-1828 RCA — the OneDev→GitHub mirror failed every 15min for 7+
# hours with only "push-failed" in .context/working/.mirror-sync.log. Took
# a consumer pickup to surface the actual blocking error (T-1603 hook).
# This test pins that mirror_sync_one captures push stderr into the log on
# failure so the next stall is diagnosable from logs alone.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    PROJECT_ROOT="$TEST_TEMP_DIR/proj"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.context/working"
    export PROJECT_ROOT
    # Build a tiny git repo with an origin remote that always rejects pushes
    # so we can exercise the push-failed path deterministically.
    cd "$PROJECT_ROOT"
    git init -q
    git config user.email "test@local"
    git config user.name "test"
    git config commit.gpgsign false
    echo "init" > F
    git add F
    git commit -q -m "T-0: init"
    # Create a bare "origin" remote
    mkdir -p "$TEST_TEMP_DIR/origin.git"
    git -C "$TEST_TEMP_DIR/origin.git" init --bare -q
    git remote add origin "$TEST_TEMP_DIR/origin.git"
    git push -q origin master 2>/dev/null
    # Create a bare "mirror" remote that we'll reject pushes to via pre-receive
    mkdir -p "$TEST_TEMP_DIR/mirror.git"
    git -C "$TEST_TEMP_DIR/mirror.git" init --bare -q
    # Pre-populate mirror with the same first commit so it has the same head
    # then advance origin so mirror is "behind" (a setup mirror_sync acts on)
    git push -q "$TEST_TEMP_DIR/mirror.git" master 2>/dev/null
    git remote add mirror "$TEST_TEMP_DIR/mirror.git"
    # Install a pre-receive hook on mirror.git that ALWAYS rejects with a
    # known error string — so push fails AND produces predictable stderr.
    cat > "$TEST_TEMP_DIR/mirror.git/hooks/pre-receive" <<'HOOK'
#!/bin/bash
echo "T-1843-FAKE-REJECT: simulated push rejection for stderr-capture test" >&2
exit 1
HOOK
    chmod +x "$TEST_TEMP_DIR/mirror.git/hooks/pre-receive"
    # Advance origin past mirror so mirror_sync has something to push
    echo "advance" > G
    git add G
    git commit -q -m "T-0: advance"
    git push -q origin master 2>/dev/null
}

teardown() {
    cd /
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "T-1843: mirror.sh contains T-1829 stderr-capture marker" {
    run grep -q "T-1829" "$FRAMEWORK_ROOT/lib/mirror.sh"
    [ "$status" -eq 0 ]
    run grep -q "PUSH-FAILED-STDERR" "$FRAMEWORK_ROOT/lib/mirror.sh"
    [ "$status" -eq 0 ]
}

@test "T-1843: mirror.sh parses with bash -n" {
    run bash -n "$FRAMEWORK_ROOT/lib/mirror.sh"
    [ "$status" -eq 0 ]
}

@test "T-1843: push-failed appends stderr block to .mirror-sync.log" {
    # Source mirror.sh into a subshell so we can invoke mirror_sync directly
    # with PROJECT_ROOT pointed at our synthetic repo.
    cd "$PROJECT_ROOT"
    # shellcheck source=/dev/null
    source "$FRAMEWORK_ROOT/lib/mirror.sh"
    run mirror_sync --quiet
    # mirror_sync returns non-zero on failure
    [ "$status" -ne 0 ]
    local log_file="$PROJECT_ROOT/.context/working/.mirror-sync.log"
    [ -f "$log_file" ]
    # Tab-separated push-failed row exists
    run grep -q $'\tpush-failed\t' "$log_file"
    [ "$status" -eq 0 ]
    # Stderr block markers exist
    run grep -q "##PUSH-FAILED-STDERR remote=mirror" "$log_file"
    [ "$status" -eq 0 ]
    run grep -q "##END" "$log_file"
    [ "$status" -eq 0 ]
    # The simulated error string from the pre-receive hook is captured
    run grep -q "T-1843-FAKE-REJECT" "$log_file"
    [ "$status" -eq 0 ]
}

@test "T-1843: successful push does NOT append stderr block" {
    cd "$PROJECT_ROOT"
    # Remove the rejecting hook so mirror push succeeds
    rm -f "$TEST_TEMP_DIR/mirror.git/hooks/pre-receive"
    # shellcheck source=/dev/null
    source "$FRAMEWORK_ROOT/lib/mirror.sh"
    run mirror_sync --quiet
    [ "$status" -eq 0 ]
    local log_file="$PROJECT_ROOT/.context/working/.mirror-sync.log"
    [ -f "$log_file" ]
    # No PUSH-FAILED-STDERR marker on success
    ! grep -q "##PUSH-FAILED-STDERR" "$log_file"
}
