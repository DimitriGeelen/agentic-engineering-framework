# drift_gate_not_shadowed_by_safelist

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/drift_gate_not_shadowed_by_safelist.bats`

## What It Does

T-2880 — the safe-list early return must not shadow the focus-drift gate.
check-active-task.sh answered two independent questions with one `exit 0`:
"does this need an active task?"   — about the SESSION state
"is it attributed to the right task?" — about the COMMAND
Safe-listing a verb answered the first and silently answered the second with
"don't care". T-2878 safe-listed `fw context add-*`, which IS drift pattern 2,
so that pattern became unreachable the moment the deadlock fix shipped — with
every existing test still green, because none of them asserted the gate was
still being CONSULTED (L-555: a check that stops being consulted looks exactly
like a check that found nothing).

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [check-active-task](/docs/generated/agents-context-check-active-task) | tests | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [paths](/docs/generated/lib-paths) | tests | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-drift_gate_not_shadowed_by_safelist.yaml`*
*Last verified: 2026-08-08*
