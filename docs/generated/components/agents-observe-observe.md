# observe

> Observe Agent - Lightweight observation capture

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/observe/observe.sh`

## What It Does

Observe Agent - Lightweight observation capture
The fastest path from "I noticed something" to "it's recorded"
Usage:
./agents/observe/observe.sh "observation text"           # Capture
./agents/observe/observe.sh "text" --tag bug --task T-XX # Capture with context
./agents/observe/observe.sh list                         # Show pending
./agents/observe/observe.sh count                        # Pending count
./agents/observe/observe.sh promote OBS-001              # Promote to task
./agents/observe/observe.sh dismiss OBS-001 --reason "..." # Dismiss
./agents/observe/observe.sh triage                       # Interactive review

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [create-task](/docs/generated/agents-task-create-create-task) | calls | Task Creation Agent - Mechanical Operations |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

## Used By (10)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [observe](/docs/generated/tests-unit-observe) | tested_by | Unit tests for agents/observe/observe.sh (7 tests) |
| [observe](/docs/generated/tests-unit-observe) | called_by | Unit tests for agents/observe/observe.sh (7 tests) |
| [observe](/docs/generated/tests-unit-observe) | tests_by | Unit tests for agents/observe/observe.sh (7 tests) |
| [note_capture_guard](/docs/generated/tests-unit-note_capture_guard) | called_by | TODO: describe what this component does |
| [note_capture_guard](/docs/generated/tests-unit-note_capture_guard) | tests_by | TODO: describe what this component does |
| [note_exit_status](/docs/generated/tests-unit-note_exit_status) | called_by | TODO: describe what this component does |
| [note_exit_status](/docs/generated/tests-unit-note_exit_status) | tests_by | TODO: describe what this component does |
| [t2928_note_dismiss_persists_reason](/docs/generated/tests-unit-t2928_note_dismiss_persists_reason) | called_by | TODO: describe what this component does |
| [t2928_note_dismiss_persists_reason](/docs/generated/tests-unit-t2928_note_dismiss_persists_reason) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-observe-observe.yaml`*
*Last verified: 2026-02-20*
