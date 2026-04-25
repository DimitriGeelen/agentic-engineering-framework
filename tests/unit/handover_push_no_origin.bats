#!/usr/bin/env bats
# T-1474 — handover.sh mirror-skip must guard on origin presence.
#
# Bug: `if [ "$_remote_count" -gt 1 ] && [ "$remote_name" != "origin" ]` skips
# every remote when no remote is named `origin`. Symptom: `fw handover --commit`
# in the framework repo (which has `github` + `onedev`, no `origin`) skips both
# every time. Fix: gate the skip on `_has_origin = true`.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ---- Source-level invariants ----

@test "handover.sh computes _has_origin from remote list (T-1474)" {
    grep -q '_has_origin=true' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
    grep -q '_has_origin=false' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

@test "handover.sh detects origin via grep -qx 'origin' (T-1474)" {
    grep -q "git -C \"\$PROJECT_ROOT\" remote 2>/dev/null | grep -qx 'origin'" "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

@test "handover.sh mirror-skip guard requires _has_origin=true (T-1474)" {
    # The skip must be conditional on origin being present.
    grep -q '\[ "\$_has_origin" = true \] && \[ "\$_remote_count" -gt 1 \] && \[ "\$remote_name" != "origin" \]' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

@test "T-1255 mirror-skip preserved when origin exists (regression invariant)" {
    # The "Skipping ... mirrored from origin" message and skip path must still exist.
    grep -q 'Skipping \$remote_name (mirrored from origin via PushRepository)' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

# ---- Behavioural: simulate the guard logic in isolation ----

@test "guard skips non-origin remotes when origin is configured (T-1255 invariant)" {
    # Reproduce the guard predicate locally.
    _has_origin=true
    _remote_count=2
    skipped=0
    for remote_name in github origin; do
        if [ "$_has_origin" = true ] && [ "$_remote_count" -gt 1 ] && [ "$remote_name" != "origin" ]; then
            skipped=$((skipped + 1))
        fi
    done
    [ "$skipped" -eq 1 ]
}

@test "guard pushes to all remotes when no origin is configured (T-1474 fix)" {
    _has_origin=false
    _remote_count=2
    skipped=0
    for remote_name in github onedev; do
        if [ "$_has_origin" = true ] && [ "$_remote_count" -gt 1 ] && [ "$remote_name" != "origin" ]; then
            skipped=$((skipped + 1))
        fi
    done
    [ "$skipped" -eq 0 ]
}

@test "guard pushes to single remote even when not named origin (boundary)" {
    _has_origin=false
    _remote_count=1
    skipped=0
    for remote_name in upstream; do
        if [ "$_has_origin" = true ] && [ "$_remote_count" -gt 1 ] && [ "$remote_name" != "origin" ]; then
            skipped=$((skipped + 1))
        fi
    done
    [ "$skipped" -eq 0 ]
}

# ---- Sanity: no syntax error introduced ----

@test "handover.sh parses (bash -n) (T-1474)" {
    bash -n "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}
