#!/usr/bin/env bats
# T-3346 — claude-fw --termlink must not tear down its own live claude.
#
# The old exit-detection grepped PTY output for shell-prompt glyphs, and `❯` —
# Claude Code's own TUI input caret — matched while claude was RUNNING. The
# wrapper concluded "claude exited", exited itself, and its cleanup trap injected
# `exit` into the PTY, killing the session ~1 min after every launch (captured
# live 2026-09-07, session claude-master-3884548).
#
# These tests lift _tl_claude_exit_code out of the real wrapper (house style:
# claude_fw_restart_mode.bats) so editing bin/claude-fw moves the assertions.

setup() {
    SRC="${BATS_TEST_DIRNAME}/../../bin/claude-fw"
}

# Extract the _tl_claude_exit_code function definition from the live source.
extract_helper() {
    python3 - "$SRC" <<'PY'
import sys
lines = open(sys.argv[1]).read().split('\n')
for start, line in enumerate(lines):
    if line.startswith('_tl_claude_exit_code()'):
        for end in range(start, len(lines)):
            if lines[end] == '}':
                print('\n'.join(lines[start:end + 1]))
                raise SystemExit(0)
raise SystemExit("_tl_claude_exit_code not found in bin/claude-fw")
PY
}

run_helper() {
    local helper text="$1"
    helper=$(extract_helper)
    bash -c "$helper"'
_tl_claude_exit_code "$1"' _ "$text"
}

@test "helper function exists in the live wrapper source" {
    run extract_helper
    [ "$status" -eq 0 ]
    [[ "$output" == *"grep -oE"* ]]
}

@test "live TUI screen with caret ❯ is NOT an exit (the T-3346 false positive)" {
    screen=$'✻ resume session state aggregation\n────────────────\n❯\nenter to collapse · ? for shortcuts'
    run run_helper "$screen"
    [ "$status" -ne 0 ]
}

@test "PTY echo of the injected command (%s form) is NOT an exit" {
    screen=$'root@host:/opt/repo# claude ; printf \x27__CLAUDE_FW_EXIT_%s__\\n\x27 "$?"\n❯ working…'
    run run_helper "$screen"
    [ "$status" -ne 0 ]
}

@test "digit marker IS an exit and yields claude's real exit code" {
    screen=$'…session output…\n__CLAUDE_FW_EXIT_0__\nroot@host:/opt/repo#'
    run run_helper "$screen"
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "non-zero exit code survives the parse" {
    screen=$'boom\n__CLAUDE_FW_EXIT_143__\nroot@host:/opt/repo#'
    run run_helper "$screen"
    [ "$status" -eq 0 ]
    [ "$output" = "143" ]
}

@test "plain shell prompt alone (root@…#) is not misread as an exit" {
    # Inverse defect: the old regex would never have matched this host's real
    # prompt anyway; the marker approach simply doesn't care about prompts.
    screen=$'root@dimitrimintdev:/opt/999-Agentic-Engineering-Framework#'
    run run_helper "$screen"
    [ "$status" -ne 0 ]
}

@test "the prompt-glyph regex is gone from the wrapper" {
    ! grep -q '➜' "$SRC"
}

@test "the injection line carries the marker printf" {
    grep -q 'CLAUDE_FW_EXIT_%s' "$SRC"
}
