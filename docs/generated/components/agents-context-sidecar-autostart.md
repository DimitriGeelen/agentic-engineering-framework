# sidecar-autostart

> sidecar-autostart.sh — SessionStart hook: every agent runs a sidecar (R14).

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/sidecar-autostart.sh`

## What It Does

sidecar-autostart.sh — SessionStart hook: every agent runs a sidecar (R14).
T-3685 (arc-011 S-LIVE). claude-fw starts the project's sidecar (receiver +
supervised watcher) for its own sessions; this covers every OTHER launch —
a plain `claude`, an IDE, a dispatched worker — so no agent session in a
framework project runs without one. It runs `fw sidecar ensure --autostart`
DETACHED and returns at once: a session start never waits on it.
--autostart: enabled → (re)start a dead or stale supervisor/receiver;
never started here → start it;
explicitly stopped (`fw sidecar stop`) → leave it stopped.
Skipped inside a review worker (its environment is the review brief only),

---
*Auto-generated from Component Fabric. Card: `agents-context-sidecar-autostart.yaml`*
*Last verified: 2026-10-03*
