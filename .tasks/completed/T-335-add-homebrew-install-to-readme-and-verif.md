---
id: T-335
name: "Add Homebrew install to README and verify tap documentation"
description: >
  The launch article (T-329) and Homebrew tap (T-330) advertise `brew tap DimitriGeelen/agentic-fw && brew install fw`
  but the README Quickstart only shows the curl install. Add Homebrew as an install option in the README.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [docs, install]
components: [README.md]
related_tasks: [T-329, T-330]
created: 2026-03-06T22:12:20Z
last_update: 2026-03-08T19:33:25Z
date_finished: 2026-03-06T22:14:02Z
---

# T-335: Add Homebrew install to README and verify tap documentation

## Context

Article (T-329) and tap repo (T-330) advertise Homebrew install, but README only shows curl. Gap discovered during T-329 article review.

## Acceptance Criteria

### Agent
- [x] README Quickstart includes Homebrew install option (`brew tap` + `brew install fw`)
- [x] Homebrew and curl install are both present as alternatives
- [x] README task count matches article (312, not 325)

### Human
- [x] `brew tap DimitriGeelen/agentic-fw && brew install fw` verified on macOS

## Verification

grep -q "brew tap" README.md
grep -q "brew install fw" README.md
grep -q "curl -fsSL" README.md

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

### 2026-03-06T22:12:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-335-add-homebrew-install-to-readme-and-verif.md
- **Context:** Initial task creation

### 2026-03-06T22:14:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
