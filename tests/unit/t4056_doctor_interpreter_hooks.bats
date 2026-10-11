#!/usr/bin/env bats
# T-4056: fw doctor must treat an interpreter-prefixed hook command
# (python3 "$CLAUDE_PROJECT_DIR/scripts/x.py") as running its script argument,
# not the interpreter. Before the fix both hook checks took 'python3' as the
# script and reported 'script not found: python3' plus a broken hook path.
#
# Runs the real `fw doctor` against a temp project root (~8s per run) and greps
# the two hook lines. Fixtures live in BATS_TEST_TMPDIR, never in the repo.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$BATS_TEST_TMPDIR"
    PROJ="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJ/scripts" "$PROJ/.claude" "$PROJ/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJ/.framework.yaml"
}

# write_settings <json-command>: a single PreToolUse hook running <command>
write_settings() {
    printf '%s\n' "{\"hooks\":{\"PreToolUse\":[{\"matcher\":\"Bash\",\"hooks\":[{\"type\":\"command\",\"command\":$1}]}]}}" \
        > "$PROJ/.claude/settings.json"
}

# run_doctor: capture colour-stripped doctor output into $OUT
run_doctor() {
    OUT="$(PROJECT_ROOT="$PROJ" timeout 300 "$FRAMEWORK_ROOT/bin/fw" doctor 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
}

@test "T-4056: interpreter-prefixed hook with script present passes both hook checks" {
    printf 'print(1)\n' > "$PROJ/scripts/x.py"
    write_settings '"python3 \"$CLAUDE_PROJECT_DIR/scripts/x.py\""'
    run_doctor
    if echo "$OUT" | grep -q "script not found"; then false; fi
    if echo "$OUT" | grep -q "Hook path validation: .*broken"; then false; fi
    if echo "$OUT" | grep -q "script not executable: x.py"; then false; fi
    # the hook check ran; with one hook only the other expected hooks are reported missing
    echo "$OUT" | grep -q "Hook config: Expected hook check-active-task.sh"
}

@test "T-4056: interpreter-prefixed hook with script missing FAILs and names the script" {
    write_settings '"python3 \"$CLAUDE_PROJECT_DIR/scripts/missing.py\""'
    run_doctor
    if echo "$OUT" | grep -q "script not found: python3"; then false; fi
    echo "$OUT" | grep -q "Hook path validation: 1/1 hooks have broken paths"
    echo "$OUT" | grep -q "Hook config: PreToolUse: script not found: missing.py"
}

@test "T-4056: vendored 'fw hook' shape keeps its verdict (existing bin/fw passes)" {
    mkdir -p "$PROJ/bin"
    printf '#!/bin/sh\nexit 0\n' > "$PROJ/bin/fw" && chmod +x "$PROJ/bin/fw"
    write_settings '"${CLAUDE_PROJECT_DIR}/bin/fw hook check-tier0"'
    run_doctor
    if echo "$OUT" | grep -q "broken paths"; then false; fi
    if echo "$OUT" | grep -q "fw binary not found"; then false; fi
}
