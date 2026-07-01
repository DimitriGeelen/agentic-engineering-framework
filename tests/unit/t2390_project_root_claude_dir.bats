#!/usr/bin/env bats
# T-2390: bin/fw prefers CLAUDE_PROJECT_DIR (when valid) over the $PWD walk when
# resolving PROJECT_ROOT from a stale/non-project cwd. Origin: T-2389 live-fire —
# a spawned session's hooks ran with cwd=$HOME (/root), so find_project_root()
# mis-resolved PROJECT_ROOT (latched a stray /root/.tasks or failed), blinding
# the budget gauge + firing spurious project-boundary blocks. Claude Code exports
# CLAUDE_PROJECT_DIR to hooks as the session's project root, independent of the
# hook's invocation cwd.
#
# T-2446 extended this: when cwd IS genuinely inside another project (not $HOME,
# has markers), cwd wins over CLAUDE_PROJECT_DIR to prevent daemon-inherited
# env vars from poisoning cross-project fw invocations.
#
# Surface under test: bin/fw "Resolve PROJECT_ROOT" block (CLAUDE_PROJECT_DIR
# preference, validity-gated, daemon-poison-guarded). Observed via `fw version`.
#
# AC mapping:
#   CLAUDE_PROJECT_DIR wins when cwd=$HOME (T-2390 case)           — t1
#   cwd wins when genuinely in another project (T-2446 case)       — t2
#   unset CLAUDE_PROJECT_DIR → $PWD walk (bug repro)               — t3
#   invalid CLAUDE_PROJECT_DIR falls through to walk               — t4

load ../test_helper

FW="$BATS_TEST_DIRNAME/../../bin/fw"

setup() {
    # REAL project carries .framework.yaml (the legitimate root).
    # HOME_DIR simulates $HOME with a stray .tasks (the /root/.tasks analogue).
    # OTHER_PROJECT simulates being in a different valid project.
    REAL="$(mktemp -d -t fw-t2390-real-XXXXXX)"
    HOME_DIR="$(mktemp -d -t fw-t2390-home-XXXXXX)"
    OTHER_PROJECT="$(mktemp -d -t fw-t2390-other-XXXXXX)"
    mkdir -p "$REAL/.tasks"
    printf 'version: test\n' > "$REAL/.framework.yaml"
    mkdir -p "$HOME_DIR/.tasks"  # stray .tasks that would be latched
    mkdir -p "$OTHER_PROJECT/.tasks"
    printf 'version: other\n' > "$OTHER_PROJECT/.framework.yaml"
}

teardown() {
    rm -rf "$REAL" "$HOME_DIR" "$OTHER_PROJECT"
}

@test "t1: CLAUDE_PROJECT_DIR wins when cwd=HOME (T-2390 canonical case)" {
    # Simulates the T-2389 live-fire scenario: hook runs with cwd=$HOME,
    # but CLAUDE_PROJECT_DIR points to the real project.
    cd "$HOME_DIR"
    run env -u PROJECT_ROOT HOME="$HOME_DIR" CLAUDE_PROJECT_DIR="$REAL" bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$REAL"
    ! echo "$output" | grep -q "Project:.*$HOME_DIR"
}

@test "t2: cwd wins when genuinely in another project (T-2446 daemon-poison guard)" {
    # When you're actually inside OTHER_PROJECT and CLAUDE_PROJECT_DIR points
    # elsewhere (daemon-inherited), cwd should win to prevent cross-project
    # mis-resolution.
    cd "$OTHER_PROJECT"
    run env -u PROJECT_ROOT CLAUDE_PROJECT_DIR="$REAL" bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$OTHER_PROJECT"
    ! echo "$output" | grep -q "Project:.*$REAL"
}

@test "t3: without CLAUDE_PROJECT_DIR, \$PWD walk resolves cwd project (bug repro baseline)" {
    cd "$OTHER_PROJECT"
    run env -u PROJECT_ROOT -u CLAUDE_PROJECT_DIR bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$OTHER_PROJECT"
}

@test "t4: invalid CLAUDE_PROJECT_DIR (no markers) falls through to \$PWD walk" {
    local empty
    empty="$(mktemp -d -t fw-t2390-empty-XXXXXX)"
    cd "$OTHER_PROJECT"
    run env -u PROJECT_ROOT CLAUDE_PROJECT_DIR="$empty" bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$OTHER_PROJECT"
    ! echo "$output" | grep -q "Project:.*$empty"
    rm -rf "$empty"
}
