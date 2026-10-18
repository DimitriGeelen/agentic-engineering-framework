#!/usr/bin/env bats
load ../git_fence  # T-3610: git discovery must not escape a fixture into a repo above the temp dir
# T-4296: fw init must not abort when HOME is unset or points at a missing directory.
# T-4251 resolved $HOME with `[ -n "$HOME" ] && _home_real=$(cd "$HOME" && pwd -P)`; under
# set -e the failing assignment, as the last command of an && list, ended init silently
# with rc 1 right after "Setting up agentic governance".

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t t4296-XXXXXX)"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_existing_project() {
    local proj="$TEST_TEMP_DIR/existing"
    mkdir -p "$proj/src"; echo 'print(1)' > "$proj/src/main.py"
    git init -q "$proj"
    printf '%s' "$proj"
}

@test "T-4296: fw init succeeds when HOME points at a missing directory" {
    local proj; proj=$(_existing_project)
    run bash -c "cd '$proj' && env -i PATH=/usr/local/bin:/usr/bin:/bin HOME='$TEST_TEMP_DIR/no-such-home' '$FRAMEWORK_ROOT/bin/fw' init . --provider claude"
    [ "$status" -eq 0 ]
    [ -f "$proj/.framework.yaml" ]
    [ -n "$(ls "$proj/.tasks/active/" 2>/dev/null)" ]
}

@test "T-4296: fw init succeeds when HOME is unset" {
    local proj; proj=$(_existing_project)
    run bash -c "cd '$proj' && env -i PATH=/usr/local/bin:/usr/bin:/bin '$FRAMEWORK_ROOT/bin/fw' init . --provider claude"
    [ "$status" -eq 0 ]
    [ -f "$proj/.framework.yaml" ]
}
