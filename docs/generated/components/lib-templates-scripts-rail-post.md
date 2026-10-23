# rail-post

> T-2913 — shared rail producer for the messaging-toolkit scripts.

**Type:** script | **Subsystem:** termlink-integration | **Location:** `lib/templates/scripts/rail-post.sh`

## What It Does

T-2913 — shared rail producer for the messaging-toolkit scripts.
Sourced (not executed) by agent-send.sh, agent-respond.sh,
chat-arc-broadcast.sh and listener-heartbeat.sh so every `channel post`
they make goes through the framework's lib/rail-identity.sh: the project's
signing identity (RAIL_IDENTITY_FILE) and the canonical from_project label
(T-2904, T-2905). Before this, all four called `termlink channel post`
bare — host-signed, unlabeled — whatever `fw rail post` would have done.
Usage:  rail_post <channel-post-args...>     (uses $TERMLINK, else termlink)
These scripts are copied into consumer projects' scripts/ by fw upgrade, so
the framework lib is located, not assumed:

---
*Auto-generated from Component Fabric. Card: `lib-templates-scripts-rail-post.yaml`*
*Last verified: 2026-10-20*
