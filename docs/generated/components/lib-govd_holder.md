# govd_holder

> govd_holder — the privileged state-holder daemon `aef-govd` (arc-013 / T-2430).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/govd_holder.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [govd_envelope](/docs/generated/lib-govd_envelope) | calls | govd_envelope — the authority-broker decision evaluator (arc-013 / T-2430). |
| [govd](/docs/generated/agents-govd-govd) | calls | Privileged state-holder agent (arc-013/T-2430). Agent-safe subcommands emit specs and evaluate who-commits decisions with no side effects (evaluate/propose/emit-install). The cage/daemon INSTALL (aef-gov uid, RO bind-mounts, systemd unit) is Lock-1 human/root — never run by the agent. |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [govd_relay](/docs/generated/lib-govd_relay) | called_by | govd_relay — the governance mediation relay / proxy brain (arc-013 / T-2431). |
| [govd](/docs/generated/agents-govd-govd) | called_by | Privileged state-holder agent (arc-013/T-2430). Agent-safe subcommands emit specs and evaluate who-commits decisions with no side effects (evaluate/propose/emit-install). The cage/daemon INSTALL (aef-gov uid, RO bind-mounts, systemd unit) is Lock-1 human/root — never run by the agent. |
| [govd_relay](/docs/generated/lib-govd_relay) | uses_by | govd_relay — the governance mediation relay / proxy brain (arc-013 / T-2431). |

---
*Auto-generated from Component Fabric. Card: `lib-govd_holder.yaml`*
*Last verified: 2026-06-20*
