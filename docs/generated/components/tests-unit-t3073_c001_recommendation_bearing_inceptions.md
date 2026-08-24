# t3073_c001_recommendation_bearing_inceptions

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3073_c001_recommendation_bearing_inceptions.bats`

## What It Does

T-3073: C-001 research-artefact rail covers inceptions being DECIDED, not only
inceptions being WORKED.
Before this task the set was `workflow_type == "inception" and status ==
"started-work"`. An inception carrying a substantive `## Recommendation` has
finished researching — it is asking the operator for a go/no-go — and nothing
forces a status change to file one, so five of the six pending decisions
measured on 2026-08-18 sat at `status: captured`, invisible to the rail built
to catch exactly them.
Every assertion here is two-sided (A3, L-616): a known-missing fixture IS
reported AND a known-satisfied fixture is NOT. Two empty sets are equal, so a

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [active-task-scan](/docs/generated/agents-audit-active-task-scan) | calls | Single-pass scan of active task files that checks compliance, quality, research artifacts, ownership, and review queue status in one efficient pass |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [active-task-scan](/docs/generated/agents-audit-active-task-scan) | tests | Single-pass scan of active task files that checks compliance, quality, research artifacts, ownership, and review queue status in one efficient pass |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3073_c001_recommendation_bearing_inceptions.yaml`*
*Last verified: 2026-08-18*
