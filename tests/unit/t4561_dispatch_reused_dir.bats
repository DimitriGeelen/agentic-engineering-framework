#!/usr/bin/env bats
# T-4561 — `fw termlink dispatch` reused an existing /tmp/tl-dispatch/<name> dir and
# rewrote meta.json/prompt.md/run.sh, but left the previous run's exit_code,
# finished_at and close_state, so watchers saw the live worker as already finished
# (w4523, 2026-10-21). Dispatch must refuse a live/uncollected previous run and
# otherwise move the previous run's files into prev-<timestamp>/.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    T="$(mktemp -d)"
    export FW_DISPATCH_DIR="$T/dispatch"
    export TL_LISTED="$T/listed"
    PROJ="$T/proj"
    W="$FW_DISPATCH_DIR/w-reuse"
    mkdir -p "$W" "$PROJ/.context/working" "$T/bin"
    : > "$TL_LISTED"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJ/.framework.yaml"
    # Stub termlink: `list` prints $TL_LISTED; everything else fails, so a dispatch that
    # gets past the reuse check writes the new run's files and stops at the spawn — the
    # new run never ends, so it must have no exit_code.
    cat > "$T/bin/termlink" <<'SH'
#!/bin/sh
if [ "$1" = "list" ]; then cat "$TL_LISTED"; exit 0; fi
if [ "$1" = "--version" ] || [ "$1" = "version" ]; then echo "termlink 0.12.221"; exit 0; fi
exit 1
SH
    chmod +x "$T/bin/termlink"
    export PATH="$T/bin:$PATH"
    unset FW_TERMLINK_MAX_WORKERS FW_DISPATCH_LIMIT
}

teardown() { rm -rf "$T"; }

old_run() {  # [collected]
    printf '{\n  "name": "w-reuse",\n  "project": "%s",\n  "timeout": 600\n}\n' "$PROJ" > "$W/meta.json"
    echo 143 > "$W/exit_code"
    echo "2026-10-21T12:40:00Z" > "$W/finished_at"
    echo "closed" > "$W/close_state"
    echo "old answer" > "$W/result.md"
    echo '{"type":"result"}' > "$W/result.jsonl"
    [ "${1:-}" = collected ] && date -u +%Y-%m-%dT%H:%M:%SZ > "$W/collected"
    return 0
}

dispatch() {
    run bash -c "cd '$PROJ' && PROJECT_ROOT='$PROJ' bash '$SCRIPT' dispatch --task T-0001 --name w-reuse --prompt 'new work' --project '$PROJ' </dev/null"
}

@test "T-4561: a reused dir carries no exit_code/finished_at/close_state/result into the new run" {
    old_run collected
    dispatch
    [[ "$output" == *"Previous run of 'w-reuse' moved aside"* ]]
    # The new run was written ...
    grep -q "new work" "$W/prompt.md"
    # ... and has not ended, so none of the old run's end-state is visible.
    [ ! -e "$W/exit_code" ]
    [ ! -e "$W/finished_at" ]
    [ ! -e "$W/close_state" ]
    [ ! -e "$W/result.md" ]
    [ ! -e "$W/result.jsonl" ]
    [ ! -e "$W/collected" ]
    # The old run is kept, intact, under prev-*/.
    prev=$(ls -d "$W"/prev-* | head -1)
    [ -n "$prev" ]
    [ "$(cat "$prev/exit_code")" = 143 ]
    grep -q "old answer" "$prev/result.md"
}

@test "T-4561: an uncollected result of the previous run is refused, and nothing is moved" {
    old_run
    dispatch
    [ "$status" -ne 0 ]
    [[ "$output" == *"uncollected result"*"fw termlink result w-reuse"* ]]
    [ "$(cat "$W/exit_code")" = 143 ]
    ! ls -d "$W"/prev-* 2>/dev/null || false
}

@test "T-4561: a live previous run (no exit_code, session listed) is refused" {
    printf '{\n  "name": "w-reuse",\n  "project": "%s"\n}\n' "$PROJ" > "$W/meta.json"
    echo "w-reuse" > "$TL_LISTED"
    dispatch
    [ "$status" -ne 0 ]
    [[ "$output" == *"still running"* ]]
    [ ! -e "$W/prompt.md" ]
}

@test "T-4561: a previous run.sh still running is refused even after exit_code exists" {
    old_run collected
    printf 'sleep 30\n' > "$W/run.sh"
    bash "$W/run.sh" &
    pid=$!
    dispatch
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    [ "$status" -ne 0 ]
    [[ "$output" == *"still running"* ]]
}

@test "T-4561/control: a fresh name dispatches without moving anything aside" {
    rmdir "$W"
    dispatch
    [[ "$output" != *"moved aside"* ]]
    [ -f "$W/prompt.md" ]
    [ ! -e "$W/exit_code" ]
}
