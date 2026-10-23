# t3779_termlink_runtime

> T-3779: TERMLINK_RUNTIME_DIR split-brain. A launcher running an agent under `env -i` drops the variable; `termlink register` then lands in /tmp/termlink-$UID where no hub listens (2026-10-05: 27 fleet sessions, AEF's included).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3779_termlink_runtime.bats`

## What It Does

T-3779: TERMLINK_RUNTIME_DIR split-brain. A launcher running an agent under
`env -i` drops the variable; `termlink register` then lands in
/tmp/termlink-$UID where no hub listens (2026-10-05: 27 fleet sessions,
AEF's included). Fake hubs here are a real AF_UNIX socket plus a pidfile
naming a live ($$) or impossible pid.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3779_termlink_runtime.yaml`*
*Last verified: 2026-10-05*
