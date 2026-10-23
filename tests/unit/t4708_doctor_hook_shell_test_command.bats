#!/usr/bin/env bats
# T-4708 (TermLink be.10, sidecar c896df19): fw doctor's hook-config check took
# the first whitespace token of a hook command as its script path, so a hook
# that starts with a shell test —
#     [ -z "${TERMLINK_SIDECAR_SOCKET:-}" ] || exec termlink sidecar hook stop
# — was reported 'script not found: ['. The command is now tokenised with shlex
# and split at shell operators; builtins, keywords, test brackets, wrappers and
# assignments are skipped, and only a path-like program is checked.
#
# Runs the real `fw doctor` against a temp project root, as t4056 does.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$BATS_TEST_TMPDIR"
    PROJ="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJ/scripts" "$PROJ/.claude" "$PROJ/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJ/.framework.yaml"
}

# write_settings <json-command>: a single Stop hook running <command>
write_settings() {
    printf '%s\n' "{\"hooks\":{\"Stop\":[{\"hooks\":[{\"type\":\"command\",\"command\":$1}]}]}}" \
        > "$PROJ/.claude/settings.json"
}

run_doctor() {
    OUT="$(PROJECT_ROOT="$PROJ" timeout 300 "$FRAMEWORK_ROOT/bin/fw" doctor 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
}

@test "T-4708: TermLink's shell-test hook command is not reported as a missing script" {
    write_settings '"[ -z \"${TERMLINK_SIDECAR_SOCKET:-}\" ] || exec termlink sidecar hook stop"'
    run_doctor
    echo "$OUT" | grep 'Hook config' || true
    if echo "$OUT" | grep -q "script not found"; then false; fi
    # the check ran (only the expected-hook warnings remain)
    echo "$OUT" | grep -q "Hook config: Expected hook check-active-task.sh"
}

@test "T-4708: other non-path leaders (assignment, [[, test, !) are skipped too" {
    write_settings '"FOO=1 [[ -n \"$X\" ]] && test -x /bin/sh; ! command -v termlink >/dev/null 2>&1 || true"'
    run_doctor
    echo "$OUT" | grep 'Hook config' || true
    if echo "$OUT" | grep -q "script not found"; then false; fi
    echo "$OUT" | grep -q "Hook config: Expected hook check-active-task.sh"
}

@test "T-4708: a genuinely missing script after a shell test is still reported" {
    write_settings '"[ -n \"$X\" ] || \"$CLAUDE_PROJECT_DIR\"/scripts/missing.sh"'
    run_doctor
    echo "$OUT" | grep 'Hook config' || true
    echo "$OUT" | grep -q "Hook config: Stop: script not found: missing.sh"
}

@test "T-4708: a plain missing relative script is still reported" {
    write_settings '"./scripts/gone.sh --flag"'
    run_doctor
    echo "$OUT" | grep -q "Hook config: Stop: script not found: gone.sh"
}

@test "T-4708: a present script after a shell test passes" {
    printf '#!/bin/sh\nexit 0\n' > "$PROJ/scripts/ok.sh" && chmod +x "$PROJ/scripts/ok.sh"
    write_settings '"[ -n \"$X\" ] || \"$CLAUDE_PROJECT_DIR\"/scripts/ok.sh"'
    run_doctor
    if echo "$OUT" | grep -q "script not found"; then false; fi
    if echo "$OUT" | grep -q "script not executable: ok.sh"; then false; fi
}
