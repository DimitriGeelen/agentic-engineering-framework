# t3174_partial_complete_edit_matrix

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3174_partial_complete_edit_matrix.bats`

## What It Does

T-3174: partial-complete state revokes a task's authority to commit its own
closure artefacts — the residual scope T-3179 left open.
T-3179 solved ONE cell (partial-complete x git commit). This pins the full
matrix {partial-complete, archived} x {governance-path write, source write,
git commit}, plus the AC5 escape (FW_ALLOW_PARTIAL_COMPLETE_EDIT=1) for a
further EDIT (not a commit) on a partial-complete task -- the case where
`fw work-on <same-task>` cannot help because status-transitions.yaml has no
outgoing edge from work-completed.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | tests | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3174_partial_complete_edit_matrix.yaml`*
*Last verified: 2026-09-03*
