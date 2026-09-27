# govd_relay

> govd_relay — the governance mediation relay / proxy brain (arc-013 / T-2431).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/govd_relay.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [govd_holder](/docs/generated/lib-govd_holder) | calls | govd_holder — the privileged state-holder daemon `aef-govd` (arc-013 / T-2430). |
| [govd_holder](/docs/generated/lib-govd_holder) | uses | govd_holder — the privileged state-holder daemon `aef-govd` (arc-013 / T-2430). |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [govd_policy](/docs/generated/lib-govd_policy) | called_by | govd_policy — proxy-policy emit / install / drift (arc-013 / T-2432, design §4c). |
| [govd](/docs/generated/agents-govd-govd) | called_by | Privileged state-holder agent (arc-013/T-2430). Agent-safe subcommands emit specs and evaluate who-commits decisions with no side effects (evaluate/propose/emit-install). The cage/daemon INSTALL (aef-gov uid, RO bind-mounts, systemd unit) is Lock-1 human/root — never run by the agent. |

---
*Auto-generated from Component Fabric. Card: `lib-govd_relay.yaml`*
*Last verified: 2026-06-20*
