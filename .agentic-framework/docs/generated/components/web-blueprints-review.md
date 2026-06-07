# review

> Watchtower review blueprint: task review page — shows ACs, research artifacts, recommendation, approval actions.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/review.py`

## What It Does

T-1810: paused-dispatch helpers live in lib/ (CLI parity with `fw pause list`).

### Framework Reference

When agent ACs are complete and human ACs remain:

1. **Write your recommendation into the task file** — Add a `## Recommendation` section (Watchtower reads this) with:
   - **Recommendation:** GO / NO-GO / DEFER
   - **Rationale:** Why (cite evidence: what was fixed, what was proven, what remains)
   - **Evidence:** Bullet list of concrete proof (test results, file paths, metrics)
   You are the advisory. The human is the decision-maker. Never present a blank decision for them to fill in — always tell them what you recommend and why.

*(truncated — see CLAUDE.md for full section)*

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |
| [tasks](/docs/generated/web-blueprints-tasks) | registers | Flask blueprint: Tasks |
| [inception](/docs/generated/web-blueprints-inception) | calls | Blueprint 'inception' — routes: /inception |
| [inception](/docs/generated/web-blueprints-inception) | registers | Blueprint 'inception' — routes: /inception |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [_review_error](/docs/generated/web-templates-_review_error) | used-by | htmx partial: review error message — displayed when task review action fails (task not found, validation error). |
| [_review_error](/docs/generated/web-templates-_review_error) | used-by_by | htmx partial: review error message — displayed when task review action fails (task not found, validation error). |
| [test_review_acs](/docs/generated/tests-playwright-test_review_acs) | called_by | Playwright tests for /review/<task_id>/acs fragment endpoint (T-1026). |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-review.yaml`*
*Last verified: 2026-03-28*
