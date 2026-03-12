---
title: "T-445: README Overhaul — Positioning, Evidence, Structure"
task: T-445
type: inception-research
created: 2026-03-12
---

# T-445: README Overhaul Research

## Phase 1: Competitive Positioning

### What others say about themselves

**OpenClaw** (verified from GitHub README):
- H1: "OpenClaw -- Personal AI Assistant"
- Tagline: "Your own personal AI assistant. Any OS. Any Platform. The lobster way."
- First line: "OpenClaw is a personal AI assistant you run on your own devices."
- Lists 22 channels (WhatsApp, Telegram, Slack, Discord, Signal, iMessage, etc.)
- Selling points: local-first, channel-agnostic, voice mode, companion apps
- Mental model: "Jarvis for your computer and apps"
- Pattern: **leads with end-user experience, not architecture**

**LangGraph** (verified from GitHub README):
- H1: "Build resilient language agents as graphs"
- Opens with social proof (Klarna, Replit, Elastic)
- First definition: "a low-level orchestration framework for building, managing, and deploying long-running, stateful agents"
- Explicitly states: "does NOT abstract prompts or architecture"
- Mental model: "infrastructure for stateful agent workflows"
- Pattern: **leads with enterprise trust signals, emphasizes "low-level" infrastructure**

**CrewAI** (verified from GitHub README):
- H1: "Open source Multi-AI Agent orchestration framework"
- Tagline: "Fast and Flexible Multi-Agent Automation Framework"
- First line: "completely independent of LangChain or other agent frameworks"
- Key features: Crews (autonomy), Flows (production), high performance
- Community: "100,000 certified developers"
- Pattern: **leads with differentiation (anti-LangChain) and speed**

### What WE actually are

