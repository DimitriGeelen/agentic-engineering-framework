#!/usr/bin/env bats
# T-3974 (ring20, v1.8.5 consumer): the active-task gate advises
# `fw context focus WM-002`, but on a consumer it exited 1 with NO output.
#   1. .tasks/workflow/WM-*.md was never seeded outside the framework repo;
#   2. fw_find_wm_task returned 1 on not-found, and focus.sh (set -e) died before
#      its own "has no file" diagnostic.
# Now: init seeds the files, upgrade (re)creates them, and a missing file is reported.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export NO_COLOR=1
    C="$TEST_TEMP_DIR/consumer"
    mkdir -p "$C" && cd "$C" && git init -q && git config user.email t@t && git config user.name t
    "$FRAMEWORK_ROOT/bin/fw" init . >/dev/null 2>&1 || true
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_focus() {
    (cd "$C" && env PROJECT_ROOT="$C" "$FRAMEWORK_ROOT/bin/fw" context focus "$1" 2>&1)
}

@test "T-3974: fw init seeds WM-001..003" {
    for id in WM-001 WM-002 WM-003; do
        ls "$C/.tasks/workflow/$id"-*.md >/dev/null
    done
}

@test "T-3974: on a fresh consumer, fw context focus WM-002 works" {
    run _focus WM-002
    [ "$status" -eq 0 ]
    [[ "$output" == *"Focus set: WM-002"* ]]
}

@test "T-3974: a missing WM file is reported, not a silent exit 1" {
    rm -rf "$C/.tasks/workflow"
    run _focus WM-002
    [ "$status" -ne 0 ]
    [[ "$output" == *"has no file in .tasks/workflow/"* ]]
}

@test "T-3974: fw_find_wm_task returns 0 with empty output when the file is missing" {
    run bash -c "set -e; source '$FRAMEWORK_ROOT/lib/wm_tasks.sh'; out=\$(fw_find_wm_task WM-002 '$TEST_TEMP_DIR/nowhere'); echo \"rc0 [\$out]\""
    [ "$status" -eq 0 ]
    [ "$output" = "rc0 []" ]
}

@test "T-3974: fw upgrade recreates missing WM files on an existing consumer" {
    rm -rf "$C/.tasks/workflow"
    run env PROJECT_ROOT="$C" timeout 600 "$FRAMEWORK_ROOT/bin/fw" upgrade "$C"
    [[ "$output" == *"CREATED"*".tasks/workflow/WM-002"* ]]
    ls "$C/.tasks/workflow/"WM-002-*.md >/dev/null
    run _focus WM-002
    [ "$status" -eq 0 ]
}
