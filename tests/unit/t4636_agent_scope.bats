#!/usr/bin/env bats
# T-4636 (T-4635 RCA) — long-lived agent processes lived in the caller's login-session scope
# (root: session-*.scope in user-0.slice), and a forced teardown of that slice killed every
# session and worker at once. lib/agent-scope.sh gives claude-fw and `fw termlink spawn` a
# `systemd-run --scope --slice=agentic.slice` prefix, and falls back (logged once) where
# systemd cannot. The first test uses the REAL systemd on hosts that have it; every other
# test uses a stub systemd-run that records its argv. FW_AGENT_SCOPE_CGROUP_FILE points the
# "already placed?" check at a fake session-scope cgroup so the result does not depend on
# where this test itself happens to run.

export CLAUDE_FW_NO_SIDECAR=1

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    T="$(mktemp -d)"
    T="$(cd "$T" && pwd -P)"
    mkdir -p "$T/bin" "$T/proj/.context/working" "$T/dispatch"
    : > "$T/proj/.framework.yaml"
    echo "0::/user.slice/user-0.slice/session-42.scope" > "$T/cgroup.session"
    echo "0::/agentic.slice/run-u7.scope" > "$T/cgroup.agentic"
    mkdir -p "$T/systemd"
    export FW_AGENT_SCOPE_CGROUP_FILE="$T/cgroup.session"
    unset FW_AGENT_SCOPE FW_CFW_SCOPED_PID
}

teardown() { rm -rf "$T"; }

# Stub systemd-run: append its argv (one line) to $T/sdr.log. With $1 = exec, run whatever
# follows `--` (as the real one does in --scope mode); otherwise exit with $2 (default 0).
_stub_sdr() {
    cat > "$T/bin/systemd-run" <<EOF
#!/bin/bash
echo "\$*" >> "$T/sdr.log"
[ "${1:-}" = exec ] || exit ${2:-0}
while [ \$# -gt 0 ] && [ "\$1" != "--" ]; do shift; done
shift; exec "\$@"
EOF
    chmod +x "$T/bin/systemd-run"
}

_prefix() {   # run fw_agent_scope_prefix in a subshell; print the array, one word per line
    PROJECT_ROOT="$T/proj" bash -c '. "$1/lib/agent-scope.sh"; fw_agent_scope_prefix test
        printf "%s\n" ${FW_AGENT_SCOPE_CMD[@]+"${FW_AGENT_SCOPE_CMD[@]}"}' _ "$ROOT"
}

@test "T-4636: a process launched through the prefix lives in agentic.slice, not a session scope (real systemd)" {
    command -v systemd-run >/dev/null 2>&1 && [ -d /run/systemd/system ] \
        || skip "no systemd on this host (the fallback tests cover it)"
    out=$(PROJECT_ROOT="$T/proj" bash -c '. "$1/lib/agent-scope.sh"; fw_agent_scope_prefix test
        [ "${#FW_AGENT_SCOPE_CMD[@]}" -gt 0 ] || { echo "NO-PREFIX"; exit 0; }
        "${FW_AGENT_SCOPE_CMD[@]}" cat /proc/self/cgroup' _ "$ROOT" 2>&1)
    echo "$out"
    if [ "$out" = "NO-PREFIX" ] || grep -q "^fw: WARNING" <<<"$out"; then
        [ "$(id -u)" -ne 0 ] || { echo "root on a systemd host must get a scope"; false; }
        skip "systemd refuses a system scope to uid $(id -u) (fallback path covered below)"
    fi
    grep -q "/agentic.slice/" <<<"$out"
    ! grep -q "session-.*\.scope" <<<"$out" || false
}

@test "T-4636: with a working systemd-run the prefix is a --scope in agentic.slice" {
    _stub_sdr
    run env PATH="$T/bin:$PATH" FW_AGENT_SCOPE_SYSTEMD_DIR="$T/systemd" bash -c "$(declare -f _prefix); ROOT='$ROOT' T='$T' _prefix"
    [ "$status" -eq 0 ]
    [ "$(sed -n 1p <<<"$output")" = "systemd-run" ]
    grep -qx -- "--scope" <<<"$output"
    grep -qx -- "--slice=agentic.slice" <<<"$output"
    [ "$(tail -1 <<<"$output")" = "--" ]
    grep -q -- "--scope.* -- true" "$T/sdr.log"     # it probed before promising a scope
}

@test "T-4636: already inside agentic.slice there is no prefix, no probe and no warning" {
    _stub_sdr
    run env PATH="$T/bin:$PATH" FW_AGENT_SCOPE_SYSTEMD_DIR="$T/systemd" \
        FW_AGENT_SCOPE_CGROUP_FILE="$T/cgroup.agentic" bash -c "$(declare -f _prefix); ROOT='$ROOT' T='$T' _prefix"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -e "$T/sdr.log" ]
}

@test "T-4636: FW_AGENT_SCOPE=0 opts out silently" {
    _stub_sdr
    run env PATH="$T/bin:$PATH" FW_AGENT_SCOPE=0 bash -c "$(declare -f _prefix); ROOT='$ROOT' T='$T' _prefix"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -e "$T/sdr.log" ]
    [ ! -e "$T/proj/.context/working/agent-scope.log" ]
}

