# t3051_exec_bit_gates

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3051_exec_bit_gates.bats`

## What It Does

T-3051 — repo-tracked helper scripts must not be gated on their exec bit.
git records only one permission bit, and it was recorded wrong for three
helpers. Every gate of the form `[ -x "$helper" ]` therefore evaluated false
on any install derived from a clone, and because all three call sites are
deliberately non-fatal, a skipped helper is indistinguishable from a
successful one. That is why this went two months unreported.
The behavioural test below is written the only way that proves anything: the
exec bit is REMOVED and the helper must still run. Asserting it runs while the
bit is present passes against the broken code too.

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [pickup](/docs/generated/lib-pickup) | calls | Cross-project pickup pipeline that validates, deduplicates, and processes incoming YAML envelopes into inception tasks |
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [pickup](/docs/generated/lib-pickup) | tests | Cross-project pickup pipeline that validates, deduplicates, and processes incoming YAML envelopes into inception tasks |
| [pickup-channel-bridge](/docs/generated/lib-pickup-channel-bridge) | tests | One-way bridge from shell pickup to T-1155 channel bus. Invoked by pickup_process_one (lib/pickup.sh) after an envelope moves to processed/. Mirrors the envelope to 'framework:pickup' topic so online bus subscribers observe pickups alongside shell consumers. Non-fatal (exits 0 on any error); capability-probing (prefers termlink channel post; falls back to event broadcast; silent no-op if neither present). T-1165/T-1214 GO Option B: federate, don't converge. |
| [colors](/docs/generated/lib-colors) | tests | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [bvp-estimator](/docs/generated/agents-termlink-bvp-estimator-bvp-estimator) | tests | TODO: describe what this component does |
| [discard-manifest](/docs/generated/agents-handover-discard-manifest) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3051_exec_bit_gates.yaml`*
*Last verified: 2026-08-16*
