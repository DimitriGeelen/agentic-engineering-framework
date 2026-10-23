# agent-scope

> lib/agent-scope.sh — T-4636 (T-4635 RCA, docs/reports/T-4635-session-kill-rca.md).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/agent-scope.sh`

## What It Does

lib/agent-scope.sh — T-4636 (T-4635 RCA, docs/reports/T-4635-session-kill-rca.md).
Long-lived agent processes (claude-fw, the tmux server it or `termlink spawn` starts, and
every dispatch worker inside that server) used to live in the cgroup of whoever launched
them: for root, a transient `session-*.scope` in `user-0.slice`. Root does not linger, cron
closes root's last session every minute, and under load systemd's stop of that slice times
out and SIGKILLs everything still in it — every session and worker at once.
fw_agent_scope_prefix <label> sets the array FW_AGENT_SCOPE_CMD to a `systemd-run --scope`
prefix that starts the command in its own transient scope under $FW_AGENT_SLICE
(agentic.slice), outside every login session. --scope keeps the command in the foreground
on the caller's terminal and environment, and systemd-run execs it, so the pid is kept.

---
*Auto-generated from Component Fabric. Card: `lib-agent-scope.yaml`*
*Last verified: 2026-10-22*
