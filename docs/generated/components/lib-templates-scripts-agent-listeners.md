# agent-listeners

> Template skill script: single-hub agent-presence discovery reader consuming listener-heartbeat convention (T-1833)

**Type:** script | **Subsystem:** termlink-integration | **Location:** `lib/templates/scripts/agent-listeners.sh`

## What It Does

T-1833 — agent-presence discovery reader (T-1830 sub-build b).
Consumes the heartbeat convention from T-1832. Reads the most-recent
envelopes on agent-presence (configurable), dedupes to one entry per
agent_id (keeping the newest by ts), classifies LIVE/STALE/OFFLINE
using each envelope's own metadata.interval_secs, and emits per-listener
rows. This is the "who's listening right now?" verb — the piece that
was missing between healthy runtime (T-1829) and active conversations
(T-1830 adoption gap).
TTL convention (informational; from T-1832):
age = now - last_seen_ts

---
*Auto-generated from Component Fabric. Card: `lib-templates-scripts-agent-listeners.yaml`*
*Last verified: 2026-09-08*
