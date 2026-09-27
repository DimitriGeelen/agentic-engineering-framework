# sandbox-profile

> sandbox-profile.yaml — the OS cage's SOURCE (arc-013 / T-2433, design §7a).

**Type:** config | **Subsystem:** governance | **Location:** `policy/sandbox-profile.yaml`

## What It Does

sandbox-profile.yaml — the OS cage's SOURCE (arc-013 / T-2433, design §7a).
Sovereign-authored, agent-reviewable. `fw sandbox emit-profile` derives the
tier-independent STATIC FLOOR from this file plus the repo layout:
- a systemd unit    (uid demotion S5 + RO substrate S4)   → policy/sandbox-profile.d/aef-agent.service
- an nftables ruleset (egress pinned to the proxy S3)     → policy/sandbox-profile.d/aef-agent-egress.nft
- the resolved manifest (absolute paths, uid, egress)      → policy/sandbox-profile.d/sandbox-profile.resolved.yaml
`sudo fw sandbox install` deploys them (human/root only, Lock-1 Part 1 — refuses
under the agent). `fw sandbox status` reports two drift classes: source edited but
not re-emitted (stale), and emitted but not installed (drift).
This is the FLOOR only. The active per-operation mediation tier (microVM +

---
*Auto-generated from Component Fabric. Card: `policy-sandbox-profile.yaml`*
*Last verified: 2026-09-20*
