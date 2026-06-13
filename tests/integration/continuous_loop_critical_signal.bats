#!/usr/bin/env bats
# T-2378 — link #2 of the arc-012 continuous-run loop: a budget-critical token
# reading must drive checkpoint.sh to write .context/working/.restart-requested
# (the signal claude-fw's terminator, T-2373, watches), with the .next-directive
# directive folded in (T-2363).
#
# Chain coverage map:
#   #1 gauge reads tokens via stdin transcript_path  → budget_gauge_stdin_transcript.bats (T-2377)
#   #2 critical → .restart-requested written         → THIS FILE
#   #3 terminator fires on the signal                → claude_fw_restart_terminator.bats (T-2373)
#   #4 restart advances the loop                     → continuous_loop_auto_restart_advance.bats (T-2376)
#
# Drives the REAL agents/context/checkpoint.sh post-tool. handover.sh is stubbed via
# a fake FRAMEWORK_ROOT tree (symlinked checkpoint.sh + lib, stub handover) so no real
# git commit/push happens — checkpoint derives FRAMEWORK_ROOT from its own location, so
# running the symlinked copy redirects its handover call to the stub.

setup() {
    REAL="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    command -v python3 >/dev/null || skip "python3 unavailable"

    TMP="$(mktemp -d)"

    # Fake framework tree: real checkpoint.sh + real lib, but a STUB handover.sh.
    FAKEFW="$TMP/fw"
    mkdir -p "$FAKEFW/agents/context" "$FAKEFW/agents/handover"
    ln -s "$REAL/agents/context/checkpoint.sh" "$FAKEFW/agents/context/checkpoint.sh"
    ln -s "$REAL/lib" "$FAKEFW/lib"
    printf '#!/bin/bash\necho STUB-HANDOVER\nexit 0\n' > "$FAKEFW/agents/handover/handover.sh"
    chmod +x "$FAKEFW/agents/handover/handover.sh"
    CHECK="$FAKEFW/agents/context/checkpoint.sh"

    PROJ="$TMP/proj"
    mkdir -p "$PROJ/.context/working"
    echo "session_id: S-TEST-001" > "$PROJ/.context/working/session.yaml"
    SIGNAL="$PROJ/.context/working/.restart-requested"

    CRIT="$TMP/critical.jsonl"; _mk_transcript "$CRIT" 290000   # > 285K critical @ 300K
    OK="$TMP/ok.jsonl";        _mk_transcript "$OK"  50000      # < 225K warn → ok
}

teardown() {
    [ -n "${TMP:-}" ] && rm -rf "$TMP"
    return 0
}

_mk_transcript() {  # file, tokens
    printf '%s\n' "{\"timestamp\":\"2026-06-13T19:00:00.000Z\",\"message\":{\"model\":\"claude-opus-4\",\"usage\":{\"input_tokens\":$2,\"cache_read_input_tokens\":0,\"cache_creation_input_tokens\":0}}}" > "$1"
}

# Run the REAL (symlinked) checkpoint post-tool with a stdin transcript_path.
_run_post() {  # transcript_path
    printf '%s' "{\"hook_event_name\":\"PostToolUse\",\"transcript_path\":\"$1\",\"tool_name\":\"Read\"}" | \
        env HOME="$TMP/home" PROJECT_ROOT="$PROJ" FW_CONTEXT_WINDOW=300000 FW_HANDOVER_TOTAL_TIMEOUT=10 \
            bash "$CHECK" post-tool
}

@test "critical tokens → .restart-requested is written" {
    run _run_post "$CRIT"
    [ "$status" -eq 0 ]
    [ -f "$SIGNAL" ]
}

@test "restart signal carries reason=critical_budget_auto_handover + the token count" {
    _run_post "$CRIT" >/dev/null 2>&1
    [ -f "$SIGNAL" ]
    grep -q '"reason":"critical_budget_auto_handover"' "$SIGNAL"
    grep -q '"tokens":290000' "$SIGNAL"
}

@test "T-2363 directive-fold: directive present in signal when .next-directive.yaml has one" {
    printf 'directive: |\n  Continue the loop. No task ref here.\n' > "$PROJ/.context/working/.next-directive.yaml"
    _run_post "$CRIT" >/dev/null 2>&1
    [ -f "$SIGNAL" ]
    grep -q '"directive"' "$SIGNAL"
    grep -q 'Continue the loop' "$SIGNAL"
}

@test "T-2363 directive-fold: no directive key when .next-directive.yaml absent (backward compat)" {
    [ ! -f "$PROJ/.context/working/.next-directive.yaml" ]
    _run_post "$CRIT" >/dev/null 2>&1
    [ -f "$SIGNAL" ]
    ! grep -q '"directive"' "$SIGNAL"
}

@test "negative control: ok-level tokens do NOT write .restart-requested" {
    run _run_post "$OK"
    [ "$status" -eq 0 ]
    [ ! -f "$SIGNAL" ]
}

@test "handover is stubbed — no real git commit happens (no .git created in PROJ)" {
    _run_post "$CRIT" >/dev/null 2>&1
    [ -f "$SIGNAL" ]            # signal written (proves handover returned success)
    [ ! -d "$PROJ/.git" ]      # but no real handover/commit touched the project
}
