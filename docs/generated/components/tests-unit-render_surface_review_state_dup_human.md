# render_surface_review_state_dup_human

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/render_surface_review_state_dup_human.bats`

## What It Does

T-1901: render-surface gate's review-state detector reads ALL `### Human`
blocks, not just the first. Backward-compatible with single-header tasks.
Pre-fix bug: a task with `### Human` template-comment header + a second
`### Human` containing the actual [REVIEW] AC returned "empty" because
re.search captured only the first block's content. Hit on T-1898.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |

---
*Auto-generated from Component Fabric. Card: `tests-unit-render_surface_review_state_dup_human.yaml`*
*Last verified: 2026-07-22*
