# Track 3: Agent Implementer Walkthrough

You're building a new AI agent integration (beyond Claude Code) or extending the hook system. This guide covers the enforcement architecture, memory model, and integration points.

**Time:** ~45 minutes
**Prerequisites:** Familiarity with the framework's governance model (see [New User Track](01-new-user.md))

---

## 1. The Authority Model

```
Human    →  SOVEREIGNTY  →  Can override anything, is accountable
Framework →  AUTHORITY   →  Enforces rules, checks gates, logs everything
Agent    →  INITIATIVE   →  Can propose, request, suggest — never decides
```

**Key principle:** Initiative is not authority. Broad directives ("proceed as you see fit") delegate initiative, not authority. When a structural gate blocks an action, the gate wins.

**Read more:**
- [Deep-dive: Authority Model](../articles/deep-dives/06-authority-model.md)
- [Generated article: Enforcement](../generated/articles/enforcement-prompt.md)

---

## 2. Hook System — Where Enforcement Lives

The framework enforces rules through hooks that run before and after tool invocations.

### For Claude Code

Hooks are configured in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Write|Edit", "hooks": [{ "type": "command", "command": "check-active-task.sh" }] },
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "check-tier0.sh" }] },
      { "matcher": "Write|Edit|Bash", "hooks": [{ "type": "command", "command": "budget-gate.sh" }] }
    ],
    "PostToolUse": [
      { "matcher": "*", "hooks": [{ "type": "command", "command": "checkpoint.sh" }] }
    ]
  }
}
```

**Exit code protocol:**
- `0` — Allow (hook passes)
- `1` — Warn (message shown, action proceeds)
- `2` — Block (action rejected)

### For Other Agents (Cursor, Copilot, custom)

The same gates can be implemented as:
- Git hooks (`commit-msg`, `post-commit`, `pre-push`) — portable across all agents
- CLI wrappers around `fw` commands
- CI/CD pipeline checks (see GitHub Action: `.github/actions/fw-audit/`)
- `AGENTS.md` — Cross-agent configuration standard

**Read more:**
- [Deep-dive: Enforcement](../articles/deep-dives/20-enforcement.md)

**Implementer note:** The framework is designed to be provider-neutral. `CLAUDE.md` contains Claude Code-specific integration. `FRAMEWORK.md` is the provider-neutral guide. `AGENTS.md` is the cross-agent standard.

---

## 3. Task Gate — The Foundation

Every code change requires an active task. This is the framework's core invariant.

**How it works:**
1. `check-active-task.sh` reads `.context/working/focus.yaml`
2. Validates the referenced task exists in `.tasks/active/`
3. If no active task → exit code 2 (block)

**Integration points:**
- Set focus: write task ID to `.context/working/focus.yaml`
- Or use: `fw context focus T-XXX`
- Task files: `.tasks/active/T-XXX-slug.md` (YAML frontmatter + markdown body)

**Read more:**
- [Deep-dive: Task Gate](../articles/deep-dives/01-task-gate.md)
- [Generated article: Task Management](../generated/articles/task-management-prompt.md)

---

## 4. Context Budget — Managing the Finite Resource

AI agents have limited context windows. The budget system prevents context exhaustion.

**Architecture:**
```
budget-gate.sh (PreToolUse)
    ↓ reads
Session JSONL transcript
    ↓ calculates
Token usage estimate
    ↓ writes
.context/working/.budget-status  →  {level, tokens, timestamp}
    ↓ returns
exit 0 (ok/warn) or exit 2 (critical/block)
```

**For non-Claude agents:** Implement equivalent token tracking. The concept (track usage → warn → block → auto-handover) is universal. The specific implementation (JSONL parsing) is Claude Code-specific.

**Read more:**
- [Deep-dive: Context Budget](../articles/deep-dives/03-context-budget.md)
- [Generated article: Budget Management](../generated/articles/budget-management-prompt.md)

---

## 5. Memory Model — Three Layers

Understanding the memory model is essential for building agents that maintain continuity.

### Working Memory (`.context/working/`)
- `session.yaml` — Current session ID, start time
- `focus.yaml` — Active task ID
- `.budget-status` — Context budget level
- `.tool-counter` — Tool invocation count

**Lifetime:** One session. Reset on session start.

### Project Memory (`.context/project/`)
- `learnings.yaml` — Lessons learned (L-XXX entries)
- `patterns.yaml` — Failure/success patterns
- `decisions.yaml` — Architectural decisions
- `gaps.yaml` — Known spec-reality gaps
- `metrics-history.yaml` — Historical metrics

**Lifetime:** Permanent. Grows over project life.

### Episodic Memory (`.context/episodic/`)
- `T-XXX.yaml` — Per-task completion summary
- Contains: timeline, outcomes, challenges, decisions, artifacts, metrics

**Lifetime:** Permanent. One per completed task.

**Integration:** Agents should read learnings/patterns before starting work (the `fw context focus` command surfaces relevant ones). Write learnings via `fw context add-learning`.

**Read more:**
- [Deep-dive: Three-Layer Memory](../articles/deep-dives/04-three-layer-memory.md)
- [Generated article: Context Fabric](../generated/articles/context-fabric-prompt.md)

---

## 6. Handover Protocol — Session Continuity

Agents must produce a handover document before session end. This enables the next session (same or different agent) to continue.

**Required sections:**
- Where We Are (2-3 sentence summary)
- Work in Progress (per-task status with last action, next step, blockers)
- Decisions Made (with rationale and alternatives)
- Suggested First Action

**Implementation:** Call `fw handover --commit` or write directly to `.context/handovers/`.

**Read more:**
- [Deep-dive: Handover](../articles/deep-dives/19-handover.md)
- [Generated article: Handover](../generated/articles/handover-prompt.md)

---

## 7. Building a New Agent

To integrate a new AI agent with the framework:

1. **Task gate:** Ensure the agent checks for an active task before modifying files
2. **Commit traceability:** Use `fw git commit` or ensure commits include `T-XXX:` prefix
3. **Handover:** Generate a handover document before session end
4. **Budget awareness:** Track context/token usage and wrap up before exhaustion
5. **Audit compliance:** Run `fw audit` periodically or in CI/CD

**Minimum viable integration:**
```bash
# Before work
fw context init
fw work-on "task name" --type build

# During work
fw git commit -m "T-XXX: changes"

# After work
fw handover --commit
```

**Full integration** adds: hook enforcement, context budget management, learning capture, healing loop, and episodic memory.

---

## Component Fabric for Implementers

The Component Fabric tracks file dependencies. When modifying the framework:

```bash
fw fabric deps <file>          # What does this file depend on?
fw fabric impact <file>        # What breaks if I change this?
fw fabric blast-radius HEAD    # What did my last commit affect?
```

After creating new files:
```bash
fw fabric register <path>     # Add to topology
```

**Read more:**
- [Deep-dive: Component Fabric](../articles/deep-dives/07-component-fabric.md)
- [Generated article: Component Fabric](../generated/articles/component-fabric-prompt.md)

---

## What's Next?

- Browse the [127 component docs](../generated/components/) for detailed file-level reference
- Explore the [interactive topology](http://localhost:3000/fabric) to see how everything connects
- Read `FRAMEWORK.md` for the provider-neutral specification
- Read `AGENTS.md` for the cross-agent configuration standard
