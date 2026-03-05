# AGENTS.md — Agentic Engineering Framework

> Standard agent instruction file (AAIF/Linux Foundation convention).
> For Claude Code-specific integration, see `CLAUDE.md`.
> For the full provider-neutral guide, see `FRAMEWORK.md`.

## Identity

- **Name:** Agentic Engineering Framework
- **Purpose:** Governance framework for AI coding agents — enforces task traceability, structural gates, session continuity, and audit trails.
- **Version:** 1.0.0

## Core Principle

**Nothing gets done without a task.** This is enforced structurally, not by agent discipline.

## Rules

1. **Create a task before editing files.** Use `fw work-on "description" --type build` to create and focus.
2. **Every commit references a task.** Format: `T-XXX: description`. Enforced by commit-msg hook.
3. **Never bypass structural gates.** If a gate blocks you, stop and ask the human.
4. **Destructive commands require approval.** Force push, hard reset, `rm -rf`, DROP TABLE → `fw tier0 approve`.
5. **Generate a handover before ending.** Use `fw handover --commit` to preserve session context.

## Authority Model

```
Human     → SOVEREIGNTY  → Can override anything
Framework → AUTHORITY    → Enforces rules, checks gates
Agent     → INITIATIVE   → Can propose, never decides
```

## Quick Commands

| Action | Command |
|--------|---------|
| Start work | `fw work-on "name" --type build` |
| Commit | `fw git commit -m "T-XXX: description"` |
| Run audit | `fw audit` |
| Health check | `fw doctor` |
| End session | `fw handover --commit` |
| Check status | `fw context status` |

## Enforcement Tiers

| Tier | Scope | Bypass |
|------|-------|--------|
| 0 | Destructive commands | Human approval via `fw tier0 approve` |
| 1 | All file modifications | Create a task first |
| 2 | Situational exceptions | Single-use, mandatory logging |
| 3 | Read-only operations | Pre-approved |

## Memory System

The framework maintains three memory layers:
- **Working memory** (`.context/working/`) — Current session state
- **Project memory** (`.context/project/`) — Patterns, decisions, learnings
- **Episodic memory** (`.context/episodic/`) — Completed task histories

## File Structure

```
bin/fw              CLI entry point
agents/             Agent scripts (audit, context, git, handover, healing, task-create)
.tasks/active/      In-progress tasks
.tasks/completed/   Finished tasks
.context/           Memory system
.fabric/            Component topology map
```

## Getting Started

```bash
fw doctor           # Check framework health
fw context init     # Initialize session
fw work-on "Fix the bug" --type build   # Create task + start
# ... do work ...
fw git commit -m "T-XXX: Fix the bug"   # Commit with traceability
fw handover --commit                     # End session
```

For the complete operating guide, see [FRAMEWORK.md](FRAMEWORK.md).
