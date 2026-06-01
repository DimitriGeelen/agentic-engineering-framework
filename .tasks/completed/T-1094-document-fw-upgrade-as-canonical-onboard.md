---
id: T-1094
name: "Document fw upgrade as canonical onboarding command + clarify what it actually does (G-025)"
description: >
  Surface fw upgrade in CLAUDE.md, fw doctor output, and a new docs/consumer-project-setup.md as the canonical answer to 'set up the framework in this project'. Document exactly what it does (shim migration, governance refresh, vendored script sync, version pin) so agents stop assuming it copies framework files into a per-project directory. Origin: G-025. Trigger: cross-session ring20-dashboard onboarding incident 2026-04-11.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: [T-1093]
created: 2026-04-11T12:15:33Z
last_update: 2026-04-12T07:27:52Z
date_finished: 2026-04-12T07:27:52Z
---

# T-1094: Document fw upgrade as canonical onboarding command + clarify what it actually does (G-025)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `fw upgrade` documented in CLAUDE.md Quick Reference table
- [x] CLAUDE.md §fw CLI section mentions upgrade with description
- [x] Description clarifies upgrade does NOT copy framework code into
      the consumer project

## Verification

grep -q "fw upgrade" CLAUDE.md
grep -q "Upgrade consumer" CLAUDE.md

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

### 2026-04-11T12:15:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1094-document-fw-upgrade-as-canonical-onboard.md
- **Context:** Initial task creation

### 2026-04-12T07:25:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T07:27:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