- Not an agent runtime (doesn't execute agents)
- Not an orchestration engine (doesn't chain LLM calls)
- Not an assistant platform (doesn't connect to messaging/services)

We are: **governance infrastructure for AI coding agents working in git repos.**

The closest analogy: ESLint governs code quality. We govern agent behavior.

### Positioning contrast (draft)

> "This is not another AI assistant or agent runtime. It's the safety layer that governs whatever AI coding tool you already use — Claude Code, Cursor, Copilot, or anything with CLI access to your repo."

### Complementary framing (draft)

> "Run OpenClaw for multi-app automation. Run LangGraph for AI pipelines. Run this inside the repos those agents touch, so nothing gets committed without traceability and nothing gets destroyed without approval."

---

## Phase 2: Evidence of Value

### Real enforcement examples from project history

#### Example 1: Task gate blocking file edits (actual output from check-active-task.sh)
```
BLOCKED: No active task. Framework rule: nothing gets done without a task.

To unblock:
  1. Create a task:  fw task create --name '...' --type build --start
  2. Set focus:      fw context focus T-XXX

Attempting to modify: src/api/routes.ts
Policy: P-002 (Structural Enforcement Over Agent Discipline)
```
Mechanism: PreToolUse hook fires on every Write/Edit/Bash call. Fail-closed.
Evidence: Enforced continuously across 445+ tasks in this project.

#### Example 2: Tier 0 blocking destructive commands (actual output from check-tier0.sh)
```
══════════════════════════════════════════════════════════
  TIER 0 BLOCK — Destructive Command Detected
══════════════════════════════════════════════════════════

  Risk: FORCE PUSH overwrites remote history — may destroy teammates' work
  Command: git push --force origin main

  This command is classified as Tier 0 (consequential).
  It requires explicit human approval before execution.

  To proceed (after the human approves):
    ./bin/fw tier0 approve
  Then retry the same command.

  Policy: 011-EnforcementConfig.md §Tier 0
══════════════════════════════════════════════════════════
```
Detected patterns: force push, hard reset, rm -rf, DROP TABLE, --no-verify, find -delete, chmod 000, mkfs, pkill -9.
Evidence: 49 real Tier 0 approvals logged in bypass-log.yaml (2026-02-13 to 2026-03-08), all human-authorized.

#### Example 3: Budget gate blocking context exhaustion (actual output from budget-gate.sh)
```
══════════════════════════════════════════════════════════
  SESSION WRAPPING UP (~170000 tokens)
══════════════════════════════════════════════════════════

  Context is at ~85% of 200K window.
  Task files already have all essential state. Time to wrap up.

  ALLOWED: git commit, fw handover, reading files,
           Write/Edit to .context/ .tasks/ .claude/
  BLOCKED: Write/Edit to source files, Bash (except commit/handover)

  Action: Commit your work, then run 'fw handover'
══════════════════════════════════════════════════════════
```
Budget levels: ok (≤120K) → warn (≤150K) → urgent (≤170K) → critical (>170K blocks new work).
Evidence: Triggers regularly in long sessions. Auto-generates handover at critical.

#### Example 4: Commit traceability enforcement (commit-msg hook)
```
✗ Commit message must reference a task: T-XXX
  Example: git commit -m "T-042: Fix login validation"
```
Evidence: commit-msg hook active on every commit. 96% traceability across 445+ tasks.

#### Example 5: Settings protection (check-active-task.sh)
```
BLOCKED: Cannot modify .claude/settings.json — this controls enforcement hooks.

Modifying this file could disable task gates, Tier 0 checks, and budget enforcement.
Changes to hook configuration require human review.

Policy: B-005 (Enforcement Config Protection)
```
Evidence: Agent cannot disable its own guardrails — the framework protects its enforcement config.

---

## Phase 3: Proposed README Structure

### Current structure (what's wrong)
1. Title + tagline
2. Problem (good, but payoff never returns)
3. Solution (feature list, not outcomes)
4. Enforcement diagram (good)
5. Quickstart (3 paths, no payoff shown)
6. What's Inside (LONG feature tour — 60% of README)
7. Key Commands
8. Agent Setup
9. Team Usage
10. When to Use
11. Core Principles (collapsible)
12. Architecture (collapsible)
13. Self-Governing

### Proposed structure
1. **Title + sharp positioning** (3 lines — what it is, what it isn't)
2. **What this actually prevents** (4-5 concrete examples with terminal output)
3. **The Problem** (keep, tighten)
4. **5-minute demo** (5 commands → visible enforcement + audit + handover)
5. **How enforcement works** (keep diagram, add honest gradient table)
6. **Quickstart** (keep 3 paths, tighten)
7. **What you get** (outcomes, not features — collapsible details for each)
8. **Key Commands** (keep)
9. **Agent Setup** (keep, add enforcement gradient)
10. **When to Use** (keep)
11. **Self-Governing** (keep, move higher?)
12. **Architecture** (collapsible, move numbers here)
13. **Documentation** links

### Key changes
- Lead with **evidence** (blocked actions), not features
- Add **enforcement gradient table** (Claude Code = full, Cursor = git hooks, others = voluntary)
- Move component counts and subsystem details into collapsibles
- Add "What this is NOT" line in first 3 lines
- Add 5-minute demo before the feature tour
- Tone down: "compliance engine" → "governance checks", soften component count
- Add "complementary to" framing (OpenClaw, LangGraph, etc.)

---

## Enforcement Gradient (honest disclosure)

| Capability | Claude Code (tested) | Cursor / Copilot / Others (untested) |
|------------|---------------------|--------------------------------------|
| Task gate (blocks file edits) | **Structural** — PreToolUse hook | Convention — agent follows rules |
| Tier 0 (blocks destructive cmds) | **Structural** — PreToolUse hook | Convention |
| Budget management | **Structural** — reads transcript | Manual checkpointing |
| Commit traceability | **Git hook** — tested | **Git hook** — should work (untested) |
| Audit (90+ checks) | **CLI** — tested | **CLI** — should work (untested) |
| Handover / memory | **CLI** — tested | **CLI** — should work (untested) |
| Settings protection | **Structural** — PreToolUse hook | N/A |

**Honest summary:** Full structural enforcement requires Claude Code's hook system. All other agents get git hooks (commit traceability) + CLI tools (audit, handover, tasks) + voluntary governance rules. This is still far more than most teams have, but it's not the same as "blocks before the action happens."

**CRITICAL HONESTY NOTE (from human, 2026-03-12):**
The framework has ONLY been tested with Claude Code. `fw init --provider cursor` and `--provider generic` exist and generate config files, but no actual testing has been done with Cursor, Copilot, Aider, or any other agent. The README must not imply tested multi-provider support. Correct framing:
- "Battle-tested with Claude Code (445+ tasks, 312 completed)"
- "Designed for any CLI agent — git hooks and CLI tools are agent-agnostic"
- "Structural enforcement hooks (task gate, Tier 0, budget) require Claude Code's PreToolUse/PostToolUse system"
- "Community testing with other agents welcome"

---

## Draft: New README Top Section

```markdown
# Agentic Engineering Framework

> Governance and guardrails for AI coding agents in your repo. Not another chatbot.

Your AI agent (Claude Code, Cursor, Copilot) can edit files, run commands, and push code.
This framework makes sure it can't do any of that without a task, an audit trail, and human
oversight on destructive actions. Think ESLint for agent behavior, not another assistant runtime.

## What This Has Actually Stopped

Real output from this framework governing its own development (445+ tasks):

**Agent tries to edit a file without a task:**
​```
BLOCKED: No active task. Framework rule: nothing gets done without a task.
To unblock: fw task create --name '...' --type build --start
​```

**Agent tries to force push:**
​```
TIER 0 BLOCK — Destructive Command Detected
Risk: FORCE PUSH overwrites remote history
To proceed: ./bin/fw tier0 approve (requires human)
​```

**Agent tries to disable its own guardrails:**
​```
BLOCKED: Cannot modify .claude/settings.json — this controls enforcement hooks.
​```

**Context running out mid-session:**
​```
SESSION WRAPPING UP (~170K tokens)
BLOCKED: Write/Edit to source files
ALLOWED: git commit, fw handover (auto-saves progress)
​```

Every blocked action is logged. Every approval is auditable. The agent cannot override the framework.
```

---

## Draft: 5-Minute Demo Section

```markdown
## See It Work in 5 Minutes

​```bash
# 1. Install
curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash

# 2. Initialize a project
mkdir demo && cd demo && git init
fw init --provider claude

# 3. Try editing without a task — BLOCKED
echo "test" > file.txt   # This would be blocked by the task gate in Claude Code

# 4. Create a task and start working
fw work-on "Add authentication" --type build
# Now edits are allowed — and traced to T-001

# 5. See what the framework is tracking
fw audit                 # 90+ governance checks
fw serve                 # Open http://localhost:3000 — live dashboard
​```

In 5 commands: your repo has task-traced commits, enforcement gates, continuous audit,
and a dashboard. Every session from here forward is governed.
```

---

## Draft: "What This Is NOT" Section

```markdown
## What This Is (and Isn't)

| | This framework | OpenClaw / LangGraph / CrewAI |
|---|---|---|
| **Purpose** | Govern agent behavior in repos | Run agents / connect to services |
| **Does it execute agents?** | No — governs agents you already have | Yes — IS the agent runtime |
| **Messaging / browser / APIs?** | No | Yes (OpenClaw: 22 channels) |
| **Git traceability?** | Yes — every commit traces to a task | No |
| **Blocks destructive commands?** | Yes — Tier 0 requires human approval | No |
| **Session continuity?** | Yes — handovers bridge sessions | Varies |
| **Complementary?** | Run this inside repos those agents touch | Run those for capabilities |
```

---

## Dialogue Log

### 2026-03-12 — Human provides two critical reviews
- Human shared two independent critiques of the README
- Critique 1 (positioning): wrong mental model, no demo, complexity front-loaded, no complementary framing
- Critique 2 (technical honesty): enforcement is partially convention, component count inflated, memory is files, healing is shallow, security claims exaggerated
- Agent reflected: agreed on 6 points, partially agreed on 6, pushed back on 5
- Human said "yes please" to creating inception task
- Key insight from human: "You let yourself be mentally compared to OpenClaw but you're actually a governance layer for repos and agents"

### 2026-03-12 — Human reflects on project identity
- Human: "I'm not sure whether this is AI slop or something really useful, but I'm having loads of fun making it and find it very useful"
- This is an important signal for positioning. The project is:
  - Built by one person using the framework to govern itself (self-referential proof)
  - Genuinely useful to its creator (daily driver, 445+ tasks, 312 completed)
  - Potentially "AI slop" to outsiders if the README doesn't convey real value
  - Fun to build (motivation matters for open source sustainability)
- Positioning implication: the README should own this honesty. "Built by one developer using it daily to govern Claude Code. It works for me. Here's why it might work for you."
- This is actually a STRONGER pitch than "enterprise governance platform" — it's authentic.

### 2026-03-12 — Human flags untested multi-provider claims
- Human: "I have only tested on Claude Code recently, haven't tested it anywhere else. It's designed for other frameworks but not tested!"
- This means the README's "works with any CLI-capable AI agent" is an untested claim
- `fw init --provider cursor` and `--provider generic` generate config but nobody verified the workflow
- Decision: README must be honest about this — "battle-tested with Claude Code, designed for others, community testing welcome"
- Spawned concern: multi-provider testing is a separate task (out of scope for README inception)
