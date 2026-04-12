# review

> Full page template: task review — recommendation, evidence, AC list, approval/reject actions.

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/review.html`

## What It Does

### Framework Reference

When agent ACs are complete and human ACs remain:

1. **Write your recommendation into the task file** — Add a `## Recommendation` section (Watchtower reads this) with:
   - **Recommendation:** GO / NO-GO / DEFER
   - **Rationale:** Why (cite evidence: what was fixed, what was proven, what remains)
   - **Evidence:** Bullet list of concrete proof (test results, file paths, metrics)
   You are the advisory. The human is the decision-maker. Never present a blank decision for them to fill in — always tell them what you recommend and why.

*(truncated — see CLAUDE.md for full section)*

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `web/templates/_review_acs.html` | includes |

---
*Auto-generated from Component Fabric. Card: `web-templates-review.yaml`*
*Last verified: 2026-03-28*
