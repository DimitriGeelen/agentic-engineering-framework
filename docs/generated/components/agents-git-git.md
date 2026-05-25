# git

> Git Agent - Structural Enforcement for Git Operations

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/git.sh`

## What It Does

Git Agent - Structural Enforcement for Git Operations
Ensures every commit connects to a task (T-XXX pattern)

## Dependencies (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [common](/docs/generated/agents-git-lib-common) | calls | Common utilities for git agent |
| [commit](/docs/generated/agents-git-lib-commit) | calls | Git Agent - Commit subcommand |
| [status](/docs/generated/agents-git-lib-status) | calls | Git Agent - Status subcommand |
| [hooks](/docs/generated/agents-git-lib-hooks) | calls | Git Agent - Hook installation subcommand |
| [bypass](/docs/generated/agents-git-lib-bypass) | calls | Git Agent - Bypass logging subcommand |
| [log](/docs/generated/agents-git-lib-log) | calls | Git Agent - Log subcommand |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

## Used By (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [handover](/docs/generated/agents-handover-handover) | called_by | Handover Agent - Mechanical Operations |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [init](/docs/generated/lib-init) | called_by | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [setup](/docs/generated/lib-setup) | called_by | fw setup - Guided onboarding wizard for new projects |
| [upgrade](/docs/generated/lib-upgrade) | called_by | fw upgrade - Sync framework improvements to a consumer project |
| [git_log](/docs/generated/tests-unit-git_log) | called-by | Unit tests for git log (14 tests) |
| [git_common](/docs/generated/tests-unit-git_common) | called-by | Unit tests for git common (10 tests) |
| [git_common](/docs/generated/tests-unit-git_common) | called_by | Unit tests for git common (10 tests) |
| [git_log](/docs/generated/tests-unit-git_log) | called_by | Unit tests for git log (14 tests) |

## Documentation

- [Deep Dive: The Task Gate](docs/articles/deep-dives/01-task-gate.md) (deep-dive)
- [Deep Dive: The Authority Model](docs/articles/deep-dives/06-authority-model.md) (deep-dive)

---
*Auto-generated from Component Fabric. Card: `agents-git-git.yaml`*
*Last verified: 2026-02-20*
