#!/usr/bin/env bash
# lib/agent-scope.sh — T-4636 (T-4635 RCA, docs/reports/T-4635-session-kill-rca.md).
#
# Long-lived agent processes (claude-fw, the tmux server it or `termlink spawn` starts, and
# every dispatch worker inside that server) used to live in the cgroup of whoever launched
# them: for root, a transient `session-*.scope` in `user-0.slice`. Root does not linger, cron
# closes root's last session every minute, and under load systemd's stop of that slice times
# out and SIGKILLs everything still in it — every session and worker at once.
#
# fw_agent_scope_prefix <label> sets the array FW_AGENT_SCOPE_CMD to a `systemd-run --scope`
# prefix that starts the command in its own transient scope under $FW_AGENT_SLICE
# (agentic.slice), outside every login session. --scope keeps the command in the foreground
# on the caller's terminal and environment, and systemd-run execs it, so the pid is kept.
# The array is EMPTY (run the command as before) when:
#   - FW_AGENT_SCOPE=0 (opt-out; silent),
#   - this process already lives under $FW_AGENT_SLICE (silent; no nested scope),
#   - systemd-run is missing, systemd is not the init system, or systemd-run refuses a probe
#     scope (a non-root user without polkit, a container). That fallback is logged ONCE per
#     reason: a stderr warning plus a line in .context/working/agent-scope.log.
# Test seams: FW_AGENT_SCOPE_CGROUP_FILE (default /proc/self/cgroup) and
# FW_AGENT_SCOPE_SYSTEMD_DIR (default /run/systemd/system).

FW_AGENT_SLICE="${FW_AGENT_SLICE:-agentic.slice}"

fw_agent_scope_prefix() {
    local label="${1:-agent}" reason="" probe=()
    FW_AGENT_SCOPE_CMD=()
    [ "${FW_AGENT_SCOPE:-1}" = 0 ] && return 0
    if grep -q "/${FW_AGENT_SLICE}/" "${FW_AGENT_SCOPE_CGROUP_FILE:-/proc/self/cgroup}" 2>/dev/null; then
        return 0
    fi
    command -v timeout >/dev/null 2>&1 && probe=(timeout 10)
    if ! command -v systemd-run >/dev/null 2>&1; then
        reason="systemd-run not found"
    elif [ ! -d "${FW_AGENT_SCOPE_SYSTEMD_DIR:-/run/systemd/system}" ]; then
        reason="systemd is not the init system"
    elif ! "${probe[@]}" systemd-run --scope --quiet --collect --no-ask-password \
            --slice="$FW_AGENT_SLICE" -- true >/dev/null 2>&1; then
        reason="systemd-run --scope refused (no permission for a system scope?)"
    fi
    if [ -n "$reason" ]; then
        _fw_agent_scope_fallback "$label" "$reason"
        return 0
    fi
    FW_AGENT_SCOPE_CMD=(systemd-run --scope --quiet --collect --no-ask-password
        --slice="$FW_AGENT_SLICE" --description="AEF ${label} (T-4636)" --)
}

# _fw_agent_scope_fallback <label> <reason> — warn once per reason, log every first sighting.
_fw_agent_scope_fallback() {
    local label="$1" reason="$2" root="${PROJECT_ROOT:-$PWD}" log=""
    [ -d "$root/.context/working" ] && log="$root/.context/working/agent-scope.log"
    if [ -n "$log" ] && grep -qF "reason=$reason" "$log" 2>/dev/null; then
        return 0
    fi
    echo "fw: WARNING: $label runs without its own systemd scope ($reason); a login-session teardown can kill it. Host fix: loginctl enable-linger $(id -un 2>/dev/null || echo "\$USER") (T-4636)${log:+ — logged once to $log}" >&2
    [ -n "$log" ] && echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) fallback label=$label reason=$reason" >> "$log" 2>/dev/null
    return 0
}
