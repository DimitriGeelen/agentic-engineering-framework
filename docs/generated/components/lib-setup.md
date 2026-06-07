# setup

> fw setup - Guided onboarding wizard for new projects

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/setup.sh`

## What It Does

fw setup - Guided onboarding wizard for new projects
A 6-step breadcrumb flow that wraps fw init with guided configuration.
Each step is idempotent (sentinel-checked) and safe to re-run.
Steps:
1. Project Identity    — name, description, owner
2. Provider Selection  — claude, cursor, generic
3. Tech Stack          — languages, test framework, conventions
4. Enforcement Level   — strict, standard, advisory
5. First Task          — optional initial task creation
6. Verification        — fw doctor + cheat sheet

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [init](/docs/generated/lib-init) | calls | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [git](/docs/generated/agents-git-git) | calls | Git Agent - Structural Enforcement for Git Operations |
| [context-dispatcher](/docs/generated/context-dispatcher) | calls | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [create-task](/docs/generated/agents-task-create-create-task) | calls | Task Creation Agent - Mechanical Operations |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [lib_setup](/docs/generated/tests-unit-lib_setup) | called-by | Unit tests for setup (2 tests) |
| [lib_setup](/docs/generated/tests-unit-lib_setup) | called_by | Unit tests for setup (2 tests) |
| [lib_setup](/docs/generated/tests-unit-lib_setup) | tests_by | Unit tests for setup (2 tests) |

## Related

### Tasks
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-setup.yaml`*
*Last verified: 2026-02-20*
