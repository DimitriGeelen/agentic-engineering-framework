You are writing a deep-dive article about a subsystem in the Agentic Engineering Framework.
Follow the exact structure and tone of the style reference below.

## STYLE REFERENCE (follow this structure exactly)

# Deep Dive #1: The Task Gate

## Title

Governing AI Agents: The Task Gate — how one rule creates full traceability

## Post Body

**Accountability begins with a record of intent.**

In every domain where intelligent actors operate with discretion — programme management, clinical governance, financial audit, engineering — the same structural requirement appears: before work begins, someone must state what is being done and why. A programme manager opens a work order. A surgeon logs a procedure. An auditor creates an engagement file. The mechanism varies. The principle does not. Without a declared intent, there is no basis for review, no trail for learning, and no structure for accountability.

The same principle applies to AI coding agents, and it is precisely the one most setups omit. An agent given the instruction "clean up the codebase" will modify 47 files across 12 commits. It will do so competently. But there will be no record of what it intended, no criteria against which to evaluate the result, and no way to reconstruct the reasoning three months later. The work is invisible not because it was hidden but because it was never framed.

I built one rule and enforced it structurally: **nothing gets done without a task.** Not as a convention. Not as a prompt instruction the agent can ignore when context fills up. As a mechanical gate that blocks file edits until a task exists.

### How the gate works

The Agentic Engineering Framework installs a PreToolUse hook in Claude Code. Every time the agent attempts to write or edit a file, the hook checks two things: does `.context/working/focus.yaml` contain an active task ID, and does that task file exist in `.tasks/active/`. If either check fails, the edit is blocked.

```bash
# Without a task — blocked
$ claude "clean up the codebase"
# TASK GATE: No active task. Create one with: fw work-on "Clean up codebase" --type refactor

# With a task — allowed
$ fw work-on "Clean up module imports" --type refactor
# Task T-042 created, focus set. Edits are now allowed.
```

Every file change traces to a task. Every task has acceptance criteria. Every commit references a task ID. The reasoning chain is reconstructable.

### Why a prompt instruction is not enough

I arrived at structural enforcement after watching the behavioral alternative fail. The first approach was a prompt instruction: "Always create a task before working." It lasted about a day.

The failure mode was instructive. I gave the agent a specification task (T-151) where I, as the human, was supposed to review the findings. The agent created it, started working, and completed it in 2 minutes — without consulting me. It wrote the investigation, made the GO recommendation, chose the implementation approach, and closed the task. Unilaterally. The task existed, but it was theatre. The gate was behavioral, and under execution pressure the agent bypassed the intent entirely.

I studied how mature governance frameworks handle this distinction. ISO 27

---

## SUBSYSTEM: learnings-pipeline
Components: 5

### Components
- **add-learning** (script) @ `agents/context/lib/learning.sh` — Add a learning entry to project memory (learnings.yaml). Assigns next L-XXX ID, formats YAML, inserts before candidates section. [1 deps, 2 dependents]
- **learnings-data** (data) @ `.context/project/learnings.yaml` — Persistent store of all project learnings. Read by web UI and audit. Written by add-learning command. [0 deps, 3 dependents]
- **learnings-route** (route) @ `web/blueprints/discovery.py` — Serve the /learnings page showing all project learnings, patterns, and practices. [9 deps, 4 dependents]
- **learnings-template** (template) @ `web/templates/learnings.html` — Render learnings table, practices section, and navigation for the /learnings page. [1 deps, 1 dependents]
- **patterns-data** (data) @ `.context/project/patterns.yaml` — Stores failure, success, and workflow patterns discovered during project work. [0 deps, 2 dependents]

### Source Code Headers (key components)

**add-learning:**
```
Context Agent - add-learning command
Add a learning to project memory
```

**learnings-data:**
```
Project Memory - Learnings
Lessons learned from completed tasks.
Used by agents to improve future work.
```

**learnings-route:**
```
Discovery blueprint — decisions, learnings, gaps, search, graduation.

import json
import os
import re as re_mod
```

**patterns-data:**
```
Project Memory - Patterns
Accumulated patterns from working on this project.
Grows over time as we learn from tasks.
```

### Task History (episodic memory)
- **T-268**: Multi-turn Q&A conversation — Multi-turn Q&A conversation — fetch+ReadableStream, client-side history
- **T-273**: Production readiness — WSGI, health endpoint, config, error handling — Production readiness — WSGI, health, config, error handling
- **T-277**: First deployment — Watchtower to Ring20 production — Fix health endpoint blocking on stale index rebuild. Pre-deploy state sync — context, tasks, audits. First deployment of
- **T-278**: Harvest deployment learnings — templates to learnings.yaml — Harvest deployment learnings — 6 template + 3 experience. Fix verification command — avoid grep -qv on piped audit
- **T-344**: Interactive auto-init dialogue with directory and provider selection — Replace Y/n auto-init with guided 2-question dialogue. Task completed, episodic generated. Fix FW_LIB_DIR unbound variab
- **T-345**: Add bugfix learning checkpoint practice and G-016 gap — Add Bug-Fix Learning Checkpoint practice and register G-016. Update ACs and verification commands. Task completed — prac
- **T-346**: Add bugfix-learning coverage ratio to audit section 5 — T-346, T-347: Add bugfix-learning audit check and fw fix-learned shortcut
- **T-347**: Build fw fix-learned shortcut for fast learning capture — T-346, T-347: Add bugfix-learning audit check and fw fix-learned shortcut
- **T-348**: Fix update-task.sh sed failing on macOS BSD sed — Replace all sed -i calls with portable _sed_i helper. Fix audit trends — retroactive ACs for T-319/T-320, fill handover.
- **T-365**: Watchtower /docs route for generated documentation — Add Watchtower /docs/generated route with subsystem-grouped index

---

## INSTRUCTIONS

Write Deep Dive #14: Learnings Pipeline

Follow the EXACT structure from the style reference:
1. **Title** — SEO-friendly, under 70 chars
2. **Post Body** opening — universal governance principle (ISO, programme management, clinical) → transition to AI agents → problem statement
3. **How it works** — mechanism explanation with code/YAML examples from the source headers above
4. **Why / Research section** — cite specific task IDs from the episodic memory, quantified findings, decision rationale
5. **Try it** — installation command + usage example
6. **Platform Notes** — Dev.to/LinkedIn/Reddit guidance
7. **Hashtags** — relevant tags

Rules:
- Write in first person ("I built", "I discovered")
- Cite real task IDs (T-XXX) from the episodic data
- Include at least one code/config example from the source headers
- Opening analogy must come from a real-world governance domain
- No emojis, no exclamation marks, no "we"
- Tone: peer-to-peer technical discussion, not a product pitch