@test "T-4636: systemd-run refusing falls back to no prefix, warns once and logs once" {
    _stub_sdr noexec 1
    run env PATH="$T/bin:$PATH" FW_AGENT_SCOPE_SYSTEMD_DIR="$T/systemd" bash -c "$(declare -f _prefix); ROOT='$ROOT' T='$T' _prefix"
    [ "$status" -eq 0 ]
    [ "$output" = "fw: WARNING: test runs without its own systemd scope (systemd-run --scope refused (no permission for a system scope?)); a login-session teardown can kill it. Host fix: loginctl enable-linger $(id -un) (T-4636) — logged once to $T/proj/.context/working/agent-scope.log" ]
    [ "$(grep -c 'reason=systemd-run --scope refused' "$T/proj/.context/working/agent-scope.log")" -eq 1 ]
    # Second call, same reason: silent, nothing new in the log.
    run env PATH="$T/bin:$PATH" FW_AGENT_SCOPE_SYSTEMD_DIR="$T/systemd" bash -c "$(declare -f _prefix); ROOT='$ROOT' T='$T' _prefix"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ "$(wc -l < "$T/proj/.context/working/agent-scope.log")" -eq 1 ]
}

@test "T-4636: no systemd (init dir absent, or systemd-run missing) falls back with the reason named" {
    _stub_sdr
    run env PATH="$T/bin:$PATH" FW_AGENT_SCOPE_SYSTEMD_DIR="$T/nonexistent" bash -c "$(declare -f _prefix); ROOT='$ROOT' T='$T' _prefix"
    [ "$status" -eq 0 ]
    grep -q "systemd is not the init system" <<<"$output"
    ! grep -qx "systemd-run" <<<"$output" || false
    # A PATH holding only the tools the helper needs, and no systemd-run.
    mkdir -p "$T/min"
    for t in bash grep date id timeout printf; do ln -sf "$(command -v "$t")" "$T/min/$t"; done
    run env PATH="$T/min" bash -c "$(declare -f _prefix); ROOT='$ROOT' T='$T' _prefix"
    [ "$status" -eq 0 ]
    grep -q "systemd-run not found" <<<"$output"
    [ "$(wc -l < "$T/proj/.context/working/agent-scope.log")" -eq 2 ]
}

@test "T-4636: claude-fw re-execs itself through the scope prefix exactly once, then runs claude" {
    _stub_sdr exec
    printf '#!/bin/bash\necho "claude ran: $*" >> %q\nexit 0\n' "$T/claude.log" > "$T/bin/claude"
    chmod +x "$T/bin/claude"
    run env -u TMUX -u FW_DISPATCHED_WORKER -u TL_CLAUDE_ENABLED PATH="$T/bin:$PATH" HOME="$T" \
        FW_AGENT_SCOPE_SYSTEMD_DIR="$T/systemd" FW_CLAUDE_FW_NO_TMUX=1 \
        bash -c "cd '$T/proj' && timeout 30 bash '$ROOT/bin/claude-fw' --no-restart -p hello < /dev/null"
    echo "$output"; cat "$T/sdr.log"
    [ "$(grep -c -- ' -- true$' "$T/sdr.log")" -eq 1 ]                 # one probe
    launch=$(grep -v -- ' -- true$' "$T/sdr.log")
    [ "$(grep -c . <<<"$launch")" -eq 1 ]                               # one launch, no loop
    grep -q -- "--slice=agentic.slice .*-- bash $(readlink -f "$ROOT/bin/claude-fw") --no-restart -p hello$" <<<"$launch"
    grep -q "claude ran: .*hello" "$T/claude.log"
}

@test "T-4636: fw termlink spawn runs termlink spawn through the scope prefix" {
    _stub_sdr exec
    printf '#!/bin/bash\necho "termlink $*" >> %q\nexit 0\n' "$T/termlink.log" > "$T/bin/termlink"
    chmod +x "$T/bin/termlink"
    run env PATH="$T/bin:$PATH" PROJECT_ROOT="$T/proj" FW_DISPATCH_DIR="$T/dispatch" \
        FW_AGENT_SCOPE_SYSTEMD_DIR="$T/systemd" \
        bash "$ROOT/agents/termlink/termlink.sh" spawn --name t4636-w --task T-4636
    echo "$output"
    [ "$status" -eq 0 ]
    grep -q -- "--slice=agentic.slice .*-- termlink spawn --name t4636-w" "$T/sdr.log"
    grep -q "^termlink spawn --name t4636-w" "$T/termlink.log"
}

@test "T-4636: fw termlink spawn without systemd still spawns (fallback)" {
    printf '#!/bin/bash\necho "termlink $*" >> %q\nexit 0\n' "$T/termlink.log" > "$T/bin/termlink"
    chmod +x "$T/bin/termlink"
    run env PATH="$T/bin:$PATH" PROJECT_ROOT="$T/proj" FW_DISPATCH_DIR="$T/dispatch" \
        FW_AGENT_SCOPE_SYSTEMD_DIR="$T/nonexistent" \
        bash "$ROOT/agents/termlink/termlink.sh" spawn --name t4636-f --task T-4636
    echo "$output"
    [ "$status" -eq 0 ]
    grep -q "^termlink spawn --name t4636-f" "$T/termlink.log"
    grep -q "systemd is not the init system" "$T/proj/.context/working/agent-scope.log"
}
