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

## SUBSYSTEM: watchtower
Components: 45

### Components
- **app** (entrypoint) @ `web/app.py` — Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port [25 deps, 1 dependents]
- **__init__** (route) @ `web/blueprints/__init__.py` — Flask blueprint:   Init   [0 deps, 1 dependents]
- **cockpit** (route) @ `web/blueprints/cockpit.py` — Flask blueprint: Cockpit [1 deps, 4 dependents]
- **core** (route) @ `web/blueprints/core.py` — Flask blueprint: Core [8 deps, 2 dependents]
- **enforcement** (route) @ `web/blueprints/enforcement.py` — Flask blueprint: Enforcement [2 deps, 2 dependents]
- **fabric** (route) @ `web/blueprints/fabric.py` — Flask blueprint: Fabric [4 deps, 2 dependents]
- **inception** (route) @ `web/blueprints/inception.py` — Blueprint 'inception' — routes: /inception [4 deps, 2 dependents]
- **metrics** (route) @ `web/blueprints/metrics.py` — Flask blueprint: Metrics [2 deps, 2 dependents]
- **quality** (route) @ `web/blueprints/quality.py` — Flask blueprint: Quality [2 deps, 2 dependents]
- **risks** (route) @ `web/blueprints/risks.py` — Flask blueprint 'risks' serving routes: /risks [2 deps, 2 dependents]
- **session** (route) @ `web/blueprints/session.py` — Flask blueprint: Session [1 deps, 2 dependents]
- **tasks** (route) @ `web/blueprints/tasks.py` — Flask blueprint: Tasks [3 deps, 2 dependents]
- **timeline** (route) @ `web/blueprints/timeline.py` — Blueprint 'timeline' — routes: /timeline [2 deps, 2 dependents]
- **embeddings** (script) @ `web/embeddings.py` — sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search [2 deps, 0 dependents]
- **search** (script) @ `web/search.py` — Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets [2 deps, 0 dependents]
- **shared** (library) @ `web/shared.py` — Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) [0 deps, 13 dependents]
- **_error** (fragment) @ `web/templates/_error.html` — Error page template — displays HTTP error codes and messages [0 deps, 1 dependents]
- **_quality_audit_fragment** (fragment) @ `web/templates/_quality_audit_fragment.html` — HTMX fragment: quality audit results panel, loaded dynamically [0 deps, 1 dependents]
- **_session_strip** (fragment) @ `web/templates/_session_strip.html` — HTMX fragment: session status strip shown in page headers [0 deps, 1 dependents]
- **_timeline_task** (fragment) @ `web/templates/_timeline_task.html` — HTMX fragment: individual task card for the timeline view [0 deps, 1 dependents]
- **_wrapper** (fragment) @ `web/templates/_wrapper.html` — Base layout wrapper: nav, header, footer, htmx/CSS includes [1 deps, 0 dependents]
- **assumptions** (template) @ `web/templates/assumptions.html` — Watchtower UI page: Assumptions [0 deps, 1 dependents]
- **base** (template) @ `web/templates/base.html` — Template: {{ page_title | default("Watchtower") }} — Agentic Engineering Framework [0 deps, 1 dependents]
- **cockpit** (template) @ `web/templates/cockpit.html` — Page template: Watchtower [0 deps, 1 dependents]
- **decisions** (template) @ `web/templates/decisions.html` — Watchtower UI page: Decisions [0 deps, 1 dependents]
- **directives** (template) @ `web/templates/directives.html` — Watchtower UI page: Directives [0 deps, 1 dependents]
- **enforcement** (template) @ `web/templates/enforcement.html` — Page template: Enforcement Tiers [0 deps, 1 dependents]
- **fabric** (template) @ `web/templates/fabric.html` — Watchtower UI page: Fabric [0 deps, 1 dependents]
- **fabric_detail** (template) @ `web/templates/fabric_detail.html` — Watchtower UI page: Fabric Detail [0 deps, 1 dependents]
- **fabric_graph** (template) @ `web/templates/fabric_graph.html` — Watchtower UI page: Fabric Graph [0 deps, 1 dependents]
- **gaps** (template) @ `web/templates/gaps.html` — Watchtower UI page: Gaps [0 deps, 1 dependents]
- **graduation** (template) @ `web/templates/graduation.html` — Watchtower UI page: Graduation [0 deps, 1 dependents]
- **inception** (template) @ `web/templates/inception.html` — Watchtower UI page: Inception [0 deps, 1 dependents]
- **inception_detail** (template) @ `web/templates/inception_detail.html` — Watchtower UI page: Inception Detail [0 deps, 1 dependents]
- **index** (template) @ `web/templates/index.html` — Watchtower UI page: Index [0 deps, 1 dependents]
- **metrics** (template) @ `web/templates/metrics.html` — Watchtower UI page: Metrics [0 deps, 1 dependents]
- **patterns** (template) @ `web/templates/patterns.html` — Watchtower UI page: Patterns [0 deps, 1 dependents]
- **project** (template) @ `web/templates/project.html` — Watchtower UI page: Project [0 deps, 1 dependents]
- **project_doc** (template) @ `web/templates/project_doc.html` — Watchtower UI page: Project Doc [0 deps, 1 dependents]
- **quality** (template) @ `web/templates/quality.html` — Watchtower UI page: Quality [1 deps, 1 dependents]
- **risks** (template) @ `web/templates/risks.html` — Watchtower UI page: Risks [0 deps, 1 dependents]
- **search** (template) @ `web/templates/search.html` — Watchtower UI page: Search [0 deps, 1 dependents]
- **task_detail** (template) @ `web/templates/task_detail.html` — Jinja2 template rendering individual task detail pages in Watchtower. Shows task frontmatter, acceptance criteria with checkboxes, verification commands, decisions, and update history with markdown rendering. [0 deps, 1 dependents]
- **tasks** (template) @ `web/templates/tasks.html` — Watchtower UI page: Tasks [0 deps, 1 dependents]
- **timeline** (template) @ `web/templates/timeline.html` — Page template: Timeline [0 deps, 1 dependents]

