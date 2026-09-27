# anti-patterns

> Anti-pattern catalogue for the reviewer agent (T-1443): per-pattern detection_confidence and lie_severity axes (L-261) consumed by the static-scan reviewer and the Layer-3 audit re-scan.

**Type:** config | **Subsystem:** governance | **Location:** `policy/anti-patterns.yaml`

**Tags:** `policy`, `reviewer`, `T-1443`

## What It Does

Anti-pattern catalogue for the reviewer agent (T-1443 v1.0)
Severity is split into two axes per L-261 (severity-axis conflation):
detection_confidence  — how reliably we can detect the pattern
values: deterministic | heuristic | semantic
lie_severity          — if the pattern fires, how badly does the evidence lie
values: complete | severe | partial | narrow | staleness
Action urgency / risk / blast-radius are extrinsic (task-level) and
combined via policy/action-matrix.yaml in later versions (v1.2+).
v1.0 scope: 4 seed patterns. v3+ expands to 12 categories via mining
external test-smell literature, internal corpus, and peer-agent dispatch.

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [static_scan](/docs/generated/lib-reviewer-static_scan) | reads | Static-scan reviewer (T-1443 v1.0 → v1.5). |
| [audit](/docs/generated/lib-reviewer-audit) | reads | Layer 3 audit cron (T-1443 v1.2, T-1484 v1.5b). |
| [verify-acs](/docs/generated/lib-verify-acs) | reads | Scans work-completed tasks with unchecked Human ACs and runs automated evidence collection where programmatic verification is possible |
| [review_link_validator](/docs/generated/lib-review_link_validator) | reads | Validate Watchtower review/inception handoff links at the moment of handoff. |
| [update-task](/docs/generated/agents-task-create-update-task) | reads | Task Update Agent - Status transitions with auto-triggers |
| [upgrade](/docs/generated/lib-upgrade) | writes | fw upgrade - Sync framework improvements to a consumer project |

---
*Auto-generated from Component Fabric. Card: `policy-anti-patterns.yaml`*
*Last verified: 2026-09-08*
