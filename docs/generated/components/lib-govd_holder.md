# govd_holder

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/govd_holder.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [govd_envelope](/docs/generated/lib-govd_envelope) | calls | TODO: describe what this component does |
| [govd](/docs/generated/agents-govd-govd) | calls | Privileged state-holder agent (arc-013/T-2430). Agent-safe subcommands emit specs and evaluate who-commits decisions with no side effects (evaluate/propose/emit-install). The cage/daemon INSTALL (aef-gov uid, RO bind-mounts, systemd unit) is Lock-1 human/root — never run by the agent. |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [govd_relay](/docs/generated/lib-govd_relay) | called_by | TODO: describe what this component does |
| [govd](/docs/generated/agents-govd-govd) | called_by | Privileged state-holder agent (arc-013/T-2430). Agent-safe subcommands emit specs and evaluate who-commits decisions with no side effects (evaluate/propose/emit-install). The cage/daemon INSTALL (aef-gov uid, RO bind-mounts, systemd unit) is Lock-1 human/root — never run by the agent. |
| [govd_relay](/docs/generated/lib-govd_relay) | uses_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-govd_holder.yaml`*
*Last verified: 2026-06-20*