### Source Code Headers (key components)

**app:**
```
Watchtower — Agentic Engineering Framework Web UI

Flask application serving the Watchtower command center with htmx-powered
SPA-like navigation and Pico CSS styling.

```

**__init__:**
```
Flask blueprints for the Agentic Engineering Framework web UI
```

**cockpit:**
```
web/blueprints/cockpit.py
Cockpit blueprint — scan-driven interactive dashboard.

Renders the Watchtower cockpit when scan data exists, with:
- Needs Decision (amber) — items requiring SOVEREIGNTY
```

**core:**
```
Core blueprint — dashboard, project docs, directives.

import os
import re as re_mod
import subprocess
```

**enforcement:**
```
Enforcement blueprint — Tier 0-3 enforcement status dashboard.

import json
import os
from pathlib import Path
```

**fabric:**
```
Watchtower – Component Fabric browser.

import glob
import os

```

### Task History (episodic memory)
- **T-263**: RAG quick wins — prompt, embeddings, chunking — RAG quick wins — prompt, embeddings, chunking, cache
- **T-265**: Saved answers — curated Q&A for retrieval flywheel — Saved answers — Save button, POST endpoint, qa directory indexing
- **T-266**: Streaming UX — marked.js, syntax highlighting, copy buttons — Streaming UX — marked.js, highlight.js, copy buttons, debounced rendering
- **T-267**: User feedback — thumbs up/down on Q&A answers — User feedback — thumbs up/down buttons, SQLite storage, analytics page
- **T-268**: Multi-turn Q&A conversation — Multi-turn Q&A conversation — fetch+ReadableStream, client-side history
- **T-273**: Production readiness — WSGI, health endpoint, config, error handling — Production readiness — WSGI, health, config, error handling
- **T-277**: First deployment — Watchtower to Ring20 production — Fix health endpoint blocking on stale index rebuild. Pre-deploy state sync — context, tasks, audits. First deployment of
- **T-353**: Fix related_tasks per-character link rendering in Watchtower — Fix related_tasks per-character link rendering in Watchtower. Fill AC and verification for completion gate
- **T-361**: Add docs field to Component Fabric cards + Watchtower rendering — Add docs field to 24 fabric cards + Watchtower rendering + traverse.sh safety fix
- **T-365**: Watchtower /docs route for generated documentation — Add Watchtower /docs/generated route with subsystem-grouped index

---

## INSTRUCTIONS

Write Deep Dive #9: Watchtower

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
