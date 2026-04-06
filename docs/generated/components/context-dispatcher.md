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

| Target | Relationship |
|--------|-------------|
| `C-002` | calls |
| `decision` | calls |
| `pattern` | calls |
| `agents/context/lib/init.sh` | calls |
| `agents/context/lib/status.sh` | calls |
| `agents/context/lib/pattern.sh` | calls |
| `agents/context/lib/decision.sh` | calls |
| `agents/context/lib/episodic.sh` | calls |
| `agents/context/lib/focus.sh` | calls |
| `lib/paths.sh` | calls |

## Used By (13)

| Component | Relationship |
|-----------|-------------|
| `fw-cli` | calls |
| `agents/task-create/update-task.sh` | called_by |
| `bin/fw` | called_by |
| `lib/setup.sh` | called_by |
| `lib/init.sh` | called_by |
| `tests/unit/context_status.bats` | called-by |
| `tests/unit/context_focus.bats` | called-by |
| `tests/unit/context_safe_commands.bats` | called-by |
| `tests/unit/context_decision.bats` | called-by |
| `tests/unit/context_init.bats` | called-by |
| `tests/unit/context_learning.bats` | called-by |
| `tests/unit/context_episodic.bats` | called-by |
| `tests/unit/context_pattern.bats` | called-by |

---
*Auto-generated from Component Fabric. Card: `context-dispatcher.yaml`*
*Last verified: 2026-02-20*
