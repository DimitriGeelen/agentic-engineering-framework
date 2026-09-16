#!/usr/bin/env bats
# T-3358 — claude-fw --termlink exit-detection must fire under a ROOT prompt,
# not only a `user@` one, and must trigger termlink_cleanup so no session is
# orphaned.
#
# RCA (T-3358): the wrapper at some point in its history matched the PTY tail
# against an enumerated prompt-glyph alternation (`^user@`, no `root@` branch).
# On root-fleet hosts, where every session runs as uid 0, the detector's true
# branch was unreachable — exit was never observed, `termlink_cleanup` never
# ran, and the TermLink session sat attached to a dead root shell indefinitely.
#
# T-3346 already replaced prompt-glyph matching with an explicit exit marker
# (_tl_claude_exit_code) — a fix that is prompt-agnostic by construction and so
# already covers the root-prompt case; tests/unit/t3346_termlink_exit_marker.bats
# pins the helper directly. This file adds the T-3358-scoped regression the task
# names explicitly: (1) unit coverage anchored to a ROOT prompt shape specifically
# (not just "any prompt"), and (2) an end-to-end drive of the real TermLink poll
# loop in bin/claude-fw proving that a root-prompt-only screen does NOT fire
# cleanup, and that cleanup (termlink_cleanup: PTY "exit" injection + `termlink
# clean`) DOES fire once the marker appears — so a live root-fleet session is
# never torn down early, and a dead one is never left orphaned.

setup() {
    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    SRC="$FRAMEWORK_ROOT/bin/claude-fw"
}

# ── Part 1: helper unit coverage, root-prompt-scoped (lifted from live source,
#    house style per t3346_termlink_exit_marker.bats / claude_fw_restart_mode.bats) ──

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

@test "root prompt ALONE (root@host:/path#, no marker) is NOT an exit" {
    screen=$'root@dimitri-fleet-01:/opt/999-Agentic-Engineering-Framework# '
    run run_helper "$screen"
    [ "$status" -ne 0 ]
}

@test "root prompt WITH the marker IS an exit, marker code survives" {
    screen=$'…claude session output…\n__CLAUDE_FW_EXIT_0__\nroot@dimitri-fleet-01:/opt/999-Agentic-Engineering-Framework# '
    run run_helper "$screen"
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "root prompt with non-zero marker code survives the parse" {
    screen=$'boom\n__CLAUDE_FW_EXIT_137__\nroot@fleet-host:/opt/repo# '
    run run_helper "$screen"
    [ "$status" -eq 0 ]
    [ "$output" = "137" ]
}

@test "detector never special-cases user vs root — same helper, both prompts" {
    # Control: a non-root user@ prompt with the marker behaves identically,
    # proving the fix is prompt-shape-agnostic rather than a second enumerated
    # alternative (the class of fix this task's RCA explicitly rejects).
    root_screen=$'x\n__CLAUDE_FW_EXIT_42__\nroot@host:/path# '
    user_screen=$'x\n__CLAUDE_FW_EXIT_42__\nuser@host:/path$ '
    run run_helper "$root_screen"
    root_status=$status; root_output=$output
    run run_helper "$user_screen"
    [ "$root_status" -eq "$status" ]
    [ "$root_output" = "$output" ]
}

# ── Part 2: end-to-end drive of the real TermLink poll loop with a stub
#    `termlink`, proving cleanup behavior — not just the helper function. ──

setup_e2e() {
    command -v python3 >/dev/null || skip "python3 unavailable"
    STATE="$(mktemp -d)"
    BINDIR="$(mktemp -d)"
    PROJ="$(mktemp -d)"
    mkdir -p "$PROJ/.context/working"
    echo "0" > "$STATE/poll_count"
    : > "$STATE/calls.log"

    cat > "$BINDIR/termlink" <<STUB
#!/bin/bash
# T-3358 stub termlink: records every invocation, and simulates a PTY screen
# that shows a bare ROOT PROMPT for the first poll, then the real exit marker
# from the second poll onward — so a real poll cycle must pass through
# "root prompt visible, no marker" before "marker visible" is ever true.
echo "\$*" >> "$STATE/calls.log"
case "\$1" in
    spawn)
        exit 0
        ;;
    pty)
        case "\$2" in
            inject)
                exit 0
                ;;
            output)
                n=\$(cat "$STATE/poll_count")
                n=\$((n + 1))
                echo "\$n" > "$STATE/poll_count"
                if [ "\$n" -lt 2 ]; then
                    printf 'root@fleet-host:/opt/repo# \n'
                else
                    printf '…claude ran…\n__CLAUDE_FW_EXIT_0__\nroot@fleet-host:/opt/repo# \n'
                fi
                exit 0
                ;;
            *)
                exit 0
                ;;
        esac
        ;;
    ping)
        exit 0
        ;;
    clean)
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
STUB
    chmod +x "$BINDIR/termlink"
}

