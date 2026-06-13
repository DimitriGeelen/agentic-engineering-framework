#!/usr/bin/env bats
# T-2376 — continuous-loop auto-restart must self-advance.
#
# DEFECT (OBS-074): .claude/settings.json registered SessionStart matchers only
# for "compact" and "resume". The budget-critical auto-restart (claude-fw →
# `claude -c`) emits source "startup", which matched neither → post-compact-resume
# never fired on auto-restart → the loop restarted but current_iteration never
# advanced and the directive was never reinjected (manual /compact worked).
#
# FIX: (1) claude-fw writes a one-shot .auto-restart-pending sentinel before
# `claude -c`; (2) post-compact-resume.sh proceeds on source=startup ONLY when
# that sentinel is present (loop continuation), consuming it; a cold start
# (startup, no sentinel) stays a no-op as before; (3) lib/init.sh generator adds
# the startup matcher so fw init/upgrade wire it.
#
# Part A drives the REAL bin/claude-fw with a stub `claude` (no tokens burned).
# Part B drives the REAL post-compact-resume.sh against a temp PROJECT_ROOT.

setup() {
    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    WRAPPER="$FRAMEWORK_ROOT/bin/claude-fw"
    HOOK="$FRAMEWORK_ROOT/agents/context/post-compact-resume.sh"
    command -v git >/dev/null || skip "git unavailable"
    command -v python3 >/dev/null || skip "python3 unavailable"
    python3 -c "import yaml" 2>/dev/null || skip "pyyaml unavailable"

    PROJ="$(mktemp -d)"
    mkdir -p "$PROJ/.context/working" "$PROJ/.context/handovers"
    echo "# handover" > "$PROJ/.context/handovers/LATEST.md"
    SENTINEL="$PROJ/.context/working/.auto-restart-pending"
    CMODE="$PROJ/.context/working/.continuous-mode.yaml"
    cat > "$CMODE" <<YAML
enabled: true
max_iterations: 10
tier_ceiling: 1
current_iteration: 3
last_source: compact
YAML
    # Directive with NO T-NNNN reference → no tier-ceiling lookup → advances cleanly.
    cat > "$PROJ/.context/working/.next-directive.yaml" <<YAML
directive: |
  Continue the continuous-run loop. No specific task reference here.
filed_by: test
filed_at: 2026-06-13T00:00:00Z
max_iterations: 10
tier_ceiling: 1
YAML
}

teardown() {
    [ -n "${PROJ:-}" ] && rm -rf "$PROJ"
    [ -n "${BINDIR:-}" ] && rm -rf "$BINDIR"
    return 0
}

_iter() {
    grep -E '^current_iteration:' "$CMODE" | head -1 | sed 's/[^0-9]//g'
}

# Run the real resume hook with a given SessionStart source.
_run_hook() {
    local src="$1"
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$HOOK" <<< "{\"source\":\"$src\"}"
}

# ── Part A: claude-fw writes the sentinel before restarting via `claude -c` ──

@test "A: claude-fw writes .auto-restart-pending before auto-restart" {
    [ -f "$WRAPPER" ] || skip "bin/claude-fw not found"
    BINDIR="$(mktemp -d)"
    ( cd "$PROJ" && git init -q && git config user.email t@t && git config user.name t \
        && git commit -q --allow-empty -m init )
    # Stub claude: writes a fresh restart signal then exits → wrapper restarts on exit.
    cat > "$BINDIR/claude" <<'STUB'
#!/bin/bash
sig="$(git rev-parse --show-toplevel)/.context/working/.restart-requested"
echo '{"timestamp":"now","session_id":"stub","reason":"critical_budget_auto_handover","tokens":99999}' > "$sig"
echo "STUB-RAN"
exit 0
STUB
    chmod +x "$BINDIR/claude"
    cd "$PROJ"
    run timeout 40 env PATH="$BINDIR:$PATH" bash "$WRAPPER"
    [[ "$output" == *"Auto-restart #1"* ]]
    # The stub has no real resume hook to consume it, so the sentinel persists.
    [ -f "$SENTINEL" ]
}

# ── Part B: post-compact-resume.sh advance semantics by source ──

@test "B1: startup WITH sentinel → loop advances + sentinel consumed" {
    : > "$SENTINEL"
    run _run_hook startup
    [ "$status" -eq 0 ]
    [ -n "$output" ]                 # full resume path emits additionalContext
    [ "$(_iter)" -eq 4 ]            # 3 → 4
    [ ! -f "$SENTINEL" ]           # one-shot: consumed
}

@test "B2: startup WITHOUT sentinel (cold start) → no-op, iteration unchanged" {
    [ ! -f "$SENTINEL" ]
    run _run_hook startup
    [ "$status" -eq 0 ]
    [ -z "$output" ]                # exits before emitting anything
    [ "$(_iter)" -eq 3 ]           # unchanged
}

@test "B3: resume → loop advances (unchanged behavior)" {
    run _run_hook resume
    [ "$status" -eq 0 ]
    [ "$(_iter)" -eq 4 ]           # 3 → 4
}

@test "B4: compact → resets then advances to 1 (unchanged behavior)" {
    run _run_hook compact
    [ "$status" -eq 0 ]
    [ "$(_iter)" -eq 1 ]           # reset to 0, then +1
}
