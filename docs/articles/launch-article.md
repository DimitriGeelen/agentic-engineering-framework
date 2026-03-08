---
title: "I built guardrails for AI coding agents — same governance principle, new domain"
published: false
description: "Over 25 years of IT programme governance taught me that effective intelligent action requires five things. I applied that principle to AI coding agents."
tags: ai, claudecode, opensource, devtools
canonical_url: https://dev.to/dimitrigeelen/i-built-guardrails-for-ai-coding-agents-same-governance-principle-new-domain
cover_image:
---

# I built guardrails for AI coding agents — same governance principle, new domain

Over 25 years of working on complex IT programmes I arrived at a principle I now believe is universal: effective intelligent action — whether by a person, a team, or an AI agent — requires five things. Clear direction. Awareness of context — what happened before, what was decided, what failed. Awareness of resource constraints. Awareness of what your actions will affect downstream. And people who are genuinely engaged and capable of acting. Remove any one and the system degrades.

I did not derive this from AI theory. I derived it from watching transitions succeed and fail. At Shell I built a governance framework for IT transitions — quality gates, assurance areas, structured handovers. Shell adopted it as the global standard. It has been used for over 1,000 transitions worldwide.

When I started building with agentic coding tools I recognised the same failure modes. So I built a framework for that too.

## The problem is structural

AI coding agents — Claude Code, Cursor, Copilot, Aider — are capable tools. What they lack is governance. Without it, the same failure modes appear that I have seen in every ungoverned programme:

**No traceability.** Files change with no record of why. No task, no decision trail, no audit history. Three weeks later you are reading a diff with no way to reconstruct the reasoning behind it.

**No memory.** Every session starts from zero. The agent does not know what it did yesterday, what decisions were made, what failed. You re-explain context repeatedly. Or worse — the agent contradicts a decision from the previous session because it has no record of it.

**No risk awareness.** The agent may ask before a force push, but it has no model for understanding why that action is risky, what it affects, or who should approve it. There is no structured authority model — no distinction between what the agent may decide and what requires human approval.

**No learning loop.** Failures are not recorded. The same mistake recurs across sessions because there is no mechanism to capture what went wrong and surface it next time.

These are not tool-specific problems. They are governance problems. The same ones I spent two decades solving in enterprise IT.

## What I built

The [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework) applies structural governance to AI coding agents — not guidelines or best practices, but mechanical enforcement.

The core principle: **nothing gets done without a task.** This is enforced as a gate, not a convention. With Claude Code, the framework intercepts every file modification and blocks it unless an active task exists.

```
Agent attempts to edit a file
    │
    ▼
┌─────────────────────┐
│  Task gate (Tier 1)  │──── No active task? → BLOCKED
└─────────────────────┘
    │ ✓ Task exists
    ▼
┌─────────────────────┐
│  Budget gate         │──── Context > 75%? → BLOCKED (auto-handover)
└─────────────────────┘
    │ ✓ Budget OK
    ▼
    Edit proceeds           Every commit traces to a task
```

This maps directly to those five requirements:

