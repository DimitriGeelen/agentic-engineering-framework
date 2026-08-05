#!/usr/bin/env bats
# T-2813: `fw git install-hooks` printed "=== Hooks Installed ===" and exited 0
# even when every hook write failed (cat > "$hook" << 'EOF' fails silently at
# the redirect, before the heredoc body runs; the subsequent chmod failure was
# likewise unchecked). This suite pins the fix: install-hooks now verifies
# each hook exists and is executable on disk before reporting it, and exits
# non-zero — with no success banner — when any hook was not actually written.
#
# Invokes agents/git/git.sh directly (not `fw git`) with PROJECT_ROOT
# exported per-scenario, per the L-271 bats pattern (see sibling
# git_install_hooks_git_path.bats for T-2812).

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TEST_TMP="$(mktemp -d)"
}

teardown() {
    cd /
    rm -rf "$TEST_TMP"
}

run_install_hooks() {
    PROJECT_ROOT="$1" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks
}

# --- Real failure mode: hooks dir cannot be created/written into -------
# Replaces .git/hooks with a plain file so `mkdir -p` cannot create the
# directory and every subsequent `cat > "$hooks_dir/<hook>"` fails at the
# redirect — the exact silent-failure mechanism described in the task.

@test "hooks dir blocked: install-hooks exits non-zero and never prints the success banner" {
    local proj="$TEST_TMP/proj"
    mkdir -p "$proj"
    git -C "$proj" init -q
    git -C "$proj" config user.email test@local
    git -C "$proj" config user.name test

    rm -rf "$proj/.git/hooks"
    touch "$proj/.git/hooks"   # blocks mkdir -p and every write beneath it

    run run_install_hooks "$proj"

    [ "$status" -ne 0 ]
    [[ "$output" != *"=== Hooks Installed ==="* ]]
    [[ "$output" == *"failed"* ]]

    # None of the four hooks may be reported as installed paths when they
    # were never actually written.
    [[ "$output" != *"(task reference validation)"* ]]
    [[ "$output" != *"(secret-scan"* ]]
    [[ "$output" != *"(bypass detection)"* ]]
    [[ "$output" != *"(audit before push)"* ]]
}

# --- Control: success path unchanged, all four hooks still reported ----

@test "control: plain repo still installs and reports all four hooks with exit 0" {
    local proj="$TEST_TMP/proj"
    mkdir -p "$proj"
    git -C "$proj" init -q
    git -C "$proj" config user.email test@local
    git -C "$proj" config user.name test

    run run_install_hooks "$proj"

    [ "$status" -eq 0 ]
    [[ "$output" == *"=== Hooks Installed ==="* ]]

    for hook in commit-msg pre-commit post-commit pre-push; do
        [ -f "$proj/.git/hooks/$hook" ]
        [ -x "$proj/.git/hooks/$hook" ]
    done
}
