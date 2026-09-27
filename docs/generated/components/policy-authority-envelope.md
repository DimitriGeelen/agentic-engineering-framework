# authority-envelope

> Sovereign-authored authority envelope (arc-013/T-2430): the trust partition deciding which agent actions may be committed autonomously vs queued to the human. RO to the agent in a deployed cage — the agent commits within the envelope but cannot change it.

**Type:** config | **Subsystem:** governance | **Location:** `policy/authority-envelope.yaml`

**Tags:** `policy`, `sovereign-authored`, `arc-013`

## What It Does

Authority envelope — SOVEREIGN-AUTHORED. (arc-013 / T-2430, design doc §4e)
This file is the trust partition between "the agent may commit autonomously" and
"queue to the human". It is the dial the sovereign turns on observed judgment
(design §4e, Antifragile feedback loop).
INVARIANT: the agent commits WITHIN this envelope; the agent cannot CHANGE this
envelope. In a deployed cage this file lives in RO substrate (Lock-1 Part 1) —
the agent uid cannot write it. Editing it is a sovereign action.
Evaluation (lib/govd_envelope.py): effective rule = {**global, **overrides[type]}
(per-type keys win). A decision commits autonomously iff every bound is satisfied;
any breach, or a non-delegable type, routes to the human. Tier-0 and directive

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [govd_holder](/docs/generated/lib-govd_holder) | reads | govd_holder — the privileged state-holder daemon `aef-govd` (arc-013 / T-2430). |
| [govd](/docs/generated/agents-govd-govd) | reads | Privileged state-holder agent (arc-013/T-2430). Agent-safe subcommands emit specs and evaluate who-commits decisions with no side effects (evaluate/propose/emit-install). The cage/daemon INSTALL (aef-gov uid, RO bind-mounts, systemd unit) is Lock-1 human/root — never run by the agent. |
| [govd](/docs/generated/agents-govd-govd) | read_by | Privileged state-holder agent (arc-013/T-2430). Agent-safe subcommands emit specs and evaluate who-commits decisions with no side effects (evaluate/propose/emit-install). The cage/daemon INSTALL (aef-gov uid, RO bind-mounts, systemd unit) is Lock-1 human/root — never run by the agent. |

---
*Auto-generated from Component Fabric. Card: `policy-authority-envelope.yaml`*
*Last verified: 2026-09-08*
