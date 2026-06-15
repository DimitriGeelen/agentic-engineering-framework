#!/usr/bin/env bats
# T-2411 — claude-fw startup banner.
#
# Adds a one-shot project overview before `command claude` takes the screen:
#   project / branch / focus / arc
#
# These tests drive the REAL bin/claude-fw wrapper with a STUB `claude` on PATH.
# Cases:
#   - banner-on-cold-start  : banner prints once, with project/branch/focus/arc
#   - banner-not-on-restart : on auto-restart iteration the banner does NOT repeat
#   - opt-out               : FW_NO_STARTUP_BANNER=1 suppresses the banner entirely
#   - degraded-graceful     : missing focus/arc files → "(none)" / non-fatal

setup() {
    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    WRAPPER="$FRAMEWORK_ROOT/bin/claude-fw"
    [ -f "$WRAPPER" ] || skip "bin/claude-fw not found"
    command -v git >/dev/null || skip "git unavailable"

    PROJ="$(mktemp -d)"
    BINDIR="$(mktemp -d)"
    ( cd "$PROJ" && git init -q && git config user.email t@t && git config user.name t \
        && git commit -q --allow-empty -m init && git checkout -q -b feature-x )
    mkdir -p "$PROJ/.context/working"
    SIG="$PROJ/.context/working/.restart-requested"
    # Fast terminator/loop so the test doesn't take 50s.
    export FW_TERMINATOR_POLL=1
    export FW_TERMINATOR_GRACE=1
}

teardown() {
    [ -n "${PROJ:-}" ] && rm -rf "$PROJ"
    [ -n "${BINDIR:-}" ] && rm -rf "$BINDIR"
}

# $1 = stub tail action ("sleep 30" or "exit 0"), $2 = optional write-signal? ("yes"/"no", default no)
_make_stub() {
    local tail_action="$1" write_sig="${2:-no}"
    cat > "$BINDIR/claude" <<STUB
#!/bin/bash
if [ "$write_sig" = "yes" ]; then
    sig="\$(git rev-parse --show-toplevel)/.context/working/.restart-requested"
    echo '{"timestamp":"now","session_id":"stub","reason":"critical_budget_auto_handover","tokens":99999}' > "\$sig"
fi
echo "STUB-CLAUDE-RAN"
$tail_action
STUB
    chmod +x "$BINDIR/claude"
}

@test "FIX: banner prints on cold start with project/branch/focus/arc" {
    _make_stub "exit 0" "no"
    cat > "$PROJ/.context/working/focus.yaml" <<EOF
current_task: T-9999
EOF
    cat > "$PROJ/.context/working/arc-focus.yaml" <<EOF
current_arc: my-test-arc
EOF
    cd "$PROJ"
    run timeout 20 env PATH="$BINDIR:$PATH" bash "$WRAPPER" --no-restart
    [[ "$output" == *"╭─ claude-fw"* ]]
    # Project basename of the tmp git root
    [[ "$output" == *"project : $(basename "$PROJ")"* ]]
    [[ "$output" == *"branch  : feature-x"* ]]
    [[ "$output" == *"focus   : T-9999"* ]]
    [[ "$output" == *"arc     : my-test-arc"* ]]
}

@test "FIX: banner does NOT re-fire on auto-restart iteration" {
    # Stub writes a fresh restart signal then exits → wrapper restarts until MAX(5).
    _make_stub "exit 0" "yes"
    cd "$PROJ"
    run timeout 40 env PATH="$BINDIR:$PATH" bash "$WRAPPER"
    [[ "$output" == *"Auto-restart #1"* ]]
    # Banner box-top should appear exactly once across the whole run.
    local n
    n=$(printf '%s\n' "$output" | grep -c "╭─ claude-fw" || true)
    [ "$n" = "1" ]
}

@test "OPT-OUT: FW_NO_STARTUP_BANNER=1 suppresses banner entirely" {
    _make_stub "exit 0" "no"
    cd "$PROJ"
    run timeout 20 env PATH="$BINDIR:$PATH" FW_NO_STARTUP_BANNER=1 bash "$WRAPPER" --no-restart
    [[ "$output" != *"╭─ claude-fw"* ]]
    # Stub still ran (proves wrapper executed claude normally).
    [[ "$output" == *"STUB-CLAUDE-RAN"* ]]
}

@test "GRACEFUL: missing focus + arc files → (none) / non-fatal" {
    _make_stub "exit 0" "no"
    # No focus.yaml, no arc-focus.yaml — only the working dir exists.
    cd "$PROJ"
    run timeout 20 env PATH="$BINDIR:$PATH" bash "$WRAPPER" --no-restart
    [ "$status" -eq 0 ]
    [[ "$output" == *"╭─ claude-fw"* ]]
    [[ "$output" == *"focus   : (none)"* ]]
    [[ "$output" == *"arc     : (none)"* ]]
}
