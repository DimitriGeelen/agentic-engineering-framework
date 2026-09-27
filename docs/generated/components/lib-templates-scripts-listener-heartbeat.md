# listener-heartbeat

> Template skill script: listener-heartbeat emitter establishing the agent-presence convention for doorbell+mail (T-1832)

**Type:** script | **Subsystem:** termlink-integration | **Location:** `lib/templates/scripts/listener-heartbeat.sh`

## What It Does

T-1832 — listener-heartbeat emitter (T-1830 sub-build a).
Establishes the agent-presence convention for the doorbell+mail
adoption push. Without presence signals there's nothing for the
discovery verb (T-1833) to read. Each listener posts a heartbeat
every --interval seconds declaring its agent_id, role, and the
topics it's actively listening on.
Convention (T-1830 GO):
- Topic:       agent-presence (per-hub; channels are hub-local — G-060)
- msg_type:    heartbeat
- payload:     role string (free-form, e.g. "listener", "responder")

---
*Auto-generated from Component Fabric. Card: `lib-templates-scripts-listener-heartbeat.yaml`*
*Last verified: 2026-09-08*
