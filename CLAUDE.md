# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

The **Agentic Engineering Framework** is a governance framework for systematizing how AI agents work within engineering projects. This is not a traditional code library—it's a set of structural rules, patterns, and enforcement mechanisms for agentic workflows.

**Primary Environment:** Claude Code (file-based, CLI-friendly)

## Core Principle

**Nothing gets done without a task.** This is enforced structurally by the framework, not by agent discipline.

## Four Constitutional Directives (Priority Order)

All architectural decisions must trace back to these directives:

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

| Type | Purpose | Typical Agent |
|------|---------|---------------|
| Specification | Define what to build | Specification Agent |
| Design | Determine how to build | Design Agent |
| Build | Create implementation | Coder Agent |
| Test | Verify correctness | Test Agent |
| Refactor | Improve existing code | Coder Agent |
| Decommission | Remove obsolete code | Deployment Agent |

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
3. Framework generates episodic summary for future reference

## Context Integration

Tasks feed three memory types:
- **Working Memory** — Active task status and pending actions
- **Project Memory** — Patterns across all tasks (failure modes, effective approaches)
- **Episodic Memory** — Completed task histories for future reference

## Error Escalation Ladder

Graduated response from tactical to structural:
1. **A** — Don't repeat the same failure
2. **B** — Improve technique
3. **C** — Improve tooling
4. **D** — Change ways of working

## Agents

The framework includes agents for common operations. Each agent has a bash script (mechanical) and AGENT.md (intelligence/guidance).

### Task Creation Agent

**Location:** `agents/task-create/`

**When to use:** Before starting any new work, create a task.

```bash
# Interactive mode
./agents/task-create/create-task.sh

# With arguments
./agents/task-create/create-task.sh --name "Fix bug" --type build --owner human --start
```

### Audit Agent

**Location:** `agents/audit/`

**When to use:** Periodically check framework compliance. Run after completing work or when suspecting drift.

```bash
./agents/audit/audit.sh
```

**Exit codes:** 0=pass, 1=warnings, 2=failures

### Session Capture Agent

**Location:** `agents/session-capture/`

**When to use:** MANDATORY before ending any session or switching context.

Review the checklist in `agents/session-capture/AGENT.md` and ensure:
- All discussed work has tasks
- All decisions are recorded
- All learnings are captured as practices
- All open questions are tracked

**Do not end a session without running session capture.**

## Quick Reference

| Action | Command |
|--------|---------|
| Create task | `./agents/task-create/create-task.sh` |
| Run audit | `./agents/audit/audit.sh` |
| View metrics | `./metrics.sh` |
| Check status | `git status && ./metrics.sh` |
| Session capture | Review `agents/session-capture/AGENT.md` checklist |

## Session End Protocol

Before ending any session:
1. Run session capture checklist
2. Create tasks for all uncaptured work
3. Update practices with learnings
4. Commit all changes with task references
5. Run `./metrics.sh` to verify state
