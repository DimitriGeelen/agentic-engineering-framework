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

## Dependencies (9)

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

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `fw-cli` | calls |
| `agents/task-create/update-task.sh` | called_by |
| `bin/fw` | called_by |
| `lib/setup.sh` | called_by |

## Related

### Tasks
- T-348: Fix update-task.sh sed failing on macOS BSD sed

---
*Auto-generated from Component Fabric. Card: `context-dispatcher.yaml`*
*Last verified: 2026-02-20*
