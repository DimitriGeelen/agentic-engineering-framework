#!/usr/bin/env bats
# T-4582 — `fw termlink wait --name W` must not idle the full timeout when W emitted
# worker.done before the wait subscribed. The stub termlink's `event wait` never sees an
# event (it sleeps its whole --timeout), which is exactly the missed-event case; the wait
# must still return as soon as W's exit_code is on disk, and never run past --timeout.
# Fixture FW_DISPATCH_DIR only, never the real /tmp/tl-dispatch.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../../agents/termlink/termlink.sh"
    T="$(mktemp -d)"
    D="$T/dispatch"
    mkdir -p "$D" "$T/bin"
    export FW_DISPATCH_DIR="$D"
    export PROJECT_ROOT="$T/proj"
    mkdir -p "$PROJECT_ROOT"
    cat > "$T/bin/termlink" <<'STUB'
#!/usr/bin/env bash
# Stub: `list` shows every worker; `event wait` misses the event and sleeps its timeout.
case "$1" in
    list) ls "$FW_DISPATCH_DIR" ;;
    event)
        t=0
        while [ $# -gt 0 ]; do [ "$1" = --timeout ] && t="$2"; shift; done
        sleep "$t"; exit 1 ;;
esac
exit 0
STUB
    chmod +x "$T/bin/termlink"
    export PATH="$T/bin:$PATH"
    BG_PID=""
}

teardown() {
    [ -n "$BG_PID" ] && kill "$BG_PID" 2>/dev/null || true
    rm -rf "$T"
}

@test "worker already done before wait starts: returns its exit code at once" {
    mkdir -p "$D/w1"
    echo 3 > "$D/w1/exit_code"
    start=$(date +%s)
    run timeout 60 bash "$SCRIPT" wait --name w1 --timeout 30
    elapsed=$(( $(date +%s) - start ))
    [ "$status" -eq 3 ]
    [[ "$output" == *"Worker w1 finished (exit: 3)"* ]]
    [ "$elapsed" -le 3 ]
}

@test "worker finishes mid-wait with the event missed: returns within a slice" {
    mkdir -p "$D/w2"
    ( sleep 2; echo 0 > "$D/w2/exit_code" ) &
    BG_PID=$!
    start=$(date +%s)
    run timeout 60 bash "$SCRIPT" wait --name w2 --timeout 40
    elapsed=$(( $(date +%s) - start ))
    [ "$status" -eq 0 ]
    [[ "$output" == *"Worker w2 finished (exit: 0)"* ]]
    [ "$elapsed" -le 10 ]
}

@test "worker never finishes: total wait honours --timeout (one deadline, not 2x)" {
    mkdir -p "$D/w3"
    start=$(date +%s)
    run timeout 60 bash "$SCRIPT" wait --name w3 --timeout 6
    elapsed=$(( $(date +%s) - start ))
    [ "$status" -eq 1 ]
    [[ "$output" == *"Timeout waiting for worker w3"* ]]
    [ "$elapsed" -le 9 ]
}
