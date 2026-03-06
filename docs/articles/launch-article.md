---
title: "I built guardrails for AI coding agents — same governance principle, new domain"
published: false
description: "Over 25 years of IT programme governance taught me that effective intelligent action requires four things. I applied that principle to AI coding agents."
tags: ai, claudecode, opensource, devtools
canonical_url: https://dev.to/dimitrigeelen/i-built-guardrails-for-ai-coding-agents-same-governance-principle-new-domain
cover_image:
---

# I built guardrails for AI coding agents — same governance principle, new domain

Over 25 years of working on complex IT programmes I arrived at a principle I now believe is universal: effective intelligent action — whether by a person, a team, or an AI agent — requires four things. Clear direction. Memory of previous reasoning. Awareness of the context you are operating in. And people who are genuinely engaged and capable of acting. Remove any one and the system degrades.

I did not derive this from AI theory. I derived it from watching transitions succeed and fail. At Shell I built the Global Transition Management Framework — 8 assurance areas, 50+ templates, quality gates including Hypercare. Personally led 80+ transitions. Adopted as the global standard, used for 1,000+ transitions globally. Assurance data captured by design. Governable without parallel bureaucracy.

When I started building with agentic coding tools I recognised the same pattern. So I built a framework for it.

## The problem is structural

AI coding agents — Claude Code, Cursor, Copilot, Aider — are capable tools. What they lack is governance. Without it, the same failure modes appear that I have seen in every ungoverned programme:

**No traceability.** Files change with no record of why. No task, no decision trail, no audit history. Three weeks later you are reading a diff with no way to reconstruct the reasoning behind it.

**No memory.** Every session starts from zero. The agent does not know what it did yesterday, what decisions were made, what failed. You re-explain context repeatedly. Or worse — the agent contradicts a decision from the previous session because it has no record of it.

**No authority model.** The agent executes destructive commands — force pushes, file deletions, hard resets — autonomously. Not maliciously. Simply because nothing prevents it.

**No learning loop.** Failures are not recorded. The same mistake recurs across sessions because there is no mechanism to capture what went wrong and surface it next time.

These are not tool-specific problems. They are governance problems. The same ones I spent two decades solving in enterprise IT.

## What I built

The [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework) applies structural governance to AI coding agents. Not guidelines. Not best practices. Enforcement.

The core principle: **nothing gets done without a task.** This is not a convention. It is a gate. The framework intercepts every file modification and blocks it unless an active task exists.

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

This maps directly to the four requirements:

| Requirement | Framework mechanism |
|-------------|-------------------|
| **Clear direction** | Task-first enforcement. Every action has a task with acceptance criteria and verification commands. |
| **Memory of previous reasoning** | Three-layer context fabric — working memory (session), project memory (patterns, decisions), episodic memory (completed task histories). |
| **Awareness of context** | Context budget management monitors token usage, auto-generates handovers before exhaustion. Session continuity across restarts. |
| **Engaged, capable actors** | Tiered authority model. The agent has initiative but not authority. Destructive actions require human approval. |

## How it works in practice

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

The tiered model is deliberate:

| Tier | Scope | Approval |
|------|-------|----------|
| **0** | Destructive commands (`--force`, `rm -rf`, `DROP TABLE`) | Human must approve |
| **1** | All file modifications | Active task required |
| **2** | Situational exceptions | Single-use, logged |
| **3** | Read-only operations | Pre-approved |

This is the same principle as quality gates in transition management. You do not prevent action. You ensure the right checks occur at the right points.

## The healing loop

In transition management, the most valuable assurance data comes from failures. The same applies here.

When a task encounters issues, the framework classifies the failure, searches for similar patterns, and suggests recovery:

```bash
fw healing diagnose T-015            # Classify and suggest
fw healing resolve T-015 --mitigation "Added retry logic"  # Record as pattern
```

The escalation ladder is deliberate: **A** — do not repeat the same failure. **B** — improve technique. **C** — improve tooling. **D** — change ways of working. Over 325 tasks, these patterns compound. The framework learns from its own history.

## Continuous audit

90+ compliance checks run automatically — every 30 minutes, on every push, and on demand:

```bash
$ fw audit

=== SUMMARY ===
Pass: 94
Warn: 5
Fail: 2
```

This is the equivalent of assurance reporting. Not retrospective. Continuous. Drift is detected before it becomes a problem.

## Evidence

I used the framework to build the framework. 325 tasks completed. 96% commit traceability. Every architectural decision recorded with rationale and rejected alternatives. The framework is its own proof of concept.

It is provider-neutral. Full structural enforcement with Claude Code via hooks. CLI governance with Cursor and any other agent. The `fw` CLI is the single entry point — same pattern as having one programme office, not five.

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

Open source under Apache 2.0: [github.com/DimitriGeelen/agentic-engineering-framework](https://github.com/DimitriGeelen/agentic-engineering-framework)

## The principle holds

Effective intelligent action requires clear direction, memory, context awareness, and capable engaged actors. This was true for Shell's global transitions. It is true for AI coding agents. The domain changed. The principle did not.

---

*I am interested in how others are approaching governance for AI coding agents. If you have experience — or questions — I would welcome the conversation on [GitHub Discussions](https://github.com/DimitriGeelen/agentic-engineering-framework/discussions).*
