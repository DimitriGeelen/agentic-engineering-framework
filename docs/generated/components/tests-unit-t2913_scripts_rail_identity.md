# t2913_scripts_rail_identity

> T-2913 — in-repo scripts that post to a rail must carry the project's rail signing identity and the canonical from_project label, like `fw rail post`.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t2913_scripts_rail_identity.bats`

## What It Does

T-2913 — in-repo scripts that post to a rail must carry the project's rail
signing identity and the canonical from_project label, like `fw rail post`.
WHAT WAS WRONG. Six producers — the messaging-toolkit scripts agent-send,
agent-respond, chat-arc-broadcast, listener-heartbeat (lib/templates/scripts,
copied into consumers' scripts/) and the pickup/learning bridges
(lib/pickup-channel-bridge.sh, lib/publish-learning-to-bus.sh) — called
`termlink channel post` bare. No TERMLINK_IDENTITY_FILE (host-signed) and no
from_project label, i.e. none of T-2904 / T-2905.
HERMETIC. termlink is a stub that records each `channel post` argv plus the
TERMLINK_IDENTITY_FILE it was launched with; nothing reaches a hub. The

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2913_scripts_rail_identity.yaml`*
*Last verified: 2026-10-21*
