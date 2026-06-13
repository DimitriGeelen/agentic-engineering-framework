#!/usr/bin/env bats
# T-2377 — the budget gauge must read the transcript Claude Code names on stdin,
# not a path reconstructed from PROJECT_ROOT.
#
# DEFECT: agents/context/{budget-gate.sh,checkpoint.sh} located the Claude Code
# transcript by reconstructing $HOME/.claude/projects/<sanitized PROJECT_ROOT>.
# In a git worktree / background job the session cwd is the worktree, but Claude
# Code keys the transcript dir on the LAUNCH cwd (the main repo). So the gauge
# searched the worktree-suffixed dir (empty / stale sibling) while the live
# transcript sat in the un-suffixed dir → "no usage data" → budget-critical was
# never detected → the arc-012 continuous-run loop never armed.
#
# FIX: prefer the authoritative transcript_path that Claude Code passes to every
# hook on stdin; fall back to reconstruction only when no stdin path is present.
#
# Discriminating setup: the RECONSTRUCTED dir holds a LOW-token (ok) transcript,
# the stdin transcript_path points at a HIGH-token (critical) transcript in an
# UNRELATED dir. If the stdin path wins → critical. If reconstruction wins → ok.

setup() {
    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    GATE="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
    CHECK="$FRAMEWORK_ROOT/agents/context/checkpoint.sh"
    command -v python3 >/dev/null || skip "python3 unavailable"

    TMP="$(mktemp -d)"
    HOME_DIR="$TMP/home"
    PROJ="$TMP/proj"                       # acts as PROJECT_ROOT (the worktree)
    mkdir -p "$PROJ/.context/working" "$HOME_DIR/.claude/projects"

    # Reconstructed project dir (what the OLD code would search) — STALE / low tokens.
    DIRNAME="$(printf '%s' "$PROJ" | tr -c 'a-zA-Z0-9' '-')"
    RECON_DIR="$HOME_DIR/.claude/projects/$DIRNAME"
    mkdir -p "$RECON_DIR"
    _usage_line "$RECON_DIR/stale.jsonl" 1000          # ok level

    # The transcript Claude Code actually names on stdin — HIGH tokens (critical).
    mkdir -p "$TMP/real"
    REAL="$TMP/real/live-session.jsonl"
    _usage_line "$REAL" 290000                         # > 285K critical @ 300K window

    STATUS="$PROJ/.context/working/.budget-status"
}

teardown() {
    [ -n "${TMP:-}" ] && rm -rf "$TMP"
    return 0
}

# Write a single usage entry (last-entry wins in the gauge's token scan).
_usage_line() {
    local file="$1" toks="$2"
    printf '%s\n' "{\"timestamp\":\"2026-06-13T19:00:00.000Z\",\"message\":{\"model\":\"claude-opus-4\",\"usage\":{\"input_tokens\":$toks,\"cache_read_input_tokens\":0,\"cache_creation_input_tokens\":0}}}" > "$file"
}

_run_gate() {  # stdin JSON on $1
    printf '%s' "$1" | \
        env HOME="$HOME_DIR" PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
            FW_CONTEXT_WINDOW=300000 bash "$GATE"
}

_level() { python3 -c "import json,sys; print(json.load(open('$STATUS')).get('level',''))" 2>/dev/null; }

# ── budget-gate.sh ──────────────────────────────────────────────────────────

@test "budget-gate: stdin transcript_path (critical) beats PROJECT_ROOT reconstruction (ok)" {
    run _run_gate "{\"hook_event_name\":\"PreToolUse\",\"transcript_path\":\"$REAL\",\"tool_name\":\"Read\",\"tool_input\":{}}"
    [ -f "$STATUS" ]
    [ "$(_level)" = "critical" ]    # proves the stdin path was read, not the stale recon dir
}

@test "budget-gate: no stdin transcript_path → falls back to reconstruction (no regression)" {
    run _run_gate "{\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Read\",\"tool_input\":{}}"
    [ -f "$STATUS" ]
    [ "$(_level)" = "ok" ]          # reconstruction found the stale (low-token) transcript
}

@test "budget-gate: stdin transcript_path pointing at a missing file → falls back to reconstruction" {
    run _run_gate "{\"hook_event_name\":\"PreToolUse\",\"transcript_path\":\"$TMP/does-not-exist.jsonl\",\"tool_name\":\"Read\",\"tool_input\":{}}"
    [ -f "$STATUS" ]
    [ "$(_level)" = "ok" ]          # bad path ignored, reconstruction used
}

# ── checkpoint.sh ───────────────────────────────────────────────────────────

@test "checkpoint status: FW_TRANSCRIPT_PATH (high) is read in preference to reconstruction (low)" {
    run env HOME="$HOME_DIR" PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        FW_CONTEXT_WINDOW=300000 FW_TRANSCRIPT_PATH="$REAL" bash "$CHECK" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"290000"* ]]   # explicit path used, not the stale 1000-token recon file
}

@test "checkpoint status: no explicit path → reconstruction reads the stale transcript" {
    run env HOME="$HOME_DIR" PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        FW_CONTEXT_WINDOW=300000 bash "$CHECK" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"1000"* ]]     # fallback path intact
}

@test "checkpoint post-tool: stdin transcript_path drives token detection" {
    env HOME="$HOME_DIR" PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        FW_CONTEXT_WINDOW=300000 bash "$CHECK" reset >/dev/null 2>&1 || true
    run bash -c "printf '%s' '{\"hook_event_name\":\"PostToolUse\",\"transcript_path\":\"$REAL\",\"tool_name\":\"Read\"}' | env HOME='$HOME_DIR' PROJECT_ROOT='$PROJ' FRAMEWORK_ROOT='$FRAMEWORK_ROOT' FW_CONTEXT_WINDOW=300000 bash '$CHECK' post-tool"
    [ "$status" -eq 0 ]             # must not crash; high-token path read without error
}
