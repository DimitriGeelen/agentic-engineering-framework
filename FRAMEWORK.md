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
  templates/   # Task templates (default.md, inception.md)
```

### Task File Format

Tasks are Markdown with YAML frontmatter. Use `default.md` as template.

**Required frontmatter fields:**
- `id`, `name`, `description`, `status`, `workflow_type`, `owner`, `created`, `last_update`

**Body sections:**
- Context (design docs, specs, predecessor tasks), Updates (chronological log)

### Task Lifecycle

```
Captured → Started Work ↔ Issues → Work Completed
```

Four statuses: `captured`, `started-work`, `issues`, `work-completed`.

### Workflow Types

| Type | Purpose |
|------|---------|
| Specification | Define what to build |
| Design | Determine how to build |
| Build | Create implementation |
| Test | Verify correctness |
| Refactor | Improve existing code |
| Decommission | Remove obsolete code |
| Inception | Explore problem space, validate assumptions, go/no-go decision |

## Enforcement Tiers

| Tier | Description | Bypass | Implementation |
|------|-------------|--------|----------------|
| 0 | Consequential actions (force push, hard reset, rm -rf /, DROP TABLE) | Human approval via `fw tier0 approve` | PreToolUse hook on Bash (check-tier0.sh) |
| 1 | All standard operations (default) | Create task or escalate to Tier 2 | PreToolUse hook on Write/Edit (check-active-task.sh) |
| 2 | Human situational authorization | Single-use, mandatory logging | Git --no-verify + bypass log |
| 3 | Pre-approved categories (health checks, status queries, git-status) | Configured | Defined in 011-EnforcementConfig.md |

## Working with Tasks

When starting work (**BEFORE reading code, editing files, or invoking external workflows**):
1. Check for existing task or create new one following `default.md` template
2. Set status to `started-work`
3. Set focus on the task: `fw context focus T-XXX`
4. THEN proceed with implementation
5. Log every action in Updates section with: action, output, context snapshot

When encountering issues:
1. Set status to `issues`
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
| Task Create | `agents/task-create/` | Create new tasks | `fw task create --name "..." --type build` |
| Task Update | `agents/task-create/` | Change task status | `fw task update T-XXX --status ...` |
| Audit | `agents/audit/` | Check compliance | `fw audit` |
| Session Capture | `agents/session-capture/` | Ensure nothing lost | See `AGENT.md` checklist |
| Git | `agents/git/` | Enforce traceability | `fw git commit -m "T-XXX: ..."` |
| Handover | `agents/handover/` | Session continuity | `fw handover --commit` |
| Context | `agents/context/` | Manage memory fabric | `fw context init` |
| Healing | `agents/healing/` | Error recovery | `fw healing diagnose T-XXX` |
| Resume | `agents/resume/` | Post-compaction recovery | `fw resume status` |
| Observe | `agents/observe/` | Capture anomalies | `fw observe "description"` |
| Dispatch | `agents/dispatch/` | Sub-agent prompt templates | Read templates before dispatching |

## Session Protocols

### Session Start
1. Initialize context: `fw context init`
2. Read `.context/handovers/LATEST.md` to understand current state
3. Review the "Suggested First Action" section
4. Set focus: `fw context focus T-XXX`
5. Run `fw metrics` to see project status

### Mid-Session Recovery (after context compaction)
1. Run resume: `fw resume status`
2. Sync working memory: `fw resume sync`
3. Continue from recommendations

### Session End
1. Run session capture checklist (`agents/session-capture/AGENT.md`)
2. Create tasks for all uncaptured work
3. Update practices with learnings
4. Generate handover: `fw handover --commit`
5. Fill in the [TODO] sections in the handover document
6. Run `fw metrics` to verify state

**Do not end a session without generating a handover.**

## fw CLI

The `fw` command is the single entry point for all framework operations:

```bash
fw help              # Show all commands
fw version           # Show version and paths
fw doctor            # Check framework health
fw audit             # Run compliance audit
fw metrics           # Show project metrics
fw context init      # Initialize session
fw context focus T-XXX
fw git commit -m "T-XXX: description"
fw handover --commit # Generate and commit handover
fw task create --name "Fix bug" --type build --owner human
fw work-on "name" --type build  # Create task + set focus + start
fw healing diagnose T-XXX
fw promote suggest   # Check graduation candidates
fw tier0 approve     # Approve a blocked destructive command
```

## Quick Reference

| Action | Command |
|--------|---------|
| **Start work** | `fw work-on "name" --type build` |
| Resume task | `fw work-on T-XXX` |
| Create task | `fw task create --name "..." --type build` |
| Update status | `fw task update T-XXX --status ...` |
| Commit changes | `fw git commit -m "T-XXX: description"` |
| Install git hooks | `fw git install-hooks` |
| Run audit | `fw audit` |
| View metrics | `fw metrics` |
| Initialize session | `fw context init` |
| Set focus | `fw context focus T-XXX` |
| Add learning | `fw context add-learning "..." --task T-XXX` |
| Diagnose issue | `fw healing diagnose T-XXX` |
| Resume state | `fw resume status` |
| Generate handover | `fw handover --commit` |
| Read last handover | `cat .context/handovers/LATEST.md` |
| Approve Tier 0 | `fw tier0 approve` |
| Project health | `fw doctor` |

## Installation

### 1. Clone the framework

```bash
git clone https://onedev.docker.ring20.geelenandcompany.com/agentic-engineering-framework.git
```

For git authentication, use your OneDev access token as the password in HTTP Basic Auth:
```bash
# Store credentials (one-time)
git credential-store --file ~/.git-credentials store <<EOF
protocol=https
host=onedev.docker.ring20.geelenandcompany.com
username=admin
password=<your-access-token>
EOF
git config --global credential.helper 'store --file ~/.git-credentials'
```

Access tokens are managed at: `https://onedev.docker.ring20.geelenandcompany.com/~my/access-tokens`

### 2. Add `fw` to your PATH

```bash
# Option A: Add to shell profile
echo 'export PATH="/path/to/agentic-engineering-framework/bin:$PATH"' >> ~/.bashrc

# Option B: Symlink
ln -s /path/to/agentic-engineering-framework/bin/fw /usr/local/bin/fw
```

### 3. Verify installation

```bash
fw version
fw doctor
```

## Setting Up a New Project

```bash
# Quick init (non-interactive)
fw init /path/to/project --provider claude  # or: cursor, generic

# Guided wizard (recommended for first project)
fw setup /path/to/project

# Then:
cd /path/to/project
fw doctor           # Verify setup
fw context init     # Start first session
fw work-on "First task" --type build
```

### Updating the framework

```bash
cd /path/to/agentic-engineering-framework
git pull
```

Existing projects pick up framework updates automatically — they reference the framework via `FRAMEWORK_ROOT` in `.framework.yaml`.
