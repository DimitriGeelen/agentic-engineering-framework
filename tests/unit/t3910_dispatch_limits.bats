#!/usr/bin/env bats
# T-3910 — operator ruling 2026-10-06: sub-agents run as TermLink workers, never
# through the vendor harness's own dispatcher (FW_DISPATCH_LIMIT defaults to 0),
# and TermLink dispatch is capped at TERMLINK_MAX_WORKERS (default 5) concurrent
# workers per project, raised only situationally on the operator's say-so.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    T="$(mktemp -d)"
    export FW_DISPATCH_DIR="$T/dispatch"
    PROJ="$T/proj"
    OTHER="$T/other"
    mkdir -p "$FW_DISPATCH_DIR" "$PROJ/.context/working" "$OTHER" "$T/bin"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJ/.framework.yaml"
    # Stub termlink: `list` prints every worker name we created; everything else fails,
    # so a dispatch that gets past the cap stops at the spawn without side effects.
    cat > "$T/bin/termlink" <<'SH'
#!/bin/sh
if [ "$1" = "list" ]; then ls "$FW_DISPATCH_DIR"; exit 0; fi
if [ "$1" = "--version" ] || [ "$1" = "version" ]; then echo "termlink 0.12.221"; exit 0; fi
exit 1
SH
    chmod +x "$T/bin/termlink"
    export PATH="$T/bin:$PATH"
    unset FW_TERMLINK_MAX_WORKERS FW_DISPATCH_LIMIT
}

teardown() { rm -rf "$T"; }

worker() {  # name project [finished]
    mkdir -p "$FW_DISPATCH_DIR/$1"
    printf '{\n  "name": "%s",\n  "project": "%s",\n  "timeout": 600\n}\n' "$1" "$2" > "$FW_DISPATCH_DIR/$1/meta.json"
    [ "${3:-}" = finished ] && echo 0 > "$FW_DISPATCH_DIR/$1/exit_code"
    return 0
}

dispatch() {
    run bash -c "cd '$PROJ' && PROJECT_ROOT='$PROJ' bash '$SCRIPT' dispatch --task T-0001 --name new-one --prompt hello --project '$PROJ' </dev/null"
}

@test "T-3910: DISPATCH_LIMIT (harness sub-agents) defaults to 0" {
    source "$FRAMEWORK_ROOT/lib/config.sh"
    grep -q '"DISPATCH_LIMIT|0|' "$FRAMEWORK_ROOT/lib/config.sh"
    grep -q 'fw_config_int "DISPATCH_LIMIT" 0' "$FRAMEWORK_ROOT/agents/context/check-agent-dispatch.sh"
}

@test "T-3910: the Agent-tool gate blocks the FIRST harness dispatch when TermLink is present" {
    run bash -c "cd '$PROJ' && PROJECT_ROOT='$PROJ' FRAMEWORK_ROOT='$FRAMEWORK_ROOT' bash '$FRAMEWORK_ROOT/agents/context/check-agent-dispatch.sh' <<< '{\"tool_name\":\"Agent\"}'"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Agent dispatch #1 exceeds limit (0)"* ]]
    [[ "$output" == *"termlink dispatch"* ]]
}

@test "T-3910: a 6th concurrent worker for this project is refused, with the ask-the-operator line" {
    for i in 1 2 3 4 5; do worker "w$i" "$PROJ"; done
    dispatch
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"*"5 of 5 concurrent TermLink workers"* ]]
    [[ "$output" == *"ASK THE OPERATOR"* ]]
    [[ "$output" == *"FW_TERMLINK_MAX_WORKERS=N"* ]]
    [ ! -d "$FW_DISPATCH_DIR/new-one" ]
}

@test "T-3910: FW_TERMLINK_MAX_WORKERS raises the cap for one run" {
    for i in 1 2 3 4 5; do worker "w$i" "$PROJ"; done
    export FW_TERMLINK_MAX_WORKERS=6
    dispatch
    [[ "$output" != *"concurrent TermLink workers already running"* ]]
    # It got past the cap: the worker dir was created (the stub then fails the spawn).
    [ -d "$FW_DISPATCH_DIR/new-one" ]
}

@test "T-3910: finished workers and another project's workers hold no slot" {
    for i in 1 2 3 4; do worker "w$i" "$PROJ"; done
    worker done1 "$PROJ" finished
    worker theirs "$OTHER"
    dispatch
    [[ "$output" != *"concurrent TermLink workers already running"* ]]
    [ -d "$FW_DISPATCH_DIR/new-one" ]
}

@test "T-3910/control: with 4 live + the 5th counted, a live 5th worker of this project does fill the cap" {
    for i in 1 2 3 4; do worker "w$i" "$PROJ"; done
    worker theirs "$OTHER"
    worker w5 "$PROJ"
    dispatch
    [[ "$output" == *"5 of 5 concurrent TermLink workers"* ]]
}
