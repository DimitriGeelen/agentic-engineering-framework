---
id: T-107
name: Initialize German pronunciation app project
description: >
  BRIDGE TASK: This is the transition from framework work to real-world project work. Initialize the German pronunciation training app as a separate project using the framework. CONTEXT: The app shows German text to a non-native speaker, they read it aloud, STT (Whisper) transcribes it, system compares transcription against original text, detects pronunciation errors, and generates targeted exercises. The clever insight: STT errors ARE the pronunciation signal — if Whisper cant understand you, native Germans probably cant either. This naturally prioritizes high-impact pronunciation issues. TECHNICAL DIRECTION: Web app (Python backend + simple frontend) for fastest MVP. Stack: FastAPI/Flask backend, Whisper for STT, Claude API for exercise generation, SQLite for progress tracking. Can access from iPhone via Safari. Native iOS rewrite later if concept validates. STEPS: (1) Create project directory. (2) Run fw setup (from T-104) to do guided onboarding. (3) Verify fw doctor passes. (4) Create first inception task IN THE NEW PROJECT (not here) to explore pronunciation engine design. (5) Validate the full framework loop: task create -> build -> commit -> handover -> harvest. DEPENDS ON: T-101 (hook fix), T-102 (CLAUDE.md template), T-103 (init hardening), T-104 (setup wizard). This task produces a working project scaffold. ALL subsequent app development tasks are created in the apps own .tasks/ directory, not in the framework repo. SEPARATION: After this task, framework work and app work are in separate repos with separate task numbering.

status: captured
horizon: next
workflow_type: inception
owner: human
tags: [external-project, pronunciation, german, bridge-task]
related_tasks: []
created: 2026-02-17T08:54:42Z
last_update: 2026-02-17T16:12:44Z
date_finished: null
---

# T-107: Initialize German pronunciation app project

## Problem Statement

Non-native German speakers (like the project owner) mispronounce words/syllables, causing confusion in daily conversation. No existing tool provides a simple read-aloud → feedback → practice loop that uses STT error detection as the pronunciation quality signal.

**For whom:** The project owner (English native speaker, living in Germany, intermediate+ German)
**Why now:** Framework is at 100 tasks, ready for real-world validation. This project tests the full fw init → build → harvest cycle.

## Assumptions

- A-001: Whisper (or similar STT) will fail to correctly transcribe mispronounced German words (this is the core signal)
- A-002: A web app accessible via Safari on iPhone is sufficient for MVP (no native app needed)
- A-003: The framework's task-first governance adds structure without slowing development
- A-004: Python + FastAPI/Flask + Whisper API is the fastest path to working MVP

## Exploration Plan

1. Run `fw setup` on a new directory — validate the full onboarding flow (10 min)
2. Create inception task IN the new project for pronunciation engine design
3. Build minimal spike: record audio → send to Whisper → compare text (1-2 hours)
4. Evaluate: does Whisper actually detect pronunciation errors, or is it too forgiving?

## Scope Fence

**IN scope (this task T-107):**
- Create project directory
- Run `fw setup` through all 6 steps
- Verify `fw doctor` passes
- Create first task in the new project
- Validate framework commands work from the new project

**OUT of scope:**
- Any actual app development (that happens in the new project's own tasks)
- Architecture decisions about the app (those go in the app's inception task)
- Dev server setup (T-106, separate)

## Go/No-Go Criteria

**GO if:**
- `fw setup` completes successfully
- `fw doctor` passes
- Can create tasks, commit, and run handover from the new project
- Hooks enforce correctly (check-active-task checks the PROJECT, not the framework)

**NO-GO if:**
- Framework bugs in T-101/T-102/T-103 are not resolved
- `fw doctor` fails in the new project
- Hooks silently point to wrong project (T-101 not fixed)

## Decision

<!-- Filled at completion via: fw inception decide T-107 go|no-go --rationale "..." -->

## Technical Direction (for the app, captured here for handover)

**App concept:** German pronunciation trainer
- Present German text → user reads aloud → STT transcribes → compare → score → adapt exercises
- Core insight: STT errors proxy pronunciation errors. High-impact issues first.
- Consider Azure Pronunciation Assessment API as enhancement over pure Whisper comparison

**Proposed stack:**
- Frontend: HTML/CSS/JS (or lightweight React) — text display, audio recording
- Backend: Python (FastAPI or Flask) — orchestration, exercise logic
- STT: Whisper (OpenAI API or local) — speech-to-text
- LLM: Claude API — exercise generation, error analysis
- Storage: SQLite or files — progress tracking

**This information transfers to the app project's first inception task.**

## Updates

### 2026-02-17T08:54:42Z — task-created [task-create-agent]
- **Action:** Created inception task
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-107-initialize-german-pronunciation-app-proj.md
- **Context:** Initial task creation

[Chronological log — every action, every output, every decision]

### 2026-02-17T16:12:44Z — status-update [task-update-agent]
- **Change:** horizon: unset → next
