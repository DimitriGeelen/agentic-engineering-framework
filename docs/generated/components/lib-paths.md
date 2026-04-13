# paths

> Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/paths.sh`

**Tags:** `shell`, `paths`, `portability`, `core`

## What It Does

lib/paths.sh — Centralized path resolution for the Agentic Engineering Framework
Provides FRAMEWORK_ROOT, PROJECT_ROOT, and common directory variables.
Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern
duplicated across 25+ agent scripts.
Usage (from any agent script):
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/paths.sh"
Or if FRAMEWORK_ROOT is already known:
source "$FRAMEWORK_ROOT/lib/paths.sh"
After sourcing, these variables are set:
FRAMEWORK_ROOT — Absolute path to the framework repo root

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `lib/compat.sh` | calls |
| `lib/errors.sh` | calls |
| `lib/tasks.sh` | calls |
| `lib/yaml.sh` | calls |

## Used By (46)

| Component | Relationship |
|-----------|-------------|
| `agents/audit/audit.sh` | calls |
| `agents/context/context.sh` | calls |
| `agents/handover/handover.sh` | calls |
| `agents/git/git.sh` | calls |
| `agents/task-create/create-task.sh` | calls |
| `agents/task-create/update-task.sh` | calls |
| `agents/healing/healing.sh` | calls |
| `agents/fabric/fabric.sh` | calls |
| `agents/resume/resume.sh` | calls |
| `agents/context/checkpoint.sh` | calls |
| `agents/context/budget-gate.sh` | calls |
| `agents/context/check-active-task.sh` | calls |
| `agents/context/check-tier0.sh` | calls |
| `lib/ask.sh` | calls |
| `bin/watchtower.sh` | calls |
| `agents/audit/plugin-audit.sh` | called_by |
| `agents/audit/self-audit.sh` | called_by |
| `agents/context/bus-handler.sh` | called_by |
| `agents/context/check-active-task.sh` | called_by |
| `agents/context/check-agent-dispatch.sh` | called_by |
| `agents/context/check-project-boundary.sh` | called_by |
| `agents/context/check-tier0.sh` | called_by |
| `agents/context/post-compact-resume.sh` | called_by |
| `agents/context/pre-compact.sh` | called_by |
| `agents/docgen/generate-article.sh` | called_by |
| `agents/docgen/generate-component.sh` | called_by |
| `agents/fabric/fabric.sh` | called_by |
| `agents/git/git.sh` | called_by |
| `agents/handover/handover.sh` | called_by |
| `agents/healing/healing.sh` | called_by |
| `agents/observe/observe.sh` | called_by |
| `agents/onboarding-test/test-onboarding.sh` | called_by |
| `agents/resume/resume.sh` | called_by |
| `agents/task-create/create-task.sh` | called_by |
| `agents/task-create/update-task.sh` | called_by |
| `C-004` | called_by |
| `bin/watchtower.sh` | called_by |
| `C-007` | called_by |
| `C-008` | called_by |
| `C-001` | called_by |
| `lib/ask.sh` | called_by |
| `tests/unit/lib_paths.bats` | called-by |
| `agents/context/session-metrics.sh` | called_by |
| `tests/unit/lib_paths.bats` | called_by |
| `agents/context/block-task-tools.sh` | called_by |
| `agents/git/lib/hooks.sh` | called_by |

---
*Auto-generated from Component Fabric. Card: `lib-paths.yaml`*
*Last verified: 2026-03-10*
