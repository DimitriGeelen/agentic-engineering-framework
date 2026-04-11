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

| Target | Relationship |
|--------|-------------|
| `lib/init.sh` | calls |
| `agents/git/git.sh` | calls |
| `C-001` | calls |
| `agents/task-create/create-task.sh` | calls |

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `tests/unit/lib_setup.bats` | called-by |
| `tests/unit/lib_setup.bats` | called_by |

## Related

### Tasks
- T-761: Fix shellcheck warnings in update.sh, upstream.sh, init.sh, notify.sh, setup.sh
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-setup.yaml`*
*Last verified: 2026-02-20*
