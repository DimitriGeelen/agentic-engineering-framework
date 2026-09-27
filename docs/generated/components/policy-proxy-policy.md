# proxy-policy

> Sovereign-authored proxy mediation policy (arc-013/T-2431): the relay reads it to allow or deny each tool_use the model emits; invariants are hard denies. RO to the agent uid in a deployed cage (Lock-1 Part 1).

**Type:** config | **Subsystem:** governance | **Location:** `policy/proxy-policy.yaml`

**Tags:** `policy`, `sovereign-authored`, `arc-013`, `govd`

## What It Does

Proxy mediation policy — SOVEREIGN-AUTHORED (arc-013 / T-2431, design §4c).
The relay (lib/govd_relay.py) reads this to decide each tool_use the model emits:
allow (pass the turn through) or deny (substitute a coherent text refusal). In a
deployed cage this file is RO to the agent uid (Lock-1 Part 1) — the agent cannot
loosen its own governance. `invariants:` are hard denies the rest cannot override.
This is the proxy's CHOICE/mechanism governance (design §4b). It complements the
OS sandbox's EFFECT governance (T-2433) — defense in depth, no shared failure mode.

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [govd_relay](/docs/generated/lib-govd_relay) | reads | govd_relay — the governance mediation relay / proxy brain (arc-013 / T-2431). |
| [govd_policy](/docs/generated/lib-govd_policy) | reads | govd_policy — proxy-policy emit / install / drift (arc-013 / T-2432, design §4c). |
| [govd](/docs/generated/agents-govd-govd) | reads | Privileged state-holder agent (arc-013/T-2430). Agent-safe subcommands emit specs and evaluate who-commits decisions with no side effects (evaluate/propose/emit-install). The cage/daemon INSTALL (aef-gov uid, RO bind-mounts, systemd unit) is Lock-1 human/root — never run by the agent. |
| [govd](/docs/generated/agents-govd-govd) | read_by | Privileged state-holder agent (arc-013/T-2430). Agent-safe subcommands emit specs and evaluate who-commits decisions with no side effects (evaluate/propose/emit-install). The cage/daemon INSTALL (aef-gov uid, RO bind-mounts, systemd unit) is Lock-1 human/root — never run by the agent. |

---
*Auto-generated from Component Fabric. Card: `policy-proxy-policy.yaml`*
*Last verified: 2026-09-08*
