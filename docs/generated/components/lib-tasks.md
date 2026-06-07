# tasks

> fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/tasks.sh`

## What It Does

lib/tasks.sh — Shared task file lookup helpers
Provides find_task_file() and task_exists() to replace the
find ... -name "${task_id}-*.md" pattern duplicated across 7+ files.
Usage: source "$FRAMEWORK_ROOT/lib/tasks.sh"
Requires: TASKS_DIR (set by lib/paths.sh)

### Framework Reference

When starting work (**BEFORE reading code, editing files, or invoking skills**):
1. Check for existing task or create new one following `zzz-default.md` template
2. Set status to `started-work`
3. Set focus: `fw context focus T-XXX`
4. THEN proceed with implementation (skills, code changes, etc.)
5. Record decisions in Decisions section ONLY when choosing between alternatives
6. Updates section is auto-populated at completion — manual entries optional

*(truncated — see CLAUDE.md for full section)*

## Used By (22)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hooks](/docs/generated/agents-git-lib-hooks) | called_by | Git Agent - Hook installation subcommand |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [paths](/docs/generated/lib-paths) | called_by | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [lib_tasks](/docs/generated/tests-unit-lib_tasks) | called-by | Unit tests for tasks (10 tests) |
| [lib_tasks](/docs/generated/tests-unit-lib_tasks) | called_by | Unit tests for tasks (10 tests) |
| [context_episodic](/docs/generated/tests-unit-context_episodic) | called_by | Unit tests for context episodic (11 tests) |
| [context_episodic](/docs/generated/tests-unit-context_episodic) | tests_by | Unit tests for context episodic (11 tests) |
| [context_focus](/docs/generated/tests-unit-context_focus) | called_by | Unit tests for context focus (15 tests) |
| [context_focus](/docs/generated/tests-unit-context_focus) | tests_by | Unit tests for context focus (15 tests) |
| [git_common](/docs/generated/tests-unit-git_common) | called_by | Unit tests for git common (10 tests) |
| [git_common](/docs/generated/tests-unit-git_common) | tests_by | Unit tests for git common (10 tests) |
| [inception_decide_ac_tick](/docs/generated/tests-unit-inception_decide_ac_tick) | called_by | Unit tests for T-1324 — tick_inception_decide_acs auto-ticks the templated [REVIEW]/[RUBBER-STAMP] Human AC after fw inception decide writes the Decision block, so the work-completed gate does not leave the task in partial-complete forever (G-008; P-039). |
| [inception_decide_ac_tick](/docs/generated/tests-unit-inception_decide_ac_tick) | tests_by | Unit tests for T-1324 — tick_inception_decide_acs auto-ticks the templated [REVIEW]/[RUBBER-STAMP] Human AC after fw inception decide writes the Decision block, so the work-completed gate does not leave the task in partial-complete forever (G-008; P-039). |
| [inception_decide_atomicity](/docs/generated/tests-unit-inception_decide_atomicity) | called_by | TODO: describe what this component does |
| [inception_decide_atomicity](/docs/generated/tests-unit-inception_decide_atomicity) | tests_by | TODO: describe what this component does |
| [inception_tick_decision_recorded](/docs/generated/tests-unit-inception_tick_decision_recorded) | called_by | TODO: describe what this component does |
| [inception_tick_decision_recorded](/docs/generated/tests-unit-inception_tick_decision_recorded) | tests_by | TODO: describe what this component does |
| [inception_tick_marker](/docs/generated/tests-unit-inception_tick_marker) | called_by | TODO: describe what this component does |
| [inception_tick_marker](/docs/generated/tests-unit-inception_tick_marker) | tests_by | TODO: describe what this component does |
| [lib_inception](/docs/generated/tests-unit-lib_inception) | called_by | Unit tests for inception (12 tests) |
| [lib_inception](/docs/generated/tests-unit-lib_inception) | tests_by | Unit tests for inception (12 tests) |
| [lib_tasks](/docs/generated/tests-unit-lib_tasks) | tests_by | Unit tests for tasks (10 tests) |

---
*Auto-generated from Component Fabric. Card: `lib-tasks.yaml`*
*Last verified: 2026-03-11*
