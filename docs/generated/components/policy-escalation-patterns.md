# escalation-patterns

> Layer-1 escalation patterns for the reviewer agent (T-1443 v1.1): mechanical triggers that force a human-signoff recommendation for high-risk/destructive/external-impact tasks regardless of anti-pattern findings.

**Type:** config | **Subsystem:** governance | **Location:** `policy/escalation-patterns.yaml`

**Tags:** `policy`, `reviewer`, `T-1443`

## What It Does

Layer 1 escalation patterns (T-1443 v1.1)
Mechanical triggers — when ANY trigger matches, the reviewer recommends
human signoff regardless of anti-pattern findings. This is the "safety-net"
layer for high-risk / destructive / external-impact tasks.
Layer 2 (frontmatter `risk` / `human_signoff` declarations) overlays this
at task-creation time. Layer 3 (audit cron) re-checks at idle (v1.2+).
v1.1 ships the seed catalogue; v2.0+ adds learned triggers from the
feedback stream override events.
Schema:
triggers[]:

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [static_scan](/docs/generated/lib-reviewer-static_scan) | reads | Static-scan reviewer (T-1443 v1.0 → v1.5). |
| [audit](/docs/generated/lib-reviewer-audit) | reads | Layer 3 audit cron (T-1443 v1.2, T-1484 v1.5b). |
| [upgrade](/docs/generated/lib-upgrade) | writes | fw upgrade - Sync framework improvements to a consumer project |

---
*Auto-generated from Component Fabric. Card: `policy-escalation-patterns.yaml`*
*Last verified: 2026-09-08*
