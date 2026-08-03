# govd

> Privileged state-holder agent (arc-013/T-2430). Agent-safe subcommands emit specs and evaluate who-commits decisions with no side effects (evaluate/propose/emit-install). The cage/daemon INSTALL (aef-gov uid, RO bind-mounts, systemd unit) is Lock-1 human/root — never run by the agent.

**Type:** script | **Subsystem:** framework-core | **Location:** `agents/govd/govd.sh`

**Tags:** `arc-013`, `governance`, `payload-mediation`

## What It Does

govd — privileged state-holder agent (arc-013 / T-2430).
AGENT-SAFE subcommands only emit specs and evaluate decisions. The INSTALL of the
cage/daemon (create the aef-gov uid, RO bind-mount the envelope+state, enable the
systemd unit) is Lock-1 Part 1 — human/root, NEVER run by the agent. `emit-install`
prints the artifacts; it does not execute them.
Usage:
govd.sh evaluate '<decision-json>'     # who-commits verdict (no side effects)
govd.sh propose  '<request-json>'      # one-shot propose as current uid
govd.sh emit-install [--out DIR]       # emit systemd unit + root setup (NOT run)

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [govd_envelope](/docs/generated/lib-govd_envelope) | calls | TODO: describe what this component does |
| [govd_holder](/docs/generated/lib-govd_holder) | calls | TODO: describe what this component does |
| [govd_relay](/docs/generated/lib-govd_relay) | calls | TODO: describe what this component does |
| `policy/authority-envelope.yaml` | reads | — |
| `policy/proxy-policy.yaml` | reads | — |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [govd_holder](/docs/generated/lib-govd_holder) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-govd-govd.yaml`*
*Last verified: 2026-06-20*
