---
title: "I built guardrails for Claude Code — here's what I learned"
published: false
description: "After 325 tasks with AI coding agents, I built a governance framework that enforces task traceability, blocks destructive commands, and preserves context across sessions. Here's what went wrong without it — and what changed."
tags: ai, claudecode, opensource, devtools
canonical_url: https://dev.to/dimitrigeelen/i-built-guardrails-for-claude-code-heres-what-i-learned
cover_image:
---

# I built guardrails for Claude Code — here's what I learned

I've been using Claude Code daily for six months. It's the most productive tool I've ever used — and also the most dangerous.

Not dangerous like "it writes bad code." Dangerous like: it force-pushed to main at 2 AM. It deleted files without telling me why. It lost all context when the session ended, so the next session started from zero and made the same mistakes again.

After the third time an agent made a destructive decision I hadn't approved, I stopped blaming the agent. The problem wasn't Claude. The problem was me — I had given a power tool to an autonomous system with no structural constraints.

So I built them.

## The problem nobody talks about

Everyone's excited about AI writing code faster. Nobody's talking about what happens when AI agents operate on your codebase *without governance.*

Here's what I kept running into:

**No traceability.** Files changed with no record of *why*. No task, no ticket, no context. Three weeks later, I'm reading a diff going "who wrote this and what were they thinking?" The answer was: an AI agent, and there's no way to find out.

**Context amnesia.** Every session starts from zero. The agent doesn't know what it did yesterday, what decisions were made, what failed, or what's in progress. You explain the same context over and over. Or worse — the agent makes a decision that contradicts one you made last session, because it has no memory of it.

**Autonomous destruction.** `git push --force`. `rm -rf`. Dropping database tables. Not maliciously — just... autonomously. The agent decided it was the right move. Nobody asked me.

**Invisible technical debt.** Failures happen, but nobody records them. The same mistake gets repeated across sessions because there's no learning loop. The agent doesn't know it already tried approach X and it failed.

This isn't a Claude Code problem. This is an *any AI agent* problem. Cursor, Copilot, Aider, Devin — they all share the same gap: the agent has capability without governance.

## What I built

The [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework) is a governance layer for AI coding agents. Not guidelines. Not "best practices." Structural enforcement.

The core principle is simple: **nothing gets done without a task.**

This is enforced mechanically. Try to edit a file without an active task? Blocked:

```
Agent tries to edit a file
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
    Edit proceeds ✓        Every commit traces back to a task
```

Not honor-system governance. The framework blocks the action *before it happens* using pre-operation hooks.

### Before and after

**Before (raw Claude Code):**

```bash
# Agent just... does stuff
echo "some new feature" >> app.py
git add . && git commit -m "updates"
git push --force origin main  # 💀
```

No task. No traceability. Destructive command executed without approval.

**After (with framework):**

```bash
# Start with a task
fw work-on "Add user authentication" --type build

# Agent works within governance
# Every file edit requires an active task (enforced by hooks)
# Every commit references the task
fw git commit -m "T-042: Add JWT validation middleware"

# Destructive commands are blocked
$ git push --force
══════════════════════════════════════════════════════════
  TIER 0 BLOCK — Destructive Command Detected
══════════════════════════════════════════════════════════
  Risk: FORCE PUSH overwrites remote history
  To proceed: fw tier0 approve (requires human)
══════════════════════════════════════════════════════════

# Session ends with context preserved
fw handover --commit
```

Every action is traced. Destructive commands require human approval. Context survives between sessions.

## The four things that actually matter

After 325 tasks, here's what governance boils down to:

### 1. Task-first enforcement

Every file modification requires an active task. Not as a convention — as a structural gate. The `PreToolUse` hook runs before every Write, Edit, or Bash command and checks whether a task exists and has focus set.

This means every commit traces back to a task. Every task has acceptance criteria. Every decision is recorded. When you look at a file change six months later, you can trace it back to the task that caused it, the criteria that defined it, and the decision that shaped it.

### 2. Tiered approval for destructive actions

Not all commands are equal. The framework classifies them:

| Tier | What | Approval |
|------|------|----------|
| **0** | `--force`, `rm -rf`, `DROP TABLE` | Human must approve |
| **1** | All file modifications | Active task required |
| **2** | Situational exceptions | Single-use, logged |
| **3** | Read-only (status, health) | Pre-approved |

The Tier 0 gate catches the commands that keep me up at night. Force pushes, hard resets, deleting directories. The agent cannot execute these without my explicit sign-off.

### 3. Session continuity

When a session ends (or context runs out), the framework generates a handover document: what was done, what's in progress, what decisions were made, what to do next. The next session picks up where the last one left off.

```bash
# End of session
fw handover --commit

# Next session
fw resume
# → Shows: last session state, active tasks, suggested first action
```

No more explaining the same context twice. No more contradicting yesterday's decisions. The framework remembers so the agent doesn't have to.

### 4. Continuous audit

90+ compliance checks run automatically — every 30 minutes, on every push, and on demand:

```bash
$ fw audit

=== SUMMARY ===
Pass: 94
Warn: 5
Fail: 2

=== PRIORITY ACTIONS ===
1. Fill handover TODOs
2. Review pending tasks
```

The audit catches drift before it becomes a problem: unchecked acceptance criteria, missing task references in commits, stale handovers, bypass log entries without justification.

## What surprised me

**The framework governs itself.** I used the framework to build the framework. 325 tasks completed, 96% commit traceability, every architectural decision recorded. It's its own proof of concept.

**Context budget management was the sleeper feature.** AI agents have a finite context window. When it runs out, they lose everything. The framework monitors token usage and auto-generates a handover before context exhaustion. This alone saved me dozens of lost sessions.

**The healing loop compounds.** When a task fails, the framework records the failure pattern. The next time something similar happens, it surfaces the previous resolution. After 325 tasks, the pattern library is genuinely useful — the framework learns from its own mistakes.

**Governance doesn't slow you down.** Running `fw work-on "Fix the bug"` takes 2 seconds. But it gives you: a task file, acceptance criteria, verification commands, episodic memory when it's done, and a commit trail back to the decision. That's not overhead — that's infrastructure.

## Try it

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/main/install.sh | bash

# Or via Homebrew
brew tap DimitriGeelen/agentic-fw && brew install fw

# Initialize in your project
cd your-project && fw init

# Start your first governed task
fw work-on "Set up project structure" --type build
```

The framework works with Claude Code (full enforcement via hooks), Cursor (`.cursorrules` + CLI), and any other CLI-capable agent (generic mode).

It's open source under Apache 2.0: [github.com/DimitriGeelen/agentic-engineering-framework](https://github.com/DimitriGeelen/agentic-engineering-framework)

## The takeaway

AI coding agents are incredible. They're also unsupervised autonomous systems operating on your most valuable asset — your codebase.

You wouldn't give a contractor access to your production servers without governance. Don't give an AI agent access to your codebase without it either.

The agent has capability. The framework gives it accountability.

---

*If you're using Claude Code, Cursor, or any AI coding agent daily, I'd love to hear how you're handling governance. What goes wrong? What works? Drop a comment or open a Discussion on [GitHub](https://github.com/DimitriGeelen/agentic-engineering-framework/discussions).*
