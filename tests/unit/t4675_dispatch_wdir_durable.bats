#!/usr/bin/env bats
# T-4675 — a tmpfs mounted over /tmp (2026-10-23 00:00) hid every /tmp/tl-dispatch/<worker>
# dir: running workers kept writing through open fds, but `fw termlink wait/result/status`
# looked the dir up by path and found nothing. Worker state now lives under the dispatching
# project (.context/dispatch/<name>); the legacy /tmp root is only a read fallback for workers
# that were already running there. FW_DISPATCH_DIR is deliberately NOT set here (it pins a
# single root); FW_DISPATCH_LEGACY_DIR points the fallback at a fixture, never the real /tmp.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    T="$(mktemp -d)"
    PROJ="$T/proj"
    LEGACY="$T/legacy"
    PD="$PROJ/.context/dispatch"
    mkdir -p "$PROJ/.context/working" "$LEGACY" "$T/bin"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJ/.framework.yaml"
    unset FW_DISPATCH_DIR FW_TERMLINK_MAX_WORKERS FW_DISPATCH_LIMIT
    export FW_DISPATCH_LEGACY_DIR="$LEGACY"
    export PROJECT_ROOT="$PROJ"
    # Stub termlink: `list` shows nothing live, `event wait` misses, spawn fails — so a dispatch
    # writes its worker dir and stops at the spawn.
    cat > "$T/bin/termlink" <<'SH'
#!/bin/sh
case "$1" in
    list) exit 0 ;;
    --version|version) echo "termlink 0.12.221"; exit 0 ;;
    event) sleep 1; exit 1 ;;
esac
exit 1
SH
    chmod +x "$T/bin/termlink"
    export PATH="$T/bin:$PATH"
    BG_PID=""
}

teardown() {
    [ -n "$BG_PID" ] && kill "$BG_PID" 2>/dev/null || true
    rm -rf "$T"
}

finished_worker() {  # <dir> <name> <exit> <text>
    mkdir -p "$1"
    printf '{\n  "name": "%s",\n  "project": "%s",\n  "timeout": 600\n}\n' "$2" "$PROJ" > "$1/meta.json"
    echo "$4" > "$1/result.md"
    echo "$3" > "$1/exit_code"
}

@test "T-4675: dispatch creates the worker dir under the project, not under /tmp" {
    run bash -c "cd '$PROJ' && bash '$SCRIPT' dispatch --task T-0001 --name w-new --prompt 'work' --project '$PROJ' </dev/null"
    [ -f "$PD/w-new/meta.json" ]
    [ -f "$PD/w-new/run.sh" ]
    grep -q '"project": "'"$PROJ"'"' "$PD/w-new/meta.json"
    [ ! -e "$LEGACY/w-new" ]
}

@test "T-4675: /tmp root vanishes mid-run — result, exit_code and status still resolve" {
    mkdir -p "$PD/w-live"
    printf '{\n  "name": "w-live",\n  "project": "%s"\n}\n' "$PROJ" > "$PD/w-live/meta.json"
    # The remount: the /tmp root disappears while the worker runs, then run.sh finishes.
    ( sleep 1; mv "$LEGACY" "$T/legacy-hidden"; sleep 1
      echo "the answer" > "$PD/w-live/result.md"; echo 0 > "$PD/w-live/exit_code" ) &
    BG_PID=$!
    run timeout 60 bash "$SCRIPT" wait --name w-live --timeout 30
    [ "$status" -eq 0 ]
    [[ "$output" == *"Worker w-live finished (exit: 0)"* ]]
    run bash "$SCRIPT" result w-live
    [ "$status" -eq 0 ]
    [[ "$output" == *"the answer"* ]]
    [ -f "$PD/w-live/collected" ]
    run bash "$SCRIPT" status
    [[ "$output" == *"w-live"*"complete"* ]]
}

@test "T-4675: a worker still in the legacy /tmp root stays readable (fallback)" {
    finished_worker "$LEGACY/w-old" w-old 4 "legacy answer"
    run timeout 30 bash "$SCRIPT" wait --name w-old --timeout 5
    [ "$status" -eq 4 ]
    run bash "$SCRIPT" result w-old
    [[ "$output" == *"legacy answer"* ]]
    run bash "$SCRIPT" status
    [[ "$output" == *"w-old"*"failed (exit: 4)"* ]]
}

@test "T-4675: the project dir wins over a same-named legacy dir" {
    finished_worker "$LEGACY/w-both" w-both 1 "stale legacy"
    finished_worker "$PD/w-both" w-both 0 "current project"
    run bash "$SCRIPT" result w-both
    [[ "$output" == *"current project"* ]]
    [[ "$output" != *"stale legacy"* ]] || false
}

@test "T-4675: cleanup removes a collected project-root worker" {
    finished_worker "$PD/w-done" w-done 0 "done"
    date -u +%Y-%m-%dT%H:%M:%SZ > "$PD/w-done/collected"
    run bash "$SCRIPT" cleanup --yes
    [ "$status" -eq 0 ]
    [ ! -e "$PD/w-done" ]
}

@test "T-4675: dispatch_tokens.py and termlink_worker.py resolve the project root first" {
    finished_worker "$PD/w-py" w-py 0 "x"
    finished_worker "$LEGACY/w-leg" w-leg 0 "x"
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT/lib')
import dispatch_tokens, termlink_worker
print(dispatch_tokens.worker_dir('w-py'))
print(dispatch_tokens.worker_dir('w-leg'))
print(termlink_worker.TermLinkWorker(model='', cwd='$PROJ', task_id='T-0001', name='w-py').wdir)
"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$PD/w-py" ]
    [ "${lines[1]}" = "$LEGACY/w-leg" ]
    [ "${lines[2]}" = "$PD/w-py" ]
}
