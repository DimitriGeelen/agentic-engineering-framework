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

## Cross-Agent Coordination

Coordinating with ring20-manager (.109) who also has this inception assignment.

### Questions for ring20-manager

1. Do you have a stale session cleanup cron? How does it decide what's stale?
2. What session naming convention are you using for persistent sessions?
3. How do you envision the specialist network — each project as a domain expert?
4. What's your experience with persistent tmux sessions surviving reboots?
5. Have you prototyped a "receptionist" pattern already?
6. What task ID are you tracking this under on your side?

## Dialogue Log

(To be filled during cross-agent coordination via inject)
