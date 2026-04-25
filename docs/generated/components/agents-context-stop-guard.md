# stop-guard

> Stop hook — conversation-capture nudge. Fires after every assistant response, never blocks (exits 0). Emits agent-visible stderr nudge when a pure-conversation session accumulates N exchanges without tools, commits, or focus. Nudge becomes additional context on the next turn; agent then proactively asks the user if a task should be created (C-002 Exploratory Conversation Guard).

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/stop-guard.sh`

**Tags:** `hook`, `stop`, `conversation-capture`, `C-002`, `T-1211`

## What It Does

Stop hook — conversation-capture nudge (T-1211)
Fires after every assistant response. Never blocks (exits 0). Emits an
agent-visible stderr nudge when a "pure conversation" session has accumulated
N exchanges without using any tools, making any commits, or setting a focus.
The nudge is a one-line stderr message that becomes additional context on the
agent's next turn (per Claude Code hooks semantics). On seeing it, the agent
proactively asks the user a y/n:
"We've been talking for N exchanges without capturing anything. Should I
create a task to summarize this conversation so far? (y/n)"
On 'y': agent creates a task via `fw work-on "summary" --type spec` and

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `.context/working/stop-guard.log` | writes |
| `.context/working/focus.yaml` | reads |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | invoked_via_fw_hook |
| `agents/context/tests/stop-guard-stub-test.sh` | called_by |

---
*Auto-generated from Component Fabric. Card: `agents-context-stop-guard.yaml`*
*Last verified: 2026-04-24*
