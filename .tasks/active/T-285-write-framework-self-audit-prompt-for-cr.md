---
id: T-285
name: "Write framework self-audit prompt for cross-project deployment"
description: >
  Create a comprehensive self-audit and remediation prompt that agents can use to verify all framework controls are functioning after the framework has been merged/copied into an existing project.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [audit, deployment, governance]
components: [docs/prompts/framework-self-audit.md]
related_tasks: [T-286]
created: 2026-03-01T08:59:31Z
last_update: 2026-03-01T09:38:01Z
date_finished: 2026-03-01T09:38:01Z
---

# T-285: Write framework self-audit prompt for cross-project deployment

## Context

Create a comprehensive self-audit prompt for cross-project framework deployment. Research: dispatched 2 explore agents (controls inventory 704 lines, dependency chains 661 lines) to map all 6 enforcement layers, 14 self-corrective mechanisms, 150+ audit checks. Follow-up T-286 will build the standalone CLI script and `fw self-audit` command.

## Acceptance Criteria

### Agent
- [x] Self-audit prompt covers all 6 enforcement layers
- [x] Includes bootstrap prompt for pulling from OneDev repo
- [x] Includes remediation steps for each failure mode
- [x] Documents 8 common merge problems with solutions
- [x] Includes success criteria with concrete verification commands
- [x] Includes correct `.claude/settings.json` reference JSON
- [x] Report template included for structured findings

### Human
- [ ] Bootstrap prompt works from a fresh project (pull + execute)

## Verification

test -f docs/prompts/framework-self-audit.md
# File has substantial content (>500 lines)
test $(wc -l < docs/prompts/framework-self-audit.md) -gt 500
# Contains all 6 layers
grep -q "LAYER 1" docs/prompts/framework-self-audit.md
grep -q "LAYER 2" docs/prompts/framework-self-audit.md
grep -q "LAYER 3" docs/prompts/framework-self-audit.md
grep -q "LAYER 4" docs/prompts/framework-self-audit.md
grep -q "LAYER 5" docs/prompts/framework-self-audit.md
grep -q "LAYER 6" docs/prompts/framework-self-audit.md
# Contains success criteria
grep -q "SUCCESS CRITERIA" docs/prompts/framework-self-audit.md
# Contains bootstrap prompt
grep -q "Bootstrap" docs/prompts/framework-self-audit.md

## Decisions

### 2026-03-01 — Two-piece architecture
- **Chose:** Prompt file in repo + short bootstrap prompt for humans to paste
- **Why:** Single source of truth, version-controlled, any project can pull and execute
- **Rejected:** Pasting the full 900-line prompt (fragile, unversioned, painful)

## Updates

### 2026-03-01T08:59:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-285-write-framework-self-audit-prompt-for-cr.md
- **Context:** Initial task creation

### 2026-03-01T09:38:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
