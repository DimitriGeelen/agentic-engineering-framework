# inception_decisions

> T-1984: inception_decisions / unlocks_inception_decision frontmatter parser.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/inception_decisions.py`

## What It Does

── Regex helpers ─────────────────────────────────────────────────────────────

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [recommendation_claims](/docs/generated/lib-reviewer-recommendation_claims) | called_by | T-100187: Recommendation-claims validator (T-100186 GO slice A). |
| [recommendation_claims](/docs/generated/lib-reviewer-recommendation_claims) | uses_by | T-100187: Recommendation-claims validator (T-100186 GO slice A). |
| [check-inception-decisions](/docs/generated/agents-context-check-inception-decisions-py) | called_by | T-1984: inception_decisions task-frontmatter validation hook. |
| [check-inception-decisions](/docs/generated/agents-context-check-inception-decisions-py) | uses_by | T-1984: inception_decisions task-frontmatter validation hook. |

---
*Auto-generated from Component Fabric. Card: `lib-inception_decisions.yaml`*
*Last verified: 2026-05-22*
