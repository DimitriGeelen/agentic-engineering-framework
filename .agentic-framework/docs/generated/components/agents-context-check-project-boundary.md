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

| Target | Relationship |
|--------|-------------|
| `agents/context/check-tier0.sh` | related |
| `agents/context/check-active-task.sh` | related |
| `lib/paths.sh` | calls |
| `lib/config.sh` | calls |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `.claude/settings.json` | triggers |
| `tests/lint/no-bare-fw-in-gate-scripts.bats` | tests_by |
| `tests/unit/test_boundary_hook_arguments.bats` | called_by |
| `tests/unit/test_boundary_hook_arguments.bats` | tests_by |

## Related

### Tasks
- T-821: Hook crash distinguishability — trap handlers + stderr headers for crash vs block

---
*Auto-generated from Component Fabric. Card: `agents-context-check-project-boundary.yaml`*
*Last verified: 2026-03-28*
