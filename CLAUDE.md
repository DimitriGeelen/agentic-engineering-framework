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

### Git Agent

**Location:** `agents/git/`

**When to use:** For all git operations that involve code changes. Enforces task traceability (P-002).

```bash
# Commit with task reference (required)
./agents/git/git.sh commit -m "T-003: Add bypass log"

# Task-aware status
./agents/git/git.sh status

# Install enforcement hooks (run once per repo)
./agents/git/git.sh install-hooks

# Log a bypass (when --no-verify was used)
./agents/git/git.sh log-bypass --commit abc123 --reason "Emergency hotfix"

# View task-filtered history
./agents/git/git.sh log --task T-003
./agents/git/git.sh log --traceability
```

### Handover Agent

**Location:** `agents/handover/`

**When to use:** MANDATORY at end of every session.

```bash
# Create handover (manual commit)
./agents/handover/handover.sh

# Create handover and auto-commit via git agent
./agents/handover/handover.sh --commit
```

Creates a forward-looking context document in `.context/handovers/` to enable the next session to continue seamlessly.

### Context Agent

**Location:** `agents/context/`

**When to use:** To manage the Context Fabric (persistent memory system).

```bash
# Initialize session (start of session)
./agents/context/context.sh init

# Show context state
./agents/context/context.sh status

# Set/show current focus
./agents/context/context.sh focus T-005
./agents/context/context.sh focus

# Record a learning
./agents/context/context.sh add-learning "Always validate inputs" --task T-014 --source P-001

# Record a pattern (failure/success/workflow)
./agents/context/context.sh add-pattern failure "API timeout" --task T-015 --mitigation "Add retry"

# Record a decision
./agents/context/context.sh add-decision "Use YAML" --task T-005 --rationale "Human readable"

# Generate episodic summary for completed task
./agents/context/context.sh generate-episodic T-014
```

Manages three memory types:
- **Working Memory** — Session state, current focus, priorities
- **Project Memory** — Patterns, decisions, learnings
- **Episodic Memory** — Condensed task histories

### Healing Agent

**Location:** `agents/healing/`

**When to use:** When a task encounters issues (status = `issues` or `blocked`). Implements the antifragile healing loop.

```bash
# Diagnose task issues and get recovery suggestions
./agents/healing/healing.sh diagnose T-015

# After fixing, record the resolution (adds pattern + learning)
./agents/healing/healing.sh resolve T-015 --mitigation "Added retry logic"

# Show all known failure patterns
./agents/healing/healing.sh patterns

# Check all tasks with issues
./agents/healing/healing.sh suggest
```

The healing loop:
1. **Classify** — Identifies failure type (code, dependency, environment, design, external)
2. **Lookup** — Searches for similar patterns in patterns.yaml
3. **Suggest** — Recommends recovery using Error Escalation Ladder
4. **Log** — Records resolution as pattern for future learning

## Session Start Protocol

**Before beginning any work:**
1. Initialize context: `./agents/context/context.sh init`
2. Read `.context/handovers/LATEST.md` to understand current state
3. Review the "Suggested First Action" section
4. Set focus: `./agents/context/context.sh focus T-XXX`
5. Run `./metrics.sh` to see project status
6. If handover feedback section exists, fill it in

## Quick Reference

| Action | Command |
|--------|---------|
| Create task | `./agents/task-create/create-task.sh` |
| Commit changes | `./agents/git/git.sh commit -m "T-XXX: description"` |
| Task-aware status | `./agents/git/git.sh status` |
| Install git hooks | `./agents/git/git.sh install-hooks` |
| Run audit | `./agents/audit/audit.sh` |
| View metrics | `./metrics.sh` |
| Initialize session | `./agents/context/context.sh init` |
| Set focus | `./agents/context/context.sh focus T-XXX` |
| Context status | `./agents/context/context.sh status` |
| Add learning | `./agents/context/context.sh add-learning "..." --task T-XXX` |
| Diagnose issue | `./agents/healing/healing.sh diagnose T-XXX` |
| Resolve issue | `./agents/healing/healing.sh resolve T-XXX --mitigation "..."` |
| Show patterns | `./agents/healing/healing.sh patterns` |
| Session capture | Review `agents/session-capture/AGENT.md` checklist |
| Generate handover | `./agents/handover/handover.sh` |
| Handover + commit | `./agents/handover/handover.sh --commit` |
| Read last handover | `cat .context/handovers/LATEST.md` |

## Session End Protocol

**Before ending any session:**
1. Run session capture checklist (`agents/session-capture/AGENT.md`)
2. Create tasks for all uncaptured work
3. Update practices with learnings
4. Generate handover: `./agents/handover/handover.sh`
5. Fill in the [TODO] sections in the handover document
6. Commit all changes with task references
7. Run `./metrics.sh` to verify state

**Do not end a session without generating a handover.**