| Requirement | Framework mechanism |
|-------------|-------------------|
| **Clear direction** | Task-first enforcement. Every action has a task with acceptance criteria and verification commands. |
| **Awareness of context** | Context Fabric (the framework's memory subsystem) — three layers of persistent memory (working, project, episodic). The agent recalls prior decisions, learned patterns, and failure resolutions across sessions. |
| **Awareness of context window** | Context budget management tracks resource consumption and triggers automatic handover before the agent loses coherence. |
| **Awareness of impact** | Component Fabric — a live structural map of the codebase. Before changing a file, the agent queries what depends on it and assesses downstream impact. |
| **Engaged, capable actors** | Tiered authority model. The agent has initiative but not authority. Destructive actions require human approval. |

Tasks flow through a visible lifecycle — Captured, In Progress, Issues, Completed — tracked on a Kanban board that surfaces what needs attention:

![Task Board](https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/docs/screenshots/watchtower-tasks-board.png)
*Tasks are not hidden in text files. They are visible, trackable, and auditable.*

## How it works in practice

Here is what this looks like in a terminal.

**Before governance:**

```bash
# Agent operates without constraints
git add . && git commit -m "updates"
git push --force origin main
```

No task reference. No traceability. Destructive command executed without approval.

**After governance:**

```bash
# Work starts with a task
fw work-on "Add JWT validation" --type build

# Every commit references the task
fw git commit -m "T-042: Add JWT validation middleware"

# Destructive commands are intercepted
$ git push --force
══════════════════════════════════════════════════════════
  TIER 0 BLOCK — Destructive Command Detected
══════════════════════════════════════════════════════════
  Risk: FORCE PUSH overwrites remote history
  To proceed: fw tier0 approve (requires human approval)
══════════════════════════════════════════════════════════

# Session ends with context preserved for the next
fw handover --commit
```

That Tier 0 block is not a warning. It is a gate. Which leads to the question: who has authority over what?

## The authority model

In transition management, the single most common failure mode is unclear accountability. Who decides? Who approves? Who can override?

The framework codifies this:

```
Human     → SOVEREIGNTY  → Can override anything, is accountable
Framework → AUTHORITY    → Enforces rules, checks gates, logs everything
Agent     → INITIATIVE   → Can propose, request, suggest — never decides
```

The agent may choose which task to work on. It may choose an implementation approach. It may not bypass a structural gate, complete a human-owned task, or execute a destructive command without approval. Initiative is not authority. This distinction prevents the most dangerous failure mode in agentic systems: the agent making consequential decisions that no one reviewed.

The tiered approval model enforces this mechanically:

| Tier | Scope | Approval |
|------|-------|----------|
| **0** | Destructive commands (`--force`, `rm -rf`, `DROP TABLE`) | Human must approve |
| **1** | All file modifications | Active task required |
| **2** | Situational exceptions | Single-use, logged |
| **3** | Read-only operations | Pre-approved |

You do not prevent action. You ensure the right checks occur at the right points.

The gates handle enforcement. But what happens to the knowledge the agent builds up during a session?

## Context Fabric — memory across sessions

The most expensive failure in agent-assisted development is not a bug. It is lost context. An agent works for an hour, the session ends, and the next session starts from zero. Decisions are re-made. Mistakes are repeated. The reasoning trail disappears.

The Context Fabric solves this with three layers of persistent memory:

- **Working memory** — current session state, active focus, pending actions
- **Project memory** — patterns, decisions, and learnings that persist across all sessions. When the agent encounters a failure it has seen before, the resolution is already there
- **Episodic memory** — condensed histories of every completed task, auto-generated at completion. What was done, what was decided, what was learned

Semantic search across all three layers means the agent can recall relevant context by meaning:

```bash
fw recall "authentication timeout pattern"
# → Returns: L-037 (from T-118), FP-003 (from T-089), episodic T-042
```

Without this, every session is a cold start. With it, the framework accumulates institutional knowledge — the same way it does in a well-run organisation.

![Watchtower Dashboard](https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/docs/screenshots/watchtower-dashboard.png)
*The Watchtower dashboard surfaces tasks awaiting human verification, work direction, and system health in one view.*

## Component Fabric — structural awareness

Memory tells the agent what happened before. But it also needs to know what it is about to affect. In a programme, this is stakeholder impact analysis. In a codebase, it is dependency tracking.

The Component Fabric is a live topology map of every significant file in the project. 126 components across 12 subsystems, with 175 dependency edges tracked. Each component has a YAML card recording what it does, what it depends on, and what depends on it.

```bash
# What depends on this file?
$ fw fabric deps agents/git/git.sh
  → 6 dependents: commit.sh, hooks.sh, ...

# What will this commit break downstream?
$ fw fabric blast-radius HEAD
  → 3 files changed, 12 downstream components potentially affected

# Detect unregistered files (structural drift)
$ fw fabric drift
  → 2 unregistered files, 0 orphaned cards
```

The difference is between modifying a file without knowing its dependents and modifying it with a verified understanding of downstream impact.

![Component Fabric — dependency graph](https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/docs/screenshots/watchtower-fabric-graph.png)
*Interactive dependency graph — filter by subsystem, switch layouts, click nodes to inspect relationships.*

## The healing loop

Context and structural awareness handle the forward path. But what about failures?

When a task encounters issues, the framework classifies the failure, searches for similar patterns, and suggests recovery:

```bash
fw healing diagnose T-015            # Classify and suggest
fw healing resolve T-015 --mitigation "Added retry logic"  # Record as pattern
```

The escalation ladder is deliberate: **A** — do not repeat the same failure. **B** — improve technique. **C** — improve tooling. **D** — change ways of working. Over 312 completed tasks, these patterns accumulate. Resolutions from prior failures are surfaced when similar issues recur.

## Continuous audit

The healing loop handles individual failures. To catch systemic drift, the framework audits itself. 90+ compliance checks run automatically — every 30 minutes, on every push, and on demand:

```bash
$ fw audit

=== SUMMARY ===
Pass: 94
Warn: 5
Fail: 2
```

This is the equivalent of assurance reporting. Not retrospective. Continuous. Drift is detected before it becomes a problem.

## Evidence

I used the framework to build the framework. 312 tasks completed. 96% commit traceability across the full task history. Every architectural decision recorded with rationale and rejected alternatives.

A typical commit log:

```
27e8ed1 T-332: Research awesome list targets — 5 lists with ready-to-submit entries
d8cd81e T-326: Complete README rewrite — all 17 agent ACs + 5 screenshots verified
2138d17 T-329: Draft launch article — I built guardrails for Claude Code
25ba46e T-328: Add NOTICE file for Apache 2.0 attribution preservation
c6287d4 T-328: Add Apache 2.0 license (Geelen & Company) and update README
```

Every commit traces to a task. Every task has acceptance criteria that were verified before completion. Every decision is recorded with rationale. The framework is its own proof of concept.

The framework is built with and tested against Claude Code — that is where the full structural enforcement lives, via hooks that intercept every file modification, every destructive command, every context threshold. But the design is provider-neutral. Cursor gets `.cursorrules` generation and CLI governance. Copilot, Aider, Devin — any agent that can follow a system prompt and run shell commands gets the same `fw` CLI. One governance interface, regardless of which agent is executing.

![Task detail](https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/docs/screenshots/watchtower-task-detail.png)
*A task is a rich artifact — acceptance criteria, verification commands, decisions, and episodic summary. Not a one-line ticket.*

## Where it stands

I use this daily for real work. 312 tasks completed. The governance model holds. The context continuity works. The healing loop genuinely improves over time. I would not go back to ungoverned agent development.

That said, the framework is alpha. It is under active development. There are bugs. There are rough edges. I have taken steps to make it usable for others — install script, Homebrew tap, documentation, GitHub Action — but it has not been tested by a wide audience yet.

If that sounds interesting, try it. If you find bugs, report them. If you see improvements, contribute. This is not a finished product — it is a working framework heading in the right direction.

## Try it

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash

# Or via Homebrew (macOS/Linux)
brew install DimitriGeelen/agentic-fw/agentic-fw

# Initialize in your project
cd your-project && fw init

# Start your first governed task
fw work-on "Set up project structure" --type build
```

Open source under Apache 2.0: [github.com/DimitriGeelen/agentic-engineering-framework](https://github.com/DimitriGeelen/agentic-engineering-framework)

## The principle holds

Effective intelligent action requires clear direction, context awareness, awareness of constraints and impact, and capable engaged actors. This was true for Shell's global transitions. It is true for AI coding agents. The domain changed. The principle did not.

---

*I am interested in how others are approaching governance for AI coding agents. If you have experience — or questions — I would welcome the conversation on [GitHub Discussions](https://github.com/DimitriGeelen/agentic-engineering-framework/discussions).*
