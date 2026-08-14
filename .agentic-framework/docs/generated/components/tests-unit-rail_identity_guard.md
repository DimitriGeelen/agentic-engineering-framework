# rail_identity_guard

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/rail_identity_guard.bats`

## What It Does

T-2904: outbound rail posts must not be signed by the shared host key.
On a host whose termlink identity is shared across sessions, every co-resident
agent signs identically — so a peer gating on producer identity cannot attribute
a post to a project. Measured live: the same rail carried our posts under two
different producers depending on which code path sent them.
WHAT THESE LEGS DELIBERATELY DO NOT DO: post to a hub. The guard is ours; the
signing is termlink's. Legs that posted would be testing termlink over the
network and would write to a shared hub from CI.
The load-bearing legs are (f) and (g). (a)-(e) all pass trivially if identity
resolution is broken — (f) proves the host fingerprint actually resolves, and

---
*Auto-generated from Component Fabric. Card: `tests-unit-rail_identity_guard.yaml`*
*Last verified: 2026-08-09*
