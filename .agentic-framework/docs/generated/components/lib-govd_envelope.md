# govd_envelope

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/govd_envelope.py`

## What It Does

Types that are NEVER delegable, regardless of what the envelope says — the hard
floor (design §4e). Even a mis-authored envelope cannot loosen these.

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [govd](/docs/generated/agents-govd-govd) | called_by | Privileged state-holder agent (arc-013/T-2430). Agent-safe subcommands emit specs and evaluate who-commits decisions with no side effects (evaluate/propose/emit-install). The cage/daemon INSTALL (aef-gov uid, RO bind-mounts, systemd unit) is Lock-1 human/root — never run by the agent. |
| [govd_holder](/docs/generated/lib-govd_holder) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-govd_envelope.yaml`*
*Last verified: 2026-06-20*
