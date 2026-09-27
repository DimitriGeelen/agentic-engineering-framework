# recommendation_claims

> T-100187: Recommendation-claims validator (T-100186 GO slice A).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/reviewer/recommendation_claims.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [inception_decisions](/docs/generated/lib-inception_decisions) | calls | T-1984: inception_decisions / unlocks_inception_decision frontmatter parser. |
| [inception_decisions](/docs/generated/lib-inception_decisions) | uses | T-1984: inception_decisions / unlocks_inception_decision frontmatter parser. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_recommendation_claims](/docs/generated/tests-unit-test_recommendation_claims) | called_by | T-100187: Recommendation-claims validator (T-100186 GO slice A). |
| [shared](/docs/generated/web-shared) | called_by | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [static_scan](/docs/generated/lib-reviewer-static_scan) | called_by | Static-scan reviewer (T-1443 v1.0 → v1.5). |
| [static_scan](/docs/generated/lib-reviewer-static_scan) | uses_by | Static-scan reviewer (T-1443 v1.0 → v1.5). |
| [test_recommendation_claims](/docs/generated/tests-unit-test_recommendation_claims) | uses_by | T-100187: Recommendation-claims validator (T-100186 GO slice A). |

---
*Auto-generated from Component Fabric. Card: `lib-reviewer-recommendation_claims.yaml`*
*Last verified: 2026-07-04*
