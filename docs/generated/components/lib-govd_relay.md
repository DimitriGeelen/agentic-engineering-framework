# govd_relay

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/govd_relay.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [govd_holder](/docs/generated/lib-govd_holder) | calls | TODO: describe what this component does |
| [govd_holder](/docs/generated/lib-govd_holder) | uses | TODO: describe what this component does |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [govd_policy](/docs/generated/lib-govd_policy) | called_by | TODO: describe what this component does |
| [govd](/docs/generated/agents-govd-govd) | called_by | Privileged state-holder agent (arc-013/T-2430). Agent-safe subcommands emit specs and evaluate who-commits decisions with no side effects (evaluate/propose/emit-install). The cage/daemon INSTALL (aef-gov uid, RO bind-mounts, systemd unit) is Lock-1 human/root — never run by the agent. |

---
*Auto-generated from Component Fabric. Card: `lib-govd_relay.yaml`*
*Last verified: 2026-06-20*
