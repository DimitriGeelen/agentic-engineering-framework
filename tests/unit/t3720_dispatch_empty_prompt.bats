#!/usr/bin/env bats
# T-3720 — a failed prompt write left empty prompt files, and `fw termlink dispatch`
# spawned workers whose whole prompt was the sidecar consult stanza. Dispatch must
# refuse an empty or whitespace-only prompt before any worker exists.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    T="$(mktemp -d)"
    export FW_DISPATCH_DIR="$T/dispatch"
    PROJ="$T/proj"
    mkdir -p "$FW_DISPATCH_DIR" "$PROJ/.context/working" "$T/bin"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJ/.framework.yaml"
    # Stub termlink: `list` is empty, everything else fails — a dispatch that gets past
    # the prompt check stops at the spawn, after it has created the worker dir.
    cat > "$T/bin/termlink" <<'SH'
#!/bin/sh
if [ "$1" = "list" ]; then exit 0; fi
if [ "$1" = "--version" ] || [ "$1" = "version" ]; then echo "termlink 0.12.221"; exit 0; fi
exit 1
SH
    chmod +x "$T/bin/termlink"
    export PATH="$T/bin:$PATH"
    unset FW_TERMLINK_MAX_WORKERS FW_DISPATCH_LIMIT
}

teardown() { rm -rf "$T"; }

dispatch() {  # extra args...
    run bash -c "cd '$PROJ' && PROJECT_ROOT='$PROJ' bash '$SCRIPT' dispatch --task T-0001 --name w-empty --project '$PROJ' $* </dev/null"
}

@test "T-3720: an empty --prompt-file is refused and no worker is created" {
    : > "$T/empty.md"
    dispatch --prompt-file "'$T/empty.md'"
    [ "$status" -ne 0 ]
    [[ "$output" == *"prompt is empty"* ]]
    [ ! -d "$FW_DISPATCH_DIR/w-empty" ]
}

@test "T-3720: a whitespace-only --prompt-file is refused and no worker is created" {
    printf '  \n\t\n\n' > "$T/blank.md"
    dispatch --prompt-file "'$T/blank.md'"
    [ "$status" -ne 0 ]
    [[ "$output" == *"prompt is empty"* ]]
    [ ! -d "$FW_DISPATCH_DIR/w-empty" ]
}

@test "T-3720: a whitespace-only --prompt is refused and no worker is created" {
    dispatch --prompt "'   '"
    [ "$status" -ne 0 ]
    [[ "$output" == *"prompt is empty"* ]]
    [ ! -d "$FW_DISPATCH_DIR/w-empty" ]
}

@test "T-3720: control — a non-empty --prompt-file gets past the check to the spawn" {
    echo "do the task" > "$T/real.md"
    dispatch --prompt-file "'$T/real.md'"
    [[ "$output" != *"prompt is empty"* ]]
    [ -d "$FW_DISPATCH_DIR/w-empty" ]
}
