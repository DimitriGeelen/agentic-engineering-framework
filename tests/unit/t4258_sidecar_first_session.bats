#!/usr/bin/env bats
# T-4258 (R14): a fresh `fw init` wires the SessionStart sidecar-autostart hook
# but no session has run yet, so fw doctor / fw audit must not WARN "No sidecar
# watcher" on a brand-new project. They report INFO until the hook has fired
# (autostart.log exists), then the R14 WARN applies again.

setup() {
    FW_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    ROOT="$(mktemp -d)"
    mkdir -p "$ROOT/.context/sidecar/watcher" "$ROOT/.claude"
    printf '{"hooks":{"SessionStart":[{"matcher":"startup","hooks":[{"type":"command","command":"bin/fw hook sidecar-autostart"}]}]}}\n' \
        > "$ROOT/.claude/settings.json"
    # shellcheck source=/dev/null
    source "$FW_ROOT/lib/sidecar-audit.sh"
}

teardown() {
    rm -rf "$ROOT"
}

@test "fresh init (hook wired, never fired): awaiting first session" {
    fw_sidecar_watcher_awaiting_first_session "$ROOT"
}

@test "control: autostart.log present (a session ran) -> not awaiting" {
    : > "$ROOT/.context/sidecar/watcher/autostart.log"
    run fw_sidecar_watcher_awaiting_first_session "$ROOT"
    [ "$status" -eq 1 ]
}

@test "control: sidecar enabled.json present -> not awaiting" {
    echo '{}' > "$ROOT/.context/sidecar/watcher/enabled.json"
    run fw_sidecar_watcher_awaiting_first_session "$ROOT"
    [ "$status" -eq 1 ]
}

@test "control: hook not wired in settings.json -> not awaiting (WARN stays)" {
    echo '{}' > "$ROOT/.claude/settings.json"
    run fw_sidecar_watcher_awaiting_first_session "$ROOT"
    [ "$status" -eq 1 ]
}

@test "fw doctor grades the awaiting case INFO before the R14 WARN" {
    run grep -n 'fw_sidecar_watcher_awaiting_first_session "\$PROJECT_ROOT"' "$FW_ROOT/bin/fw"
    [ "$status" -eq 0 ]
    hook_line=${output%%:*}
    warn_line=$(grep -n 'No sidecar watcher in this project (R14' "$FW_ROOT/bin/fw" | cut -d: -f1)
    [ "$hook_line" -lt "$warn_line" ]
    sed -n "${hook_line},$((hook_line + 3))p" "$FW_ROOT/bin/fw" | grep -q 'INFO.*first agent session'
}

@test "fw audit grades the awaiting case info before the R14 warn" {
    run grep -n 'fw_sidecar_watcher_awaiting_first_session "\$PROJECT_ROOT"' "$FW_ROOT/agents/audit/audit.sh"
    [ "$status" -eq 0 ]
    hook_line=${output%%:*}
    warn_line=$(grep -n 'warn "No sidecar watcher in this project"' "$FW_ROOT/agents/audit/audit.sh" | cut -d: -f1)
    [ "$hook_line" -lt "$warn_line" ]
    sed -n "${hook_line},$((hook_line + 3))p" "$FW_ROOT/agents/audit/audit.sh" | grep -q 'info "No sidecar watcher yet'
}

@test "liveness of a fresh root is absent and not nothing-wakes (so the INFO branch is reachable)" {
    command -v python3 >/dev/null || skip "python3 absent"
    out=$(fw_sidecar_watcher_facts "$ROOT")
    state=$(printf '%s' "$out" | cut -f1)
    wake=$(printf '%s' "$out" | cut -f7)
    [ "$state" = "absent" ]
    [ "$wake" != "none" ]
}
