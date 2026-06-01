---
id: T-1099
name: "Write docs/consumer-project-setup.md — vendoring + shim + termlink onboarding walkthrough (G-030)"
description: >
  Create docs/consumer-project-setup.md with: how to clone target project, how to fw init, when/why to fw upgrade, what .framework.yaml fields mean (especially upstream_repo), shim vs vendored isolation models (link to G-031), termlink install (system-wide via brew, NOT per-project), and a worked example. Link from README.md and CLAUDE.md. Origin: G-030. Trigger: cross-session ring20-dashboard onboarding incident 2026-04-11.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: [T-1093, T-1094, T-1098]
created: 2026-04-11T12:16:03Z
last_update: 2026-04-12T07:32:19Z
date_finished: 2026-04-12T07:32:19Z
---

# T-1099: Write docs/consumer-project-setup.md — vendoring + shim + termlink onboarding walkthrough (G-030)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `docs/consumer-project-setup.md` exists with sections: prerequisites,
      fw init, fw upgrade, .framework.yaml fields, shim model, TermLink
- [x] Doc mentions upstream_repo and version fields
- [x] Doc mentions TermLink as machine-wide (links to T-1098 CLAUDE.md note)
- [x] Doc clarifies fw upgrade does NOT copy framework code

## Verification

test -f docs/consumer-project-setup.md
grep -q "upstream_repo" docs/consumer-project-setup.md
grep -q "machine-wide" docs/consumer-project-setup.md
grep -q "fw upgrade" docs/consumer-project-setup.md

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

### 2026-04-11T12:16:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1099-write-docsconsumer-project-setupmd--vend.md
- **Context:** Initial task creation

### 2026-04-12T07:30:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T07:32:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
