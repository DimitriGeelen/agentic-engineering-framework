#!/usr/bin/env bats
# T-2788 -- proves the shared PROJECT_ROOT guard actually fires.
#
# 106 bats files build fixture paths as mkdir -p "$PROJECT_ROOT/..." with
# PROJECT_ROOT assigned inside each file's own setup(). guard_project_root
# (tests/test_helper.bash) is now called immediately after every one of those
# assignments. This file pins the guard's own behaviour: it refuses an empty
# root, refuses "/", refuses a root outside any test temp dir, and gets out of
# the way for a correctly-scoped root -- with a demonstration that the guard
# is what stands between a bad PROJECT_ROOT and a real mkdir at the
# filesystem root (T-2787's failure mode), not just a unit-level assertion.

load ../test_helper

OUTSIDE_ROOT="/nonexistent-outside-any-temp-dir"

@test "guard_project_root refuses an empty PROJECT_ROOT" {
    run bash -c "source '$FRAMEWORK_ROOT/tests/test_helper.bash'; PROJECT_ROOT=''; guard_project_root"
    [ "$status" -eq 1 ]
    [[ "$output" == *"GUARD:"* ]]
    [[ "$output" == *"empty or '/'"* ]]
}

@test "guard_project_root refuses PROJECT_ROOT=/" {
    run bash -c "source '$FRAMEWORK_ROOT/tests/test_helper.bash'; PROJECT_ROOT='/'; guard_project_root"
    [ "$status" -eq 1 ]
    [[ "$output" == *"GUARD:"* ]]
    [[ "$output" == *"empty or '/'"* ]]
}

@test "guard_project_root refuses a root outside any test temp dir" {
    run bash -c "source '$FRAMEWORK_ROOT/tests/test_helper.bash'; PROJECT_ROOT='$OUTSIDE_ROOT'; guard_project_root"
    [ "$status" -eq 1 ]
    [[ "$output" == *"GUARD:"* ]]
    [[ "$output" == *"not inside a test temp directory"* ]]
}

@test "guard_project_root passes a correctly-scoped root under /tmp" {
    local d; d="$(mktemp -d)"
    run bash -c "source '$FRAMEWORK_ROOT/tests/test_helper.bash'; PROJECT_ROOT='$d'; guard_project_root"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    rm -rf "$d"
}

@test "guard_project_root defaults to reading PROJECT_ROOT when called with no args" {
    run bash -c "source '$FRAMEWORK_ROOT/tests/test_helper.bash'; export PROJECT_ROOT=''; guard_project_root"
    [ "$status" -eq 1 ]
}

# -- demonstration: the guard is what stops the mkdir, not a claim about it --

@test "demonstration: an exposed fixture site with empty PROJECT_ROOT is stopped before mkdir touches root" {
    # Reproduces the exact shape of the 106 patched call sites:
    #   export PROJECT_ROOT="$TEST_TEMP_DIR"
    #   guard_project_root
    #   mkdir -p "$PROJECT_ROOT/.tasks/active"
    # with TEST_TEMP_DIR deliberately unset, the pre-T-2788 shape of this
    # sequence would mkdir "/.tasks/active" for real. mkdir is stubbed rather
    # than left real: this test proves the guard's exit happens BEFORE the
    # mkdir line is even reached, without betting the proof on the guard
    # actually working (a broken guard here would otherwise reproduce the
    # exact T-2787 pollution against the live host).
    run bash -c "
        source '$FRAMEWORK_ROOT/tests/test_helper.bash'
        unset TEST_TEMP_DIR
        export PROJECT_ROOT=\"\$TEST_TEMP_DIR\"
        mkdir() { echo \"MKDIR-CALLED:\$*\"; }
        guard_project_root
        mkdir -p \"\$PROJECT_ROOT/.tasks/active\"
        echo 'REACHED-MKDIR-LINE'
    "
    [ "$status" -eq 1 ]
    [[ "$output" != *"MKDIR-CALLED"* ]]
    [[ "$output" != *"REACHED-MKDIR-LINE"* ]]
}

@test "demonstration: the same fixture shape succeeds when TEST_TEMP_DIR is set correctly" {
    run bash -c "
        source '$FRAMEWORK_ROOT/tests/test_helper.bash'
        TEST_TEMP_DIR=\"\$(mktemp -d)\"
        export PROJECT_ROOT=\"\$TEST_TEMP_DIR\"
        guard_project_root
        mkdir -p \"\$PROJECT_ROOT/.tasks/active\"
        echo 'MKDIR-RAN'
        [ -d \"\$PROJECT_ROOT/.tasks/active\" ]
        rm -rf \"\$TEST_TEMP_DIR\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"MKDIR-RAN"* ]]
}
