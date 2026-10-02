#!/usr/bin/env bats
# T-3595: `fw termlink cleanup` must delete only the worker dirs it has decided are
# finished or orphaned-and-terminated — never an ACTIVE worker's dir, never the whole
# root while anything is left in it.
#
# SAFETY: every test runs against a sandbox under $BATS_TEST_TMPDIR. Nothing here touches
# the real /tmp/tl-dispatch, where live workers keep their state, and the only processes
# signalled are the fake workers these tests spawn (tracked in $PIDS, killed in teardown).

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
TERMLINK_SH="$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
PRE_FIX_REV=199168fa1   # last commit with the `rm -rf "$DISPATCH_DIR"` cleanup

setup() {
    DD="$BATS_TEST_TMPDIR/tl-dispatch"
    mkdir -p "$DD"
    PIDS_FILE="$BATS_TEST_TMPDIR/pids"
    : > "$PIDS_FILE"
}

teardown() {
    local pid
    while read -r pid; do
        [ -n "$pid" ] || continue
        pkill -KILL -P "$pid" 2>/dev/null || true
        kill -KILL "$pid" 2>/dev/null || true
    done < "$PIDS_FILE"
}

# An active worker: a parent whose args contain the wdir (like run.sh), spawning a child
# named `claude` whose args do not (like `claude -p`) — the T-972 shape.
spawn_active() {
    local w="$DD/$1"
    mkdir -p "$w"
    python3 -c 'import subprocess; subprocess.run(["bash","-c","exec -a claude sleep 300"])' "$w/run.sh" &
    echo $! >> "$PIDS_FILE"
    # wait until the claude-named child exists
    local i
    for i in $(seq 1 50); do
        ps --ppid "$!" -o args= 2>/dev/null | grep -q '^claude' && return 0
        sleep 0.1
    done
    return 1
}

# An orphan: a process holding the wdir in its args, with no worker process under it.
spawn_orphan() {
    local w="$DD/$1"
    mkdir -p "$w"
    python3 -c 'import time; time.sleep(300)' "$w/run.sh" &
    ORPHAN_PID=$!
    echo "$ORPHAN_PID" >> "$PIDS_FILE"
    sleep 0.3
}

make_finished() { mkdir -p "$DD/$1" && echo 0 > "$DD/$1/exit_code" && echo r > "$DD/$1/result.md"; }

run_cleanup() {
    run env FW_DISPATCH_DIR="$DD" bash -c "source '$TERMLINK_SH' >/dev/null 2>&1; [ \"\$DISPATCH_DIR\" = '$DD' ] || exit 99; cmd_cleanup --yes"  # T-3716: consent required since T-3651
}

@test "DISPATCH_DIR honours FW_DISPATCH_DIR; default unchanged" {
    run env -u FW_DISPATCH_DIR bash -c "source '$TERMLINK_SH' >/dev/null 2>&1; echo \"\$DISPATCH_DIR\""
    [ "$status" -eq 0 ]
    [ "$output" = "/tmp/tl-dispatch" ]
    run env FW_DISPATCH_DIR="$DD" bash -c "source '$TERMLINK_SH' >/dev/null 2>&1; echo \"\$DISPATCH_DIR\""
    [ "$output" = "$DD" ]
}

@test "active worker keeps its dir; finished one is removed; root survives" {
    spawn_active live
    make_finished done
    echo keep > "$DD/live/meta.json"
    run_cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"ACTIVE"*"live"* ]]
    [ -f "$DD/live/meta.json" ]
    [ ! -e "$DD/done" ]
    [ -d "$DD" ]
}

@test "orphan is terminated and its dir removed" {
    spawn_orphan stray
    run_cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"ORPHAN"*"stray"* ]]
    [ ! -e "$DD/stray" ]
    sleep 0.3
    ! kill -0 "$ORPHAN_PID" 2>/dev/null
}

@test "no exit_code and no process: kept, not removed" {
    mkdir -p "$DD/starting"
    run_cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"KEPT"*"starting"* ]]
    [ -d "$DD/starting" ]
}

@test "root is removed only when it ends up empty" {
    make_finished a
    make_finished b
    run_cleanup
    [ "$status" -eq 0 ]
    [ ! -e "$DD" ]
}

@test "ollama-loop worker (no claude child) counts as active, not orphan" {
    local w="$DD/ollama"
    mkdir -p "$w"
    python3 -c 'import subprocess; subprocess.run(["bash","-c","exec -a \"python3 tools/ollama-tool-loop.py\" sleep 300"])' "$w/run.sh" &
    echo $! >> "$PIDS_FILE"
    sleep 0.5
    run_cleanup
    [[ "$output" == *"ACTIVE"*"ollama"* ]]
    [ -d "$w" ]
}

@test "control: the pre-fix cleanup removes the active worker's dir" {
    # Extract only cmd_cleanup from the pre-fix revision and run it, after sourcing the
    # current script, against the sandbox. Proves the tests above bite.
    local old="$BATS_TEST_TMPDIR/old_cleanup.sh"
    git -C "$FRAMEWORK_ROOT" show "$PRE_FIX_REV:agents/termlink/termlink.sh" \
        | awk '/^cmd_cleanup\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' > "$old"
    grep -q 'rm -rf "\$DISPATCH_DIR"' "$old"
    spawn_active live
    run env FW_DISPATCH_DIR="$DD" bash -c "source '$TERMLINK_SH' >/dev/null 2>&1; source '$old'; [ \"\$DISPATCH_DIR\" = '$DD' ] || exit 99; cmd_cleanup"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ACTIVE"*"live"* ]]
    [ ! -e "$DD/live" ]
}

@test "lint: no test invokes termlink cleanup without a DISPATCH_DIR override" {
    run python3 - "$FRAMEWORK_ROOT/tests" <<'EOF'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
invoke = re.compile(r'(termlink(\.sh|_SH)?["\'}]*\s+cleanup\b|\bcmd_cleanup\b)', re.I)
bad = []
for p in root.rglob('*'):
    if p.suffix not in ('.bats', '.sh', '.py') or not p.is_file():
        continue
    for n, line in enumerate(p.read_text(errors='replace').splitlines(), 1):
        s = line.strip()
        if s.startswith('#') or s.startswith('@test') or not invoke.search(s):
            continue
        if re.search(r'grep|awk|\$output|^\s*\w+\(\)\s*\{', s):   # inspecting, not invoking (T-3716: assertions on $output)
            continue
        if 'DISPATCH_DIR' not in s and 'run_cleanup' not in s:
            bad.append(f'{p.relative_to(root)}:{n}: {s}')
for b in bad:
    print(b)
sys.exit(1 if bad else 0)
EOF
    echo "$output"
    [ "$status" -eq 0 ]
}
