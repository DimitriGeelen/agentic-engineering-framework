# approvals

> Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/approvals.py`

## What It Does

T-1808: paused-dispatch surface — needs lib/ on the path so the helper imports cleanly.
T-2645 (832 G-004 sibling): lib/ is FRAMEWORK-owned — PROJECT_ROOT resolution broke
split-root consumers (masked here by the try/except fallback, feature silently dead).

## Dependencies (17)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [inception](/docs/generated/web-blueprints-inception) | calls | Blueprint 'inception' — routes: /inception |
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |
| [approvals](/docs/generated/web-templates-approvals) | renders | Full page template: approvals queue — wrapper around _approvals_content partial with nav, filters, bulk actions. |
| [inception](/docs/generated/web-blueprints-inception) | registers | Blueprint 'inception' — routes: /inception |
| [tasks](/docs/generated/web-blueprints-tasks) | registers | Flask blueprint: Tasks |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [arcs](/docs/generated/web-blueprints-arcs) | calls | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [arcs](/docs/generated/web-blueprints-arcs) | registers | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [bvp](/docs/generated/web-blueprints-bvp) | calls | TODO: describe what this component does |
| [bvp](/docs/generated/web-blueprints-bvp) | registers | TODO: describe what this component does |
| [check-tier0](/docs/generated/agents-context-check-tier0) | calls | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [inception](/docs/generated/web-blueprints-inception) | uses | Blueprint 'inception' — routes: /inception |
| [tasks](/docs/generated/web-blueprints-tasks) | uses | Flask blueprint: Tasks |
| [arcs](/docs/generated/web-blueprints-arcs) | uses | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [bvp](/docs/generated/web-blueprints-bvp) | uses | TODO: describe what this component does |

## Used By (19)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [core](/docs/generated/web-blueprints-core) | called_by | Flask blueprint: Core |
| [core](/docs/generated/web-blueprints-core) | registered_by | Flask blueprint: Core |
| [test_inception](/docs/generated/tests-playwright-test_inception) | called_by | Playwright tests for Inception pages (T-970) |
| [test_inception](/docs/generated/tests-playwright-test_inception) | registered_by | Playwright tests for Inception pages (T-970) |
| [test_api_approvals](/docs/generated/tests-playwright-test_api_approvals) | called_by | Playwright tests for approvals API endpoints (T-1031). |
| [shared](/docs/generated/web-shared) | called_by | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [approvals_close_ready_arcs](/docs/generated/tests-unit-approvals_close_ready_arcs) | tests_by | TODO: describe what this component does |
| [test_inception](/docs/generated/tests-playwright-test_inception) | uses_by | Playwright tests for Inception pages (T-970) |
| [test_approvals_blocked_arcs](/docs/generated/tests-web-test_approvals_blocked_arcs) | called_by | TODO: describe what this component does |
| [test_approvals_blocked_arcs](/docs/generated/tests-web-test_approvals_blocked_arcs) | registered_by | TODO: describe what this component does |
| [test_approvals_blocked_arcs](/docs/generated/tests-web-test_approvals_blocked_arcs) | uses_by | TODO: describe what this component does |
| [test_approvals_origin](/docs/generated/tests-web-test_approvals_origin) | called_by | TODO: describe what this component does |
| [test_approvals_origin](/docs/generated/tests-web-test_approvals_origin) | registered_by | TODO: describe what this component does |
| [test_approvals_origin](/docs/generated/tests-web-test_approvals_origin) | uses_by | TODO: describe what this component does |
| [__init__](/docs/generated/web-blueprints-__init__) | uses_by | Flask blueprint:   Init |
| [core](/docs/generated/web-blueprints-core) | uses_by | Flask blueprint: Core |

## Related

### Tasks
- T-846: Watchtower /approvals — add 'Complete All Ready' batch action for tasks with all ACs checked
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements

---
*Auto-generated from Component Fabric. Card: `web-blueprints-approvals.yaml`*
*Last verified: 2026-03-27*
