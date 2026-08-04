#!/usr/bin/env bats
# T-2799: install.sh's own verify() step must never initialise a project in
# the caller's cwd. Step 3 (`fw doctor`) used to run against the caller's
# cwd; under a non-TTY pipe (`curl | bash`) that reaches bin/fw's auto-init
# branch and silently seeds .agentic-framework/, .git, .tasks/, .context/
# etc. wherever the user happened to be standing -- while still printing a
# green "Step 3/3: fw doctor passes" checkmark. Measured live against GitHub
# master, 2026-08-04: an empty cwd ended up with a complete initialised
# project after nothing but the documented `curl | bash` one-liner.
#
# Regression test: run install.sh --local end to end in an isolated HOME
# with an empty, isolated cwd, then assert the cwd is untouched.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
INSTALL="$FRAMEWORK_ROOT/install.sh"

setup() {
    TEST_HOME=$(mktemp -d)
    TEST_CWD=$(mktemp -d)
    CURRENT_BRANCH="$(git -C "$FRAMEWORK_ROOT" rev-parse --abbrev-ref HEAD)"
}

teardown() {
    rm -rf "$TEST_HOME" "$TEST_CWD"
}

@test "T-2799: install.sh verify() step does not initialise a project in the caller's cwd" {
    if [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
        skip "detached HEAD -- --local install needs a real branch name"
    fi

    run env -i HOME="$TEST_HOME" \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        bash -c "cd '$TEST_CWD' && bash '$INSTALL' --local '$FRAMEWORK_ROOT' --branch '$CURRENT_BRANCH'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"All verification steps passed"* ]]

    # The cwd must be empty -- nothing should have been written there.
    local entries
    entries=$(find "$TEST_CWD" -mindepth 1 | wc -l)
    [ "$entries" -eq 0 ] || { echo "cwd was NOT empty after install: $(ls -A "$TEST_CWD")"; false; }

    # The install itself did land correctly, in the isolated HOME.
    [ -x "$TEST_HOME/.local/bin/fw" ]
}