teardown() {
    [ -n "${STATE:-}" ] && rm -rf "$STATE"
    [ -n "${BINDIR:-}" ] && rm -rf "$BINDIR"
    [ -n "${PROJ:-}" ] && rm -rf "$PROJ"
    # MUST return 0. Only the Part 2 E2E tests call setup_e2e, so for the Part 1
    # helper tests PROJ is unset, the final `[ -n ... ]` evaluates false, and
    # teardown exits 1 — which bats reports as the TEST failing, at the teardown
    # line, with the assertions themselves never implicated. All four Part 1
    # tests were red on this alone.
    return 0
}

@test "E2E: root-prompt-only poll does not trigger cleanup; marker poll does" {
    setup_e2e
    cd "$PROJ"
    run timeout 60 env PATH="$BINDIR:$PATH" FW_NO_STARTUP_BANNER=1 \
        bash "$SRC" --termlink --no-restart -p "hello"
    [ "$status" -eq 0 ]

    # At least two polls happened (root-prompt-only, then marker) — proves the
    # loop did NOT stop on the first (marker-less, root-prompt-only) screen.
    run cat "$STATE/poll_count"
    [ "$output" -ge 2 ]

    # termlink_cleanup ran: PTY "exit" injected AND `termlink clean` called —
    # this is the observable proof that a root-fleet session is torn down
    # cleanly rather than left orphaned once the marker is actually seen.
    run cat "$STATE/calls.log"
    [[ "$output" == *"pty inject claude-master-"*" exit --enter"* ]]
    [[ "$output" == *$'\n'"clean"* ]] || [[ "$output" == "clean"* ]]
}

@test "E2E control: if only a bare root prompt is ever shown, wrapper never falsely exits early" {
    # Same stub, but poll_count starts pinned so output() always returns the
    # marker-less root-prompt screen — proves the wrapper keeps polling
    # (does not misread the prompt itself as an exit) rather than a timing
    # coincidence in the primary test above.
    setup_e2e
    cat > "$BINDIR/termlink" <<STUB
#!/bin/bash
echo "\$*" >> "$STATE/calls.log"
case "\$1" in
    spawn) exit 0 ;;
    pty)
        case "\$2" in
            inject) exit 0 ;;
            output) printf 'root@fleet-host:/opt/repo# \n'; exit 0 ;;
            *) exit 0 ;;
        esac
        ;;
    ping) exit 0 ;;
    clean) exit 0 ;;
    *) exit 0 ;;
esac
STUB
    chmod +x "$BINDIR/termlink"
    cd "$PROJ"
    # No marker ever appears → the loop must never break on its own; bound the
    # wait and assert it is still polling (not exited) when time runs out.
    run timeout 12 env PATH="$BINDIR:$PATH" FW_NO_STARTUP_BANNER=1 \
        bash "$SRC" --termlink --no-restart -p "hello"
    [ "$status" -eq 124 ]

    # status 124 above is the whole "never exits early" property: no marker was
    # ever shown, so the loop could only still be polling when time ran out.
    #
    # This used to additionally assert that calls.log contained NO
    # `pty inject … exit --enter`, and that assertion was wrong — it was the one
    # red test left after the teardown fix. `bin/claude-fw:125` installs
    # `trap 'termlink_cleanup; …' EXIT`, so when `timeout` SIGTERMs the wrapper
    # the trap fires and cleanup injects `exit`. That is not a false early exit;
    # it is exactly the anti-orphaning guarantee T-3358 exists to provide, and a
    # product change to satisfy the old assertion would have REINTRODUCED the
    # orphaned-session bug this task was filed for.
    #
    # So the assertion is inverted rather than dropped: cleanup must run, and
    # exactly once. Zero would mean an orphaned session; more than once would
    # mean the trap and the poll loop both fired, which is the double-cleanup
    # this suite should also catch.
    run cat "$STATE/calls.log"
    local _n_cleanup
    _n_cleanup="$(printf '%s\n' "$output" | grep -c "pty inject claude-master-.* exit --enter" || true)"
    [ "$_n_cleanup" -eq 1 ]
}
