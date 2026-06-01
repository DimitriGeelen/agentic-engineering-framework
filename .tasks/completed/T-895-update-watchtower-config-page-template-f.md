---
id: T-895
name: "Update Watchtower config page template for .framework.yaml source"
description: >
  Update Watchtower config page template for .framework.yaml source

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [web/templates/config.html]
related_tasks: []
created: 2026-04-05T13:28:16Z
last_update: 2026-04-05T13:29:51Z
date_finished: 2026-04-05T13:29:51Z
---

# T-895: Update Watchtower config page template for .framework.yaml source

## Context

T-893 added file-tier lookup to Watchtower /config but the template has no CSS class for `source-file` badge and the help text doesn't mention `.framework.yaml` as a config source.

## Acceptance Criteria

### Agent
- [x] CSS class `source-file` defined in config.html
- [x] Help section mentions `.framework.yaml` as a configuration source
- [x] Resolution order updated to: explicit > env > .framework.yaml > default

## Verification

grep -q 'source-file' web/templates/config.html
grep -q 'framework.yaml' web/templates/config.html

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

### 2026-04-05T13:28:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-895-update-watchtower-config-page-template-f.md
- **Context:** Initial task creation

### 2026-04-05T13:29:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
