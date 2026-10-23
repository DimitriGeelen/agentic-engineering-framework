# watchtower-ensure

> T-3877: make sure this project's Watchtower runs once a session starts.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/watchtower-ensure.sh`

## What It Does

T-3877: make sure this project's Watchtower runs once a session starts.
Nothing started Watchtower after a reboot: on 2026-10-05 AEF's stayed down
until started by hand and 055's for ~80 minutes, and every link handed out
was dead. post-compact-resume.sh (SessionStart: startup, resume, compact)
calls this DETACHED, so a session start never waits on it.
The port is NOT chosen here: `bin/watchtower.sh start` applies T-3876's
choose_port (explicit > configured PORT > last port > allocate, moves
announced). Reference: 055's vendored T-467 patch.
fw_watchtower_ensure — always returns 0. Running → no-op. Otherwise one
start under a flock (several sessions start together after a reboot).

---
*Auto-generated from Component Fabric. Card: `lib-watchtower-ensure.yaml`*
*Last verified: 2026-10-05*
