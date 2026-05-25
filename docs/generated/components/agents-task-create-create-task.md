# create-task

> Task Creation Agent - Mechanical Operations

**Type:** script | **Subsystem:** task-management | **Location:** `agents/task-create/create-task.sh`

## What It Does

Task Creation Agent - Mechanical Operations
Creates properly structured tasks following the framework specification

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [enums](/docs/generated/lib-enums) | calls | Single source of truth for framework enumerations — valid statuses, workflow types, horizons, and status transitions. Provides is_valid_status(), is_valid_type(), is_valid_horizon(), is_valid_transition() functions. Replaces hardcoded lists previously duplicated across 6+ files. |
| [keylock](/docs/generated/lib-keylock) | calls | Advisory file locking: task-level lock files in .context/locks/ to prevent concurrent task modifications. |

## Used By (11)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [handover](/docs/generated/agents-handover-handover) | called_by | Handover Agent - Mechanical Operations |
| [observe](/docs/generated/agents-observe-observe) | called_by | Observe Agent - Lightweight observation capture |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [setup](/docs/generated/lib-setup) | called_by | fw setup - Guided onboarding wizard for new projects |
| [create_task](/docs/generated/tests-unit-create_task) | tested_by | Unit tests for agents/task-create/create-task.sh (17 tests) |
| [create_task](/docs/generated/tests-unit-create_task) | called_by | Unit tests for agents/task-create/create-task.sh (17 tests) |
| [task_id_race](/docs/generated/tests-unit-task_id_race) | called_by | Regression test — concurrent fw work-on invocations must allocate distinct task IDs. Prior bug: generate_id() read max_id then (later) wrote the file; N parallel invocations all observed the same max_id and wrote T-${max+1}. Fix: keylock around read-compute-write sequence. |
| [create_task](/docs/generated/tests-unit-create_task) | tests_by | Unit tests for agents/task-create/create-task.sh (17 tests) |
| [task_id_race](/docs/generated/tests-unit-task_id_race) | tests_by | Regression test — concurrent fw work-on invocations must allocate distinct task IDs. Prior bug: generate_id() read max_id then (later) wrote the file; N parallel invocations all observed the same max_id and wrote T-${max+1}. Fix: keylock around read-compute-write sequence. |
| [update_task](/docs/generated/tests-unit-update_task) | called_by | Unit tests for agents/task-create/update-task.sh (11 tests) |
| [update_task](/docs/generated/tests-unit-update_task) | tests_by | Unit tests for agents/task-create/update-task.sh (11 tests) |

## Documentation

- [Deep Dive: The Task Gate](docs/articles/deep-dives/01-task-gate.md) (deep-dive)

## Related

### Tasks
- T-795: Fix shellcheck warnings across agent scripts — SC2155, SC2144, SC2034, SC2044
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `agents-task-create-create-task.yaml`*
*Last verified: 2026-02-20*
