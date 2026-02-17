# CLAUDE.md

Claude Code integration for the Agentic Engineering Framework.
For the provider-neutral framework guide, see `FRAMEWORK.md`.

This file is auto-loaded by Claude Code. It contains the full operating guide
plus Claude Code-specific integration notes.

## Project Overview

**Project:** __PROJECT_NAME__

<!-- Add your project description, tech stack, and conventions below -->

## Tech Stack and Conventions

<!-- Define your project's tech stack, coding standards, and conventions here -->

## Project-Specific Rules

<!-- Add any project-specific rules that agents must follow -->

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

## Instruction Precedence

When multiple instruction sources conflict (CLAUDE.md, plugins, skills, user messages), this resolution order applies:

1. **Framework rules (this file)** — Core Principle, Authority Model, Enforcement Tiers, and Task System rules take absolute precedence. No plugin or skill can override "Nothing gets done without a task."
2. **User instructions** — Direct human instructions can override framework rules via Tier 2 (situational authorization with logging).
3. **Skills/plugins** — Apply AFTER framework gates are satisfied. A skill that says "invoke before any response" means: after verifying an active task exists. Skills enhance workflows; they do not replace framework governance.

**The practical rule:** Before following ANY skill workflow (brainstorming, TDD, executing-plans, feature-dev, etc.), first ensure a task exists and focus is set. If a skill's instructions conflict with creating a task first, the task wins.

## Task System

### File Structure

```
.tasks/
  active/      # In-progress tasks (e.g., T-042-add-oauth.md)
  completed/   # Finished tasks
  templates/   # Task templates by workflow type
```

### Task File Format

Tasks are Markdown with YAML frontmatter. Use `default.md` template in `.tasks/templates/`.

**Required frontmatter fields:**
- `id`, `name`, `description`, `status`, `workflow_type`, `owner`, `created`, `last_update`

**Body sections:**
- Design Record, Specification Record, Test Files, Updates (chronological log)

### Task Lifecycle

