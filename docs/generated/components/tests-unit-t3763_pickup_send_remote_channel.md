# t3763_pickup_send_remote_channel

> T-3763 — `fw pickup send --remote` must deliver through the one channel (fw sidecar send, T-3631 GO / T-3758), not the deprecated `termlink remote push`, and a failed delivery must not leave the envelope in the sender's own inbox, where…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3763_pickup_send_remote_channel.bats`

## What It Does

T-3763 — `fw pickup send --remote` must deliver through the one channel
(fw sidecar send, T-3631 GO / T-3758), not the deprecated `termlink remote
push`, and a failed delivery must not leave the envelope in the sender's own
inbox, where `fw pickup process` reads it as incoming.
Origin: 055 @135. The hub allowlist refuses remote push's
`mkdir -p /tmp/termlink-inbox`: nothing was delivered and the envelope stayed
in the sender's inbox.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3763_pickup_send_remote_channel.yaml`*
*Last verified: 2026-10-21*
