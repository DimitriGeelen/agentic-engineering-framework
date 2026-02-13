# Agentic Engineering Framework

> Provider-neutral operating guide for AI agents working in this repository.

## How to Use This Document

This document defines how any AI agent (Claude, GPT-4, Gemini, Llama, or others) should operate within this project. Provider-specific integration files may exist alongside this document:

- **Claude Code:** Reads `CLAUDE.md` (auto-loaded)
- **Cursor/Copilot:** Can read this file directly or create `.cursorrules`
- **Other LLMs:** Read this file as your operating guide

## Project Overview

The **Agentic Engineering Framework** is a governance framework for systematizing how AI agents work within engineering projects. This is not a traditional code library — it's a set of structural rules, patterns, and enforcement mechanisms for agentic workflows.

**Works with:** Any file-based, CLI-capable AI agent environment.

## Core Principle

**Nothing gets done without a task.** This is enforced structurally by the framework, not by agent discipline.

## Four Constitutional Directives (Priority Order)

1. **Antifragility** — System strengthens under stress; failures are learning events
2. **Reliability** — Predictable, observable, auditable execution; no silent failures
3. **Usability** — Joy to use/extend/debug; sensible defaults; actionable errors
4. **Portability** — No provider/language/environment lock-in; prefer standards (MCP, LSP, OpenAPI)

## Authority Model

```
Human    →  SOVEREIGNTY  →  Can override anything, is accountable
Framework →  AUTHORITY   →  Enforces rules, checks gates, logs everything
Agent    →  INITIATIVE   →  Can propose, request, suggest — never decides
```

## Task System

### File Structure

```
.tasks/
  active/      # In-progress tasks (e.g., T-042-add-oauth.md)
  completed/   # Finished tasks
  templates/   # Task templates by workflow type
```

### Task File Format

Tasks are Markdown with YAML frontmatter. Use `zzz-default.md` as template.

**Required frontmatter fields:**
- `id`, `name`, `description`, `status`, `workflow_type`, `owner`, `created`, `last_update`

**Body sections:**
- Design Record, Specification Record, Test Files, Updates (chronological log)

### Task Lifecycle

```
Captured → Refined → Started Work ↔ Issues/Blocked → Work Completed
```

### Workflow Types

| Type | Purpose |
|------|---------|
| Specification | Define what to build |
| Design | Determine how to build |
| Build | Create implementation |
| Test | Verify correctness |
| Refactor | Improve existing code |
| Decommission | Remove obsolete code |

## Enforcement Tiers

| Tier | Description | Bypass |
|------|-------------|--------|
| 0 | Consequential actions (deploy, delete, destroy, firewall, secrets, db-migrate) | Never |
| 1 | All standard operations (default) | Create task or escalate to Tier 2 |
| 2 | Human situational authorization | Single-use, mandatory logging |
| 3 | Pre-approved categories (health checks, status queries, git-status) | Configured |

## Working with Tasks

When starting work:
1. Check for existing task or create new one following `zzz-default.md` template
2. Set status to `started-work`
3. Log every action in Updates section with: action, output, context snapshot

When encountering issues:
1. Set status to `issues` or `blocked`
2. Log error reference and healing loop suggestions
3. Record resolution when fixed for pattern learning

When completing:
1. Verify all acceptance criteria met
2. Set status to `work-completed`
3. Generate episodic summary for future reference

## Context Integration

Tasks feed three memory types:
- **Working Memory** — Active task status and pending actions
- **Project Memory** — Patterns across all tasks (failure modes, effective approaches)
- **Episodic Memory** — Completed task histories for future reference

## Error Escalation Ladder

1. **A** — Don't repeat the same failure
2. **B** — Improve technique
3. **C** — Improve tooling
4. **D** — Change ways of working

## Agents

Each agent has a bash script (mechanical) and AGENT.md (intelligence/guidance).

| Agent | Location | Purpose | Command |
|-------|----------|---------|---------|
| Task Create | `agents/task-create/` | Create new tasks | `./agents/task-create/create-task.sh` |
| Audit | `agents/audit/` | Check compliance | `./agents/audit/audit.sh` |
| Session Capture | `agents/session-capture/` | Ensure nothing lost | See `AGENT.md` checklist |
| Git | `agents/git/` | Enforce traceability | `./agents/git/git.sh commit -m "T-XXX: ..."` |
| Handover | `agents/handover/` | Session continuity | `./agents/handover/handover.sh` |
| Context | `agents/context/` | Manage memory fabric | `./agents/context/context.sh init` |
| Healing | `agents/healing/` | Error recovery | `./agents/healing/healing.sh diagnose T-XXX` |
| Resume | `agents/resume/` | Post-compaction recovery | `./agents/resume/resume.sh status` |

## Session Protocols

### Session Start
1. Initialize context: `./agents/context/context.sh init`
2. Read `.context/handovers/LATEST.md` to understand current state
3. Review the "Suggested First Action" section
4. Set focus: `./agents/context/context.sh focus T-XXX`
5. Run `./metrics.sh` to see project status

### Mid-Session Recovery (after context compaction)
1. Run resume: `./agents/resume/resume.sh status`
2. Sync working memory: `./agents/resume/resume.sh sync`
3. Continue from recommendations

### Session End
1. Run session capture checklist (`agents/session-capture/AGENT.md`)
2. Create tasks for all uncaptured work
3. Update practices with learnings
4. Generate handover: `./agents/handover/handover.sh`
5. Fill in the [TODO] sections in the handover document
6. Commit all changes with task references
7. Run `./metrics.sh` to verify state

**Do not end a session without generating a handover.**

## Quick Reference

| Action | Command |
|--------|---------|
| Create task | `./agents/task-create/create-task.sh` |
| Commit changes | `./agents/git/git.sh commit -m "T-XXX: description"` |
| Install git hooks | `./agents/git/git.sh install-hooks` |
| Run audit | `./agents/audit/audit.sh` |
| View metrics | `./metrics.sh` |
| Initialize session | `./agents/context/context.sh init` |
| Set focus | `./agents/context/context.sh focus T-XXX` |
| Diagnose issue | `./agents/healing/healing.sh diagnose T-XXX` |
| Resume state | `./agents/resume/resume.sh status` |
| Generate handover | `./agents/handover/handover.sh` |
| Read last handover | `cat .context/handovers/LATEST.md` |
