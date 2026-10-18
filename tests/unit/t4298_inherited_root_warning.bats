#!/usr/bin/env bats
load ../git_fence  # T-3610
# T-4298: the "ignored inherited env" notice is said once by install.sh, and bin/fw's
# inherited-FRAMEWORK_ROOT warning is shown once per calling shell, never on hook calls.

bats_require_minimum_version 1.5.0

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
INSTALL="$FRAMEWORK_ROOT/install.sh"
ENVP="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

setup() {
    TEST_HOME=$(mktemp -d); TEST_TARGET=$(mktemp -d); BAD=$(mktemp -d)
    git init -q "$TEST_TARGET"
    CURRENT_BRANCH="$(git -C "$FRAMEWORK_ROOT" rev-parse --abbrev-ref HEAD)"
    GITENV=(GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com)
}
teardown() { rm -rf "$TEST_HOME" "$TEST_TARGET" "$BAD"; rm -f "${TMPDIR:-/tmp}"/fw-inherited-root-warned.*.$$ 2>/dev/null || true; }

run_install() {
    run env -i HOME="$TEST_HOME" PATH="$ENVP" "$@" "${GITENV[@]}" \
        bash "$INSTALL" "$TEST_TARGET" --local "$FRAMEWORK_ROOT" --branch "$CURRENT_BRANCH" --no-scan
}

@test "T-4298: install.sh names every ignored inherited variable, once" {
    [[ "$CURRENT_BRANCH" == "HEAD" ]] && skip "detached HEAD"
    run_install FRAMEWORK_ROOT="$BAD" PROJECT_ROOT="$BAD"
    [ "$status" -eq 0 ]
    [ "$(grep -c 'Ignoring inherited environment' <<<"$output")" -eq 1 ]
    grep 'Ignoring inherited environment' <<<"$output" | grep -q 'FRAMEWORK_ROOT, PROJECT_ROOT'
}

@test "T-4298: install.sh prints no ignored-variable line in a clean environment" {
    [[ "$CURRENT_BRANCH" == "HEAD" ]] && skip "detached HEAD"
    run_install
    [ "$status" -eq 0 ]
    [[ "$output" != *"Ignoring inherited environment"* ]]
}

@test "T-4298: bin/fw warns about a bad inherited FRAMEWORK_ROOT once per calling shell" {
    # One bash -c = one calling shell (PPID of both fw invocations).
    run bash -c "FRAMEWORK_ROOT='$BAD' bash '$FRAMEWORK_ROOT/bin/fw' version 2>&1; FRAMEWORK_ROOT='$BAD' bash '$FRAMEWORK_ROOT/bin/fw' version 2>&1"
    [ "$(grep -c 're-resolving' <<<"$output")" -eq 1 ]
    rm -f "${TMPDIR:-/tmp}"/fw-inherited-root-warned.*
}

@test "T-4298: bin/fw hook calls never print the inherited-root warning" {
    # A throwaway project: a missing hook is logged to PROJECT_ROOT's crash log, and
    # without its own project this test wrote into the real repo's .hook-crashes.log.
    local proj
    proj="$(mktemp -d)"
    mkdir -p "$proj/.tasks" "$proj/.context/working"
    run bash -c "cd '$proj' && PROJECT_ROOT='$proj' CLAUDE_PROJECT_DIR='$proj' FRAMEWORK_ROOT='$BAD' bash '$FRAMEWORK_ROOT/bin/fw' hook nonexistent-hook-x 2>&1"
    [[ "$output" != *"re-resolving"* ]]
    rm -rf "$proj"
}
