# inception

> Blueprint 'inception' — routes: /inception

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/inception.py`

## What It Does

Ensure blank line before lists so markdown parser recognizes them

### Framework Reference

When the active task has `workflow_type: inception`:
1. **State the phase** — Say "This is an inception/exploration task" before doing any work
2. **Present the filled template** for review before executing any spikes or prototypes
3. **Do not write build artifacts** (production code, full apps) before `fw inception decide T-XXX go`
4. **The commit-msg hook enforces this** — after 2 exploration commits, further commits are blocked until a decision is recorded
5. After a GO decision, **create separate build tasks** for implementation — do not continue building under the inception task ID
6. **R

*(truncated — see CLAUDE.md for full section)*

## Dependencies (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [inception](/docs/generated/web-templates-inception) | renders | Watchtower UI page: Inception |
| [inception_detail](/docs/generated/web-templates-inception_detail) | renders | Watchtower UI page: Inception Detail |
| [assumptions](/docs/generated/web-templates-assumptions) | renders | Watchtower UI page: Assumptions |
| [subprocess_utils](/docs/generated/web-subprocess_utils) | calls | Consistent subprocess execution for git and fw commands. Provides run_git_command() and run_fw_command() with standardized timeouts, encoding, and error handling. |
| [assumptions](/docs/generated/context-project-assumptions) | calls | Project assumption register. Tracks assumptions made during inception and build tasks, with validation status and evidence. |
| [inception](/docs/generated/lib-inception) | calls | fw inception - Inception phase workflow |

## Used By (10)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | registered_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [approvals](/docs/generated/web-blueprints-approvals) | called_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [approvals](/docs/generated/web-blueprints-approvals) | registered_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [review](/docs/generated/web-blueprints-review) | called_by | Watchtower review blueprint: task review page — shows ACs, research artifacts, recommendation, approval actions. |
| [review](/docs/generated/web-blueprints-review) | registered_by | Watchtower review blueprint: task review page — shows ACs, research artifacts, recommendation, approval actions. |
| [test_api_inception](/docs/generated/tests-playwright-test_api_inception) | called_by | Playwright tests for inception API endpoints (T-1031). |

## Related

### Tasks
- T-959: Batch inception review page in Watchtower — surface pending go/no-go decisions with summaries (T-954 Phase 3a)

---
*Auto-generated from Component Fabric. Card: `web-blueprints-inception.yaml`*
*Last verified: 2026-02-20*
