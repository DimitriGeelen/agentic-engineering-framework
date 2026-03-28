# Context Agent

> Manages the Context Fabric — the framework's persistent memory system.

## Purpose

The Context Fabric provides structured memory across sessions:

| Memory Type | Purpose | Lifespan |
|-------------|---------|----------|
| **Working Memory** | Current session state, focus, pending actions | Session (reset on init) |
| **Project Memory** | Patterns, decisions, learnings accumulated over time | Project lifetime |
| **Episodic Memory** | Condensed histories of completed tasks | Project lifetime |

## Context Fabric Structure

```
.context/
├── working/           # Working Memory
│   ├── session.yaml   # Session ID, status, tasks touched
│   └── focus.yaml     # Current task, priorities, blockers
├── project/           # Project Memory
│   ├── patterns.yaml  # Failure, success, workflow patterns
│   ├── decisions.yaml # Key decisions with rationale
│   └── learnings.yaml # Lessons learned from tasks
├── episodic/          # Episodic Memory
│   ├── TEMPLATE.yaml  # Template for new summaries
│   └── T-XXX.yaml     # One file per completed task
├── handovers/         # Session handovers
├── audits/            # Audit history
└── bypass-log.yaml    # Git bypass documentation
```

## Commands

### init — Start a new session

```bash
./agents/context/context.sh init
```

Initializes working memory:
- Creates session ID (S-YYYY-MMDD-HHMM)
- Sets predecessor from latest handover
- Lists active tasks
- Resets focus

**When to use:** Start of every session, before any work.

### status — Show context state

```bash
./agents/context/context.sh status
```

Shows:
- Working memory (session, focus)
- Project memory counts (patterns, decisions, learnings)
- Episodic memory (task summaries)
- Other context artifacts (handovers, audits)

**When to use:** To understand current state.

### focus — Set or show current focus

```bash
# Show current focus
./agents/context/context.sh focus

# Set focus to a task
./agents/context/context.sh focus T-005
```

**When to use:** When starting work on a task, or to check what you're focused on.

### add-learning — Record a learning

```bash
./agents/context/context.sh add-learning "Always validate inputs" --task T-014 --source P-001
```

Options:
- `--task T-XXX` — Which task this came from
- `--source` — Principle or pattern this relates to

**When to use:** When you discover something worth remembering for future work.

### add-pattern — Record a pattern

```bash
# Failure pattern (with mitigation)
./agents/context/context.sh add-pattern failure "API timeout" --task T-015 --mitigation "Add retry logic"

# Success pattern
./agents/context/context.sh add-pattern success "Phased implementation" --task T-014

# Workflow pattern
./agents/context/context.sh add-pattern workflow "Task absorption" --task T-013
```

Pattern types:
- **failure** — Things that went wrong, with mitigations
- **success** — Approaches that worked well
- **workflow** — How to work effectively

**When to use:** After resolving issues or discovering effective approaches.

### add-decision — Record a decision

```bash
./agents/context/context.sh add-decision "Use YAML over JSON" --task T-005 --rationale "Human readable" --rejected "JSON"
```

Options:
- `--task T-XXX` — Which task this was for
- `--rationale` — Why this decision was made
- `--rejected` — Comma-separated alternatives rejected

**When to use:** When making architectural or design decisions worth recording.

### generate-episodic — Create task summary

```bash
./agents/context/context.sh generate-episodic T-014
```

Creates a condensed summary of a completed task for future reference.

**When to use:** After task completion (ideally automated).

## Integration Points

| Agent | Integration |
|-------|-------------|
| Handover | Reads working memory; writes session handover |
| Audit | Reads patterns for trend detection |
| Git | Updates tasks_touched on commit |
| Session Start | Loads project + episodic for relevant context |

## Best Practices

### Session Start
```bash
./agents/context/context.sh init
./agents/context/context.sh focus T-005
```

### During Work
- Use `add-learning` when discovering something reusable
- Use `add-pattern` after resolving failures
- Use `add-decision` for significant choices

### Session End
- Generate episodic for completed tasks
- Run handover agent (uses context automatically)

## File Formats

### session.yaml (Working Memory)
```yaml
session_id: S-2026-0213-2115
start_time: 2026-02-13T21:15:00Z
predecessor: S-2026-0213-2048
status: active
active_tasks: [T-001, T-005]
tasks_touched: [T-005]
tasks_completed: []
```

### patterns.yaml (Project Memory)
```yaml
failure_patterns:
  - id: FP-001
    pattern: "Timestamp update loop"
    learned_from: T-013
    mitigation: "Only update active tasks"

success_patterns:
  - id: SP-001
    pattern: "Phased implementation"
    learned_from: T-014
```

### T-XXX.yaml (Episodic Memory)
```yaml
task_id: T-014
task_name: "Improve audit agent"
summary: |
  Brief description of outcomes
outcomes:
  - "Outcome 1"
challenges:
  - description: "What failed"
    resolution: "How fixed"
```

## Related

- `agents/handover/` — Uses context for session summaries
- `agents/audit/` — Reads patterns for trend detection
- `010-TaskSystem.md` — Context Fabric specification
- `005-DesignDirectives.md` — Context Fabric design rationale
