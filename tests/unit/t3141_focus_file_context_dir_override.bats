#!/usr/bin/env bats
# T-3141 — fw_focus_file must honour a CONTEXT_DIR override instead of
# re-deriving "$root/.context/working" from PROJECT_ROOT.
#
# tests/unit/create_task.bats (T-2832) sandboxes CONTEXT_DIR alone, leaving
# PROJECT_ROOT pointed at the real repo so template resolution still works.
# fw_focus_file ignored that override and re-derived the path from PROJECT_ROOT,
# so --start's focus write landed in the LIVE session's real
# .context/working/focus.yaml instead of the sandbox — live-confirmed during
# T-3104 close-out, tripping the T-560 stale-focus gate on the next command.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    PATHS_LIB="$FRAMEWORK_ROOT/lib/paths.sh"
    REALROOT="$BATS_TEST_TMPDIR/real-project"
    SANDBOX="$BATS_TEST_TMPDIR/sandbox/.context"
    mkdir -p "$REALROOT/.context/working" "$SANDBOX/working"
}

@test "t3141: with CONTEXT_DIR unset, falls back to \$root/.context/working (unchanged default)" {
    # -u strips the whole outer environment (this suite may itself be running
    # inside a session-scoped-focus dispatch worker — T-3038 — whose inherited
    # FW_SESSION_SCOPED_FOCUS/FW_FOCUS_SESSION_KEY would otherwise leak in and
    # produce a scoped filename instead of the plain default).
    run env -u FW_SESSION_SCOPED_FOCUS -u FW_FOCUS_SESSION_KEY -u CONTEXT_DIR bash -c "
        PROJECT_ROOT='$REALROOT'
        source '$PATHS_LIB' 2>/dev/null
        fw_focus_file '$REALROOT'
    "
    [ "$status" -eq 0 ]
    [ "$output" = "$REALROOT/.context/working/focus.yaml" ]
}

@test "t3141: with CONTEXT_DIR overridden, resolves inside the override — not PROJECT_ROOT/.context" {
    # This is the exact create_task.bats T-2832 shape: PROJECT_ROOT stays on the
    # real repo, only CONTEXT_DIR is sandboxed.
    run env -u FW_SESSION_SCOPED_FOCUS -u FW_FOCUS_SESSION_KEY bash -c "
        PROJECT_ROOT='$REALROOT'
        source '$PATHS_LIB' 2>/dev/null
        CONTEXT_DIR='$SANDBOX'
        fw_focus_file '$REALROOT'
    "
    [ "$status" -eq 0 ]
    [ "$output" = "$SANDBOX/working/focus.yaml" ]
    [[ "$output" != "$REALROOT"* ]]
}

@test "t3141: CONTEXT_DIR override also applies under FW_SESSION_SCOPED_FOCUS=1" {
    run env FW_SESSION_SCOPED_FOCUS=1 FW_FOCUS_SESSION_KEY=worker-a bash -c "
        PROJECT_ROOT='$REALROOT'
        source '$PATHS_LIB' 2>/dev/null
        CONTEXT_DIR='$SANDBOX'
        fw_focus_file '$REALROOT'
    "
    [ "$status" -eq 0 ]
    [ "$output" = "$SANDBOX/working/focus.worker-a.yaml" ]
    [[ "$output" != "$REALROOT"* ]]
}
