---
id: T-1098
name: "CLAUDE.md: explicitly contrast termlink (machine-wide) vs framework (per-project) distribution models (G-029)"
description: >
  Add a section or sentence to CLAUDE.md §TermLink Integration that states termlink is intentionally machine-wide because session discovery uses Unix sockets at system paths — per-project isolation would defeat cross-session discovery. Frame as the deliberate inverse of framework code (per-project governance). Stops agents from proposing per-project termlink vendoring. Origin: G-029. Trigger: cross-session ring20-dashboard onboarding incident 2026-04-11.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: [T-1093]
created: 2026-04-11T12:15:59Z
last_update: 2026-04-12T07:22:38Z
date_finished: 2026-04-12T07:22:38Z
---

# T-1098: CLAUDE.md: explicitly contrast termlink (machine-wide) vs framework (per-project) distribution models (G-029)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] CLAUDE.md §TermLink Integration contains a distribution-model
      contrast note explaining machine-wide vs per-project
- [x] Note mentions Unix socket discovery as the reason

## Verification

grep -q "machine-wide" CLAUDE.md

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-11T12:15:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1098-claudemd-explicitly-contrast-termlink-ma.md
- **Context:** Initial task creation

### 2026-04-12T07:21:27Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T07:22:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a8e1ab75
- **Timestamp:** 2026-06-02T14:55:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
