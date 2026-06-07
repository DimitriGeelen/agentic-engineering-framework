# pickup-channel-bridge

> One-way bridge from shell pickup to T-1155 channel bus. Invoked by pickup_process_one (lib/pickup.sh) after an envelope moves to processed/. Mirrors the envelope to 'framework:pickup' topic so online bus subscribers observe pickups alongside shell consumers. Non-fatal (exits 0 on any error); capability-probing (prefers termlink channel post; falls back to event broadcast; silent no-op if neither present). T-1165/T-1214 GO Option B: federate, don't converge.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/pickup-channel-bridge.sh`

**Tags:** `pickup`, `channel-bus`, `termlink`, `federation`, `T-1165`, `T-1214`

## What It Does

pickup-channel-bridge.sh — one-way bridge from shell pickup to T-1155 channel bus.
Invoked by pickup_process_one (lib/pickup.sh) right after an envelope moves
to processed/. Mirrors the envelope to the `framework:pickup` topic so online
bus subscribers can observe pickups alongside existing shell consumers.
Design (per T-1165 / T-1214 GO Option B — federate, don't converge):
- Non-fatal: any error path exits 0 so shell pickup stays portable.
- Posts via `termlink channel post` (Tier-A, T-1160, with --ensure-topic
auto-heal where supported). The legacy `event.broadcast` fallback was
removed (T-1814) — it emitted a primitive being retired (T-1166) and was
the lone live emitter resetting the cut's clean-window gate. Silent no-op

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [pickup](/docs/generated/lib-pickup) | called_by | Cross-project pickup pipeline that validates, deduplicates, and processes incoming YAML envelopes into inception tasks |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [pickup](/docs/generated/lib-pickup) | invokes_at_process_one | Cross-project pickup pipeline that validates, deduplicates, and processes incoming YAML envelopes into inception tasks |

---
*Auto-generated from Component Fabric. Card: `lib-pickup-channel-bridge.yaml`*
*Last verified: 2026-04-24*
