# t3255-livefire-agent

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/t3255-livefire-agent.sh`

## What It Does

T-3255 — live-fire with a REAL Claude agent (the AC5 claim T-3254 did not prove).
WHAT T-3254 ACTUALLY PROVED, AND WHY IT WAS NOT ENOUGH. Its live-fire drove a real
TermLink PTY session through the real driver, but the "work" was a shell script
that consumed one backlog line per turn. That covers the transport and every
bound; it does NOT cover the claim the AC makes, which is that an AGENT that has
stopped early gets driven to completion. A shell script does not stop early — it
has no notion of a turn — so the single most important property was assumed.
Here the session IS a Claude agent. It reads a backlog, does ONE item, ticks it,
and ends its turn — which is a genuine early stop with work remaining and no
budget event anywhere near it. That is precisely the `exit no-signal` case M2

---
*Auto-generated from Component Fabric. Card: `tools-t3255-livefire-agent.yaml`*
*Last verified: 2026-09-03*
