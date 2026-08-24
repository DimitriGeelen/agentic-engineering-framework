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

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [rail-identity](/docs/generated/lib-rail-identity) | tests | TODO: describe what this component does |
| [config](/docs/generated/lib-config) | tests | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [rail-identity](/docs/generated/lib-rail-identity) | calls | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-rail_identity_guard.yaml`*
*Last verified: 2026-08-09*
