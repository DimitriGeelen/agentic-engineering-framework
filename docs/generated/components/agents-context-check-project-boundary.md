# check-project-boundary

> PreToolUse hook that blocks Write/Edit/Bash operations targeting paths outside PROJECT_ROOT. Prevents cross-project edits. Part of the project boundary enforcement gate (T-559).

**Type:** script | **Subsystem:** hook-enforcement | **Location:** `agents/context/check-project-boundary.sh`

**Tags:** `hook`, `enforcement`, `tier0`, `boundary`

## What It Does

Project Boundary Enforcement Hook — PreToolUse gate for Write/Edit/Bash
Blocks file modifications and commands targeting paths outside PROJECT_ROOT.
Exit codes (Claude Code PreToolUse semantics):
0 — Allow tool execution
2 — Block tool execution (stderr shown to agent)
For Write/Edit: extracts file_path, blocks if outside PROJECT_ROOT.
For Bash: detects cd, write, fw-on-other-project, AND read-side outside-path
arguments (T-1702 / G-065 — read-blind hole closed 2026-05-03).
Allowed exceptions (Bash + Write):
/tmp/**                — Agent dispatch working files

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-tier0](/docs/generated/agents-context-check-tier0) | related | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [check-active-task](/docs/generated/agents-context-check-active-task) | related | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-config](/docs/generated/hook-config) | triggers | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [no-bare-fw-in-gate-scripts](/docs/generated/tests-lint-no-bare-fw-in-gate-scripts) | tests_by | TODO: describe what this component does |
| [test_boundary_hook_arguments](/docs/generated/tests-unit-test_boundary_hook_arguments) | called_by | TODO: describe what this component does |
| [test_boundary_hook_arguments](/docs/generated/tests-unit-test_boundary_hook_arguments) | tests_by | TODO: describe what this component does |

## Related

### Tasks
- T-821: Hook crash distinguishability — trap handlers + stderr headers for crash vs block

---
*Auto-generated from Component Fabric. Card: `agents-context-check-project-boundary.yaml`*
*Last verified: 2026-03-28*
