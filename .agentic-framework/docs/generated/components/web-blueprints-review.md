# review

> Watchtower review blueprint: task review page — shows ACs, research artifacts, recommendation, approval actions.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/review.py`

## What It Does

### Framework Reference

When agent ACs are complete and human ACs remain:

1. **Write your recommendation into the task file** — Add a `## Recommendation` section (Watchtower reads this) with:
   - **Recommendation:** GO / NO-GO / DEFER
   - **Rationale:** Why (cite evidence: what was fixed, what was proven, what remains)
   - **Evidence:** Bullet list of concrete proof (test results, file paths, metrics)
   You are the advisory. The human is the decision-maker. Never present a blank decision for them to fill in — always tell them what you recommend and why.

*(truncated — see CLAUDE.md for full section)*

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/blueprints/tasks.py` | calls |
| `web/blueprints/tasks.py` | registers |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |
| `web/templates/_review_error.html` | used-by |
| `web/templates/_review_error.html` | used-by_by |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-review.yaml`*
*Last verified: 2026-03-28*
