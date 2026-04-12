# T-1135 — Persistent TermLink Agent Sessions

## The Problem

Two contradictory patterns:
1. **Cleanup cron** (T-866) kills stale sessions to prevent zombies
2. **Persistent agents** need to survive indefinitely as always-on listeners

Today's evidence: S-2026-0412 communicated with ring20-manager via inject —
immediate responses, files resent in seconds. But only because ring20-manager
had an active session. No active session = nobody home.

## The Vision

Every project has a **persistent TermLink agent session** ("receptionist"):
- Always listening for cross-agent inject messages
- Survives cleanup crons (tagged `persistent:true` or registered)
- Health-checked on `/resume` and respawned if down
- Acts as domain specialist (knows the project, can answer questions)
- Part of a **networked agent ecosystem** where projects share expertise

## Design Questions

1. **Session identity:** What naming convention? `<project>-receptionist`? `<machine>-<project>-agent`?
2. **Cleanup exemption:** Tag-based (`persistent:true`) or config-based (registered in .framework.yaml)?
3. **Cost model:** How much does an idle claude -p session cost? Can we use a cheaper model for the receptionist?
4. **Resume integration:** Check in `/resume` flow? `fw doctor`? Both?
5. **Registration format:** .framework.yaml field? Separate .termlink-agent.yaml?
6. **Cross-machine discovery:** How do agents find each other's receptionists?

## Cross-Agent Coordination Results

Coordinated with TermLink project agent (/opt/termlink) via TermLink dispatch.
Full response: `/opt/termlink/docs/reports/T-967-persistent-sessions-response.md`

### TermLink Project Findings (T-967)

**Cleanup is PID-based, not cron-based:**
- Hub supervisor sweep (every 30s) — checks `kill(pid, 0)` + socket exists
- Remote store TTL reaper (every 30s) — expires TCP sessions after 5min
- `termlink clean` CLI — same PID check, on-demand
- NO external cron jobs for cleanup

**Tags infrastructure is 90% ready:**
- `Registration` struct has `tags: Vec<String>`, `roles: Vec<String>`
- CLI already supports `--tags persistent` on registration
- Discovery already supports `--tag persistent` filtering
- **Missing:** cleanup code doesn't check tags before killing

**Fix is small (3 code changes in TermLink):**
1. `supervisor.rs` sweep — check `persistent` tag, emit `session.needs_restart` instead
2. `manager.rs` clean_stale — skip `persistent` tagged sessions
3. `remote_store.rs` reaper — skip persistent TTL

**Counter-proposals from TermLink:**
- Use existing `tags` mechanism, not a new flag (composable, no schema change)
- Emit `session.needs_restart` event for dead persistent sessions (observable)
- Grace period (5min) instead of permanent exemption
- Remote TTL override (30min vs 5min)

**Naming convention agreed:**
```
fw-agent              # Framework receptionist
termlink-agent        # TermLink receptionist
{project-name}-agent  # Consumer project receptionist
```
Tags: `persistent,receptionist`. Roles: `agent`.

**Cost model confirmed:**
- TermLink tracking cost: ~2KB disk + 1 FD per session (negligible)
- Real cost: the process inside (Claude Code ~150MB RSS)
- 3-5 projects × 150MB = <1GB — manageable on dev machine

### Related TermLink Tasks
- T-967: Persistent agent sessions (inception, captured)
- T-937: Cleanup kills active dispatch workers (same root cause)
- T-941: Service templates for persistent sessions
- T-959: Two-pool architecture (persistent /var/lib + ephemeral /tmp)

## Design Consensus

Based on coordination:

1. **Registration:** `termlink register --name "fw-agent" --tags persistent,receptionist --roles agent`
2. **Cleanup exemption:** Tag-based (`persistent` tag) — TermLink builds the check
3. **Restart signal:** `session.needs_restart` event when persistent session PID dies
4. **Framework integration:**
   - `/resume` flow: check for project's persistent agent, respawn if dead
   - `fw doctor`: report persistent agent health
   - `.framework.yaml`: optional `persistent_session` config block
5. **Consumer projects:** each runs own `{project}-agent`, discovered via hub
