# context-dispatcher

> Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic)

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/context.sh`

**Tags:** `context`, `dispatcher`, `learning`, `decision`, `pattern`, `focus`

## What It Does

Context Agent - Manages the Context Fabric memory system
Commands:
init          Initialize working memory for new session
status        Show current context state
add-learning  Add a new learning to project memory
add-pattern   Add a new pattern (failure/success/workflow)
add-decision  Add a decision to project memory
generate-episodic  Generate episodic summary for completed task
focus         Set or show current focus
Usage:

## Dependencies (10)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [add-learning](/docs/generated/add-learning) | calls | Add a learning entry to project memory (learnings.yaml). Assigns next L-XXX ID, formats YAML, inserts before candidates section. |
| `decision` | calls | — |
| `pattern` | calls | — |
| [init](/docs/generated/agents-context-lib-init) | calls | Context Agent - init command |
| [status](/docs/generated/agents-context-lib-status) | calls | Context Agent - status command |
| [pattern](/docs/generated/agents-context-lib-pattern) | calls | Context Agent - add-pattern command |
| [decision](/docs/generated/agents-context-lib-decision) | calls | Context Agent - add-decision command |
| [episodic](/docs/generated/agents-context-lib-episodic) | calls | Context Agent - generate-episodic command |
| [focus](/docs/generated/agents-context-lib-focus) | calls | Context Agent - focus command |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

## Used By (15)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `fw-cli` | calls | bin/fw routes 'context' subcommand here |
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [setup](/docs/generated/lib-setup) | called_by | fw setup - Guided onboarding wizard for new projects |
| [init](/docs/generated/lib-init) | called_by | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [context_status](/docs/generated/tests-unit-context_status) | called-by | Unit tests for context status (7 tests) |
| [context_focus](/docs/generated/tests-unit-context_focus) | called-by | Unit tests for context focus (15 tests) |
| [context_safe_commands](/docs/generated/tests-unit-context_safe_commands) | called-by | Unit tests for context safe_commands (35 tests) |
| [context_decision](/docs/generated/tests-unit-context_decision) | called-by | Unit tests for context decision (11 tests) |
| [context_init](/docs/generated/tests-unit-context_init) | called-by | Unit tests for context init (16 tests) |
| [context_learning](/docs/generated/tests-unit-context_learning) | called-by | Unit tests for context learning (10 tests) |
| [context_episodic](/docs/generated/tests-unit-context_episodic) | called-by | Unit tests for context episodic (11 tests) |
| [context_pattern](/docs/generated/tests-unit-context_pattern) | called-by | Unit tests for context pattern (11 tests) |
| [update_task_episodic_gen](/docs/generated/tests-unit-update_task_episodic_gen) | called_by | Regression test — episodic auto-gen on status: work-completed. Four tasks in one session (T-1363/1364/1366/1367) transitioned to work-completed (date_finished set, [task-update-agent] Updates entry) yet no episodic was generated. Pins the happy path so any regression surfaces. |
| [update_task_episodic_gen](/docs/generated/tests-unit-update_task_episodic_gen) | tests_by | Regression test — episodic auto-gen on status: work-completed. Four tasks in one session (T-1363/1364/1366/1367) transitioned to work-completed (date_finished set, [task-update-agent] Updates entry) yet no episodic was generated. Pins the happy path so any regression surfaces. |

---
*Auto-generated from Component Fabric. Card: `context-dispatcher.yaml`*
*Last verified: 2026-02-20*
