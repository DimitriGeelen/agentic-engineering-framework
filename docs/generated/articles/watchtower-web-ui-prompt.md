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

## SUBSYSTEM: watchtower-web-ui
Components: 4

### Components
- **watchtower** (script) @ `bin/watchtower.sh` — Launcher script for Watchtower web dashboard. Starts Flask app on configured port with optional debug mode. [1 deps, 0 dependents]
- **discoveries** (route) @ `web/blueprints/discoveries.py` — Flask blueprint serving /discoveries route. Displays audit discovery findings with WARN/FAIL status from cron and manual audits. [1 deps, 0 dependents]
- **discoveries** (template) @ `web/templates/discoveries.html` — Jinja2 template rendering the discoveries page. Shows audit discovery results with pass/warn/fail indicators. [1 deps, 0 dependents]
- **feedback_analytics** (template) @ `web/templates/feedback_analytics.html` — Jinja2 template for feedback analytics page. Displays handover quality feedback trends and session statistics. [0 deps, 0 dependents]

### Source Code Headers (key components)

**watchtower:**
```
Watchtower — Reliable start/stop/restart for the Web UI (T-250)
Inspired by DenkraumNavigator/restart_server_prod.sh
Usage:
bin/watchtower.sh start [--port N] [--debug]
bin/watchtower.sh stop
```

**discoveries:**
```
Discoveries blueprint — audit discovery findings with trend sparklines.

import yaml
from flask import Blueprint

```

### Task History (episodic memory)
- **T-215**: Component Fabric — Watchtower UI page (visual browser + graph) — Watchtower fabric page — overview, component list, detail view (graph pending)
- **T-241**: Wire discovery findings into session-start and Watchtower — T-200: Create 4 build tasks with rich context from discovery research. Wire discovery findings into session-start and Wa
- **T-250**: Reliable Watchtower startup script — Add reliable Watchtower startup script with PID/port/health management
- **T-261**: Q&A Phase 2 — model upgrade, RAG quality, framework integration, saved answers — Q&A Phase 2 inception — research complete, 6 reports. Create 9 build tasks from Phase 2 research
- **T-267**: User feedback — thumbs up/down on Q&A answers — User feedback — thumbs up/down buttons, SQLite storage, analytics page
- **T-273**: Production readiness — WSGI, health endpoint, config, error handling — Production readiness — WSGI, health, config, error handling
- **T-365**: Watchtower /docs route for generated documentation — Add Watchtower /docs/generated route with subsystem-grouped index

---

## INSTRUCTIONS

Write Deep Dive #15: Watchtower Web Ui

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
