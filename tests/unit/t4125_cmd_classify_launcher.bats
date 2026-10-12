#!/usr/bin/env bats
# T-4125 — the budget gate's wrap-up allowance must not admit a planted fw
# launcher at critical budget (same class as T-4108 in safe-commands.sh).
# Drives the REAL hook (stdin JSON incl. payload cwd -> exit code): 0 allowed, 2 blocked.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    GATE="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
    WORK="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$WORK/.context/working" "$BATS_TEST_TMPDIR/x/bin"
    printf '{"level":"critical","tokens":290000,"timestamp":%s,"source":"test"}' \
        "$(date +%s)" > "$WORK/.context/working/.budget-status"
}

# gate <command> [payload-cwd]
gate() {
    local json
    json=$(python3 -c 'import json,sys
d={"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}
if len(sys.argv)>2: d["cwd"]=sys.argv[2]
print(json.dumps(d))' "$@")
    output=$(printf '%s' "$json" | PROJECT_ROOT="$WORK" bash "$GATE" 2>&1)
    return $?
}

@test "planted absolute launcher: fw handover refused" {
    run gate "$BATS_TEST_TMPDIR/x/bin/fw handover" "$FRAMEWORK_ROOT"
    [ "$status" -eq 2 ]
}

@test "planted absolute launcher: fw git commit refused" {
    run gate "$BATS_TEST_TMPDIR/x/bin/fw git commit -m x" "$FRAMEWORK_ROOT"
    [ "$status" -eq 2 ]
}

@test "relative launcher after cd to a planted dir refused" {
    run gate "cd $BATS_TEST_TMPDIR/x && bin/fw git commit -m x" "$FRAMEWORK_ROOT"
    [ "$status" -eq 2 ]
}

@test "relative launcher after an unknowable cd refused" {
    run gate 'cd "$HOME/x" && bin/fw handover' "$FRAMEWORK_ROOT"
    [ "$status" -eq 2 ]
}

@test "relative launcher with payload cwd outside the project refused" {
    run gate "bin/fw handover" "$BATS_TEST_TMPDIR/x"
    [ "$status" -eq 2 ]
}

@test "relative launcher with no payload cwd refused" {
    run gate "bin/fw handover"
    [ "$status" -eq 2 ]
}

@test "PATH-reassigned bare fw refused" {
    run gate "PATH=$BATS_TEST_TMPDIR/x/bin fw handover" "$FRAMEWORK_ROOT"
    [ "$status" -eq 2 ]
}

@test "relative launcher with payload cwd = framework admitted" {
    run gate "bin/fw handover" "$FRAMEWORK_ROOT"
    [ "$status" -eq 0 ]
}

@test "own absolute launcher admitted" {
    run gate "$FRAMEWORK_ROOT/bin/fw git commit -m x" "$BATS_TEST_TMPDIR/x"
    [ "$status" -eq 0 ]
}

@test "prescribed cd <project> && bin/fw form admitted" {
    run gate "cd $FRAMEWORK_ROOT && bin/fw handover" "$BATS_TEST_TMPDIR/x"
    [ "$status" -eq 0 ]
}

@test "bare fw and plain git commit unchanged" {
    run gate "fw handover"
    [ "$status" -eq 0 ]
    run gate "git commit -m x"
    [ "$status" -eq 0 ]
}