```
Captured → Started Work ↔ Issues → Work Completed
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
| Inception | Explore problem, validate assumptions, go/no-go | Human / Any Agent |

## Enforcement Tiers

| Tier | Description | Bypass | Implementation |
|------|-------------|--------|----------------|
| 0 | Consequential actions (force push, hard reset, rm -rf /, DROP TABLE) | Human approval via `fw tier0 approve` | PreToolUse hook on Bash |
| 1 | All standard operations (default) | Create task or escalate to Tier 2 | PreToolUse hook on Write/Edit |
| 2 | Human situational authorization | Single-use, mandatory logging | Bypass log |
| 3 | Pre-approved categories (health checks, status queries, git-status) | Configured | Spec only |

## Working with Tasks

When starting work (**BEFORE reading code, editing files, or invoking skills**):
1. Check for existing task or create new one
2. Set status to `started-work`
3. Set focus: `fw context focus T-XXX`
4. THEN proceed with implementation (skills, code changes, etc.)
5. Log every action in Updates section with: action, output, context snapshot

When encountering issues:
1. Set status to `issues`
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

### Proactive Level D: Operational Reflection

Not all improvement comes from failures. When you notice a practice repeating ad-hoc across 3+ tasks, consider codifying it:

1. **Mine** episodic memory for evidence of the pattern (how often, what worked, what broke)
2. **Assess** codification value — use inception go/no-go criteria
3. **Codify** if warranted: protocol in CLAUDE.md, templates in agents/, guidelines
4. **Record** as learning + decision + workflow pattern

**Trigger:** An organic question about "how we do X" + 3+ instances in episodic memory.

## Context Budget Management (P-009)

**Context is a finite, non-renewable resource within a session.** Treat it like a battery gauge.

### Commit Cadence Rule
- **Commit after every meaningful unit of work** (not just at session end)
- A "meaningful unit" = completing a subtask, finishing a file, or making a decision
- Each commit is a checkpoint: if context runs out, work up to the last commit is safe
- Target: at least one commit every 15-20 minutes of active work

### Handover Timing Rule
- **Generate handover AFTER work is done, not before**
- Never generate a skeleton handover "to fill in later" — the session may not survive to fill it
- When generating handover: fill in ALL [TODO] sections immediately in the same operation
- For mid-session checkpoints: `fw handover --checkpoint`

### Agent Output Discipline
- When using Task/Agent tools, request concise output (summaries, not raw data)
- Prefer `fw resume quick` over `fw resume status` for routine checks
- Prefer `git log --oneline -5` over `git log -5`

### Emergency Protocol
- If you see a CRITICAL warning from the checkpoint hook:
  immediately run `fw handover --emergency` and commit
- Do NOT try to "finish one more thing" — context exhaustion is sudden, not gradual

## Sub-Agent Dispatch Protocol

When using Claude Code's Task tool to dispatch sub-agents, follow these rules to manage context budget.

### Result Management Rules

**Content generators** (enrichment, file creation, report writing):
- Sub-agent MUST write output to disk (Write tool), NOT return full content
- Return only: file path + one-line summary
- This prevents context explosion from agents returning full file contents

**Investigators/researchers** (codebase exploration, root cause analysis):
- Return structured summaries with findings, NOT raw file contents
- Format: numbered findings with file:line references
- Keep return under 2K tokens per agent

**Auditors/reviewers** (compliance checks, code review):
- Write detailed report to file if >1K tokens
- Return summary + file path to orchestrator
- Include pass/warn/fail counts in summary

### Dispatch Guidelines

| Factor | Rule |
|--------|------|
| Max parallel agents | **5** |
| Token headroom | Leave **40K tokens** free for result ingestion before dispatching |
| When parallel | Tasks are independent, no shared files, no sequential dependency |
| When sequential | Tasks depend on prior results, or editing same files |

### Prompt Template Structure

When dispatching sub-agents, include in the prompt:

1. **Scope**: Exactly what to investigate/produce (one clear deliverable)
2. **Framework context**: Relevant framework structure (task format, episodic template, etc.)
3. **Output format**: How to return results (write to file vs. return summary)
4. **Constraints**: Don't modify files outside scope, don't return raw data
5. **Token hint**: "Keep your response concise — the orchestrator has limited context budget"

## fw CLI (Primary Interface)

The `fw` command is the single entry point for all framework operations. It resolves paths, sets environment variables, and routes to agents.

```bash
fw help              # Show all commands
fw version           # Show version and paths
fw doctor            # Check framework health
fw audit             # Run compliance audit
fw context init      # Initialize session
fw git commit -m "T-XXX: description"
fw handover --commit # Generate and commit handover
fw task create --name "Fix bug" --type build --owner human
```

## Agents

The framework includes agents for common operations. Each agent has a bash script (mechanical) and AGENT.md (intelligence/guidance). All agents can be invoked directly or via `fw`.

### Task Creation Agent

**When to use:** Before starting any new work, create a task.

```bash
fw task create --name "Fix bug" --type build --owner human
fw work-on "Fix bug" --type build    # Create + set focus + start
fw work-on T-XXX                     # Resume existing task
```

### Task Update (with auto-triggers)

**When to use:** To change task status. Auto-triggers healing diagnosis on `issues`, and finalizes tasks on `work-completed`.

```bash
fw task update T-XXX --status issues --reason "API timeout"
fw task update T-XXX --status work-completed
fw task update T-XXX --owner human
```

### Audit Agent

**When to use:** Periodically check framework compliance. Run after completing work or when suspecting drift.

```bash
fw audit
```

**Exit codes:** 0=pass, 1=warnings, 2=failures

### Session Capture Agent

**When to use:** MANDATORY before ending any session or switching context.

Ensure:
- All discussed work has tasks
- All decisions are recorded
- All learnings are captured as practices
- All open questions are tracked

### Git Agent

**When to use:** For all git operations that involve code changes. Enforces task traceability.

```bash
fw git commit -m "T-XXX: Add bypass log"
fw git status
fw git install-hooks
fw git log-bypass --commit abc123 --reason "Emergency hotfix"
fw git log --task T-003
fw git log --traceability
```

### Handover Agent

**When to use:** MANDATORY at end of every session.

```bash
fw handover              # Create handover (manual commit)
fw handover --commit     # Create handover and auto-commit
```

Creates a forward-looking context document in `.context/handovers/` to enable the next session to continue seamlessly.

### Context Agent

**When to use:** To manage the Context Fabric (persistent memory system).

```bash
fw context init                                    # Initialize session
fw context status                                  # Show context state
fw context focus T-XXX                             # Set current focus
fw context add-learning "..." --task T-XXX         # Record a learning
fw context add-pattern failure "..." --task T-XXX  # Record a pattern
fw context add-decision "..." --task T-XXX         # Record a decision
fw context generate-episodic T-XXX                 # Generate episodic summary
```

Manages three memory types:
- **Working Memory** — Session state, current focus, priorities
- **Project Memory** — Patterns, decisions, learnings
- **Episodic Memory** — Condensed task histories

### Healing Agent

**When to use:** When a task encounters issues (status = `issues`). Implements the antifragile healing loop.

```bash
fw healing diagnose T-XXX                          # Get recovery suggestions
fw healing resolve T-XXX --mitigation "..."        # Record resolution
fw healing patterns                                # Show known failure patterns
fw healing suggest                                 # Check all tasks with issues
```

The healing loop:
1. **Classify** — Identifies failure type (code, dependency, environment, design, external)
2. **Lookup** — Searches for similar patterns in patterns.yaml
3. **Suggest** — Recommends recovery using Error Escalation Ladder
4. **Log** — Records resolution as pattern for future learning

### Resume Agent

**When to use:** After context compaction, returning from breaks, or when feeling lost about current state.

```bash
fw resume status     # Full state synthesis
fw resume sync       # Fix stale working memory
fw resume quick      # One-line summary
```

## Session Start Protocol

**Before beginning any work:**
1. Initialize context: `fw context init`
2. Read `.context/handovers/LATEST.md` to understand current state
3. Review the "Suggested First Action" section
4. Set focus: `fw context focus T-XXX`
5. Run `fw metrics` to see project status

**Before ANY implementation (even if a skill says "start now"):**
1. Verify a task exists for the work: `fw work-on "name" --type build` or `fw work-on T-XXX`
2. Confirm focus is set in `.context/working/focus.yaml`
3. THEN invoke skills (brainstorming, TDD, feature-dev, etc.)

This gate is non-negotiable. The PreToolUse hook will block Write/Edit without an active task.

**After context compaction (mid-session recovery):**
1. Run resume: `fw resume status`
2. Sync working memory: `fw resume sync`
3. Continue from recommendations

## Quick Reference

| Action | Command |
|--------|---------|
| **Start work** | `fw work-on "name" --type build` |
| Resume task | `fw work-on T-XXX` |
| Create task | `fw task create` |
| Create with tags | `fw task create --tags "ui,api"` |
| Update task | `fw task update T-XXX --status ...` |
| Commit changes | `fw git commit -m "T-XXX: ..."` |
| Task-aware status | `fw git status` |
| Install git hooks | `fw git install-hooks` |
| Run audit | `fw audit` |
| Show gaps | `fw gaps` |
| Health check | `fw doctor` |
| View metrics | `fw metrics` |
| Predict effort | `fw metrics predict --type build` |
| Initialize session | `fw context init` |
| Set focus | `fw context focus T-XXX` |
| Context status | `fw context status` |
| Add learning | `fw context add-learning "..."` |
| Diagnose issue | `fw healing diagnose T-XXX` |
| Resolve issue | `fw healing resolve T-XXX` |
| Show patterns | `fw healing patterns` |
| Resume state | `fw resume status` |
| Sync working memory | `fw resume sync` |
| Generate handover | `fw handover` |
| Handover + commit | `fw handover --commit` |
| Start inception | `fw inception start "name"` |
| Inception decide | `fw inception decide T-XXX go` |
| Add assumption | `fw assumption add "..." --task T-XXX` |
| Tier 0 approve | `fw tier0 approve` |

## Session End Protocol

**Before ending any session:**
1. Run session capture checklist
2. Create tasks for all uncaptured work
3. Update practices with learnings
4. Generate handover: `fw handover`
5. Fill in the [TODO] sections in the handover document
6. Commit all changes with task references
7. Run `fw metrics` to verify state

**Do not end a session without generating a handover.**
