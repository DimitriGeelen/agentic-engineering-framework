# tier0_grant_ttl

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/tier0_grant_ttl.bats`

## What It Does

T-3080 — the Tier 0 grant TTL is one window, resolved once, for BOTH approval legs.
Before T-3080, check-tier0.sh carried two independent TTL literals: a bare `300`
on the `fw tier0 approve` leg and `${TIER0_WATCHTOWER_TTL:-3600}` on the
Watchtower leg. The path that takes one CLICK pre-authorised a destructive
command for 12x as long as the path that takes a TYPED command — and a misclick
is the easier mistake to make, so it must carry the SHORTER window. Unified at
the tight leg: 300s, one resolution point, `TIER0_APPROVAL_TTL` in the registry.
What a grant actually is, and why the window matters: approving does not run the
command. It writes the command's hash into a grant record, and this hook then
admits ANY command whose whitespace-normalised text hashes to that value, once.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-tier0_grant_ttl.yaml`*
*Last verified: 2026-08-19*
