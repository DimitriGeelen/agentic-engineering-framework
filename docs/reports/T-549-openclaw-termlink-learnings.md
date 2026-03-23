# T-012: TermLink Learnings

## Context

TermLink was used in this evaluation for supervisor-agent communication (event signaling, session monitoring). The pickup prompt also described dispatch workflows for parallel analysis, though these weren't exercised in this session.

---

## What Worked

### 1. Event Emit for Supervisor Signaling (Good)

`termlink event emit tl-meiddtmb milestone --payload '{...}'` successfully delivered milestone events to the supervising session. Simple, reliable, one-liner.

**Usage pattern:** Agent completes milestone → emits event → supervisor polls for events.

### 2. Session Persistence (Good)

The supervising session `tl-meiddtmb` remained available throughout the evaluation. TermLink's session persistence meant the supervisor could check in at any time.

### 3. fw termlink Integration (Good)

`fw termlink check`, `fw termlink status` — the framework's TermLink integration provides convenient wrappers. Good for verifying TermLink is available before trying to use it.

---

## What Didn't Work or Was Awkward

### 1. Event Emit API Syntax (Friction)

Initial attempt used `--name` and `--data` flags (from the pickup prompt's suggested pattern). The actual API is positional: `termlink event emit <target> <topic> --payload <json>`. The pickup prompt's instructions didn't match the actual CLI.

**Suggestion:** Update pickup prompt templates to use actual TermLink CLI syntax. Or add `--name`/`--data` aliases.

### 2. Supervisor Coaching Required File-Based Communication

The supervisor wrote `.context/working/supervisor-coaching.txt` rather than sending TermLink events. This worked but is a manual pattern — the agent must be told to read the file.

**Suggestion:** Consider a `termlink notify <session> <message>` command that injects a message visible on the agent's next tool call (similar to PostToolUse hook injection).

### 3. TermLink Dispatch Not Exercised

The pickup prompt described elaborate dispatch workflows (`fw termlink dispatch`, `fw termlink wait`, `fw termlink result`). These weren't used because Claude Code's built-in Agent tool was sufficient for parallel exploration (3 concurrent Explore agents per inception task).

**Assessment:** For this type of static code analysis, Agent tool sub-agents are lighter-weight than TermLink dispatch. TermLink dispatch would be more valuable for:
- Long-running operations (>5 min)
- Operations needing shell persistence (build, test suites)
- Cross-machine coordination
- Work that should survive context compaction

### 4. No Result Aggregation

When multiple TermLink workers complete, there's no built-in way to aggregate results. Each result must be read individually. Compare to the framework's `fw bus manifest T-XXX` which provides a unified view.

**Suggestion:** Add `termlink results collect --tag <tag>` to aggregate outputs from multiple sessions with the same tag.

---

## Missing Features

| Feature | Use Case | Priority |
|---------|----------|----------|
| `termlink notify` | Push messages to agent sessions | High |
| Result aggregation | Collect outputs from parallel workers | Medium |
| Session tagging/grouping | Group related worker sessions | Medium |
| Dispatch templates | Reusable dispatch configs for common patterns | Low |
| `--name`/`--data` aliases on event emit | Match common mental model | Low |

---

## When to Use TermLink vs Agent Tool

| Factor | TermLink Dispatch | Agent Tool |
|--------|-------------------|------------|
| **Duration** | >5 min operations | <5 min tasks |
| **Persistence** | Survives compaction | Dies with context |
| **Shell access** | Full shell, can run builds/tests | Limited to read/search |
| **Overhead** | Higher (session spawn, SSH) | Lower (in-process) |
| **Result handling** | File-based, manual | Direct return to orchestrator |
| **Best for** | Build, test, deploy, cross-machine | Research, exploration, analysis |

**For this evaluation:** Agent tool was the right choice. The work was read-only exploration that fit within context windows. TermLink dispatch would add overhead without benefit.

**For future evaluations involving code changes, builds, or test runs:** TermLink dispatch would be essential for operations that need shell persistence and can't fit in a sub-agent's brief lifetime.

---

## Summary

TermLink works well for its core purpose (supervisor signaling, persistent sessions). The gap is in the orchestration layer — result aggregation, session grouping, and push notifications would make it more powerful for parallel evaluation workflows. For read-only code analysis, Claude Code's Agent tool is lighter-weight and preferred.
