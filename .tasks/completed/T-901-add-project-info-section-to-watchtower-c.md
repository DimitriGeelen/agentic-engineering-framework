---
id: T-901
name: "Add project info section to Watchtower /config page"
description: >
  Add project info section to Watchtower /config page

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [web/blueprints/config.py, web/templates/config.html]
related_tasks: []
created: 2026-04-05T13:46:08Z
last_update: 2026-04-05T13:48:11Z
date_finished: 2026-04-05T13:48:11Z
---

# T-901: Add project info section to Watchtower /config page

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Config page shows project info (name, version, provider) from `.framework.yaml`
- [x] Custom settings from `.framework.yaml` shown separately from FW_ registry
- [x] Page loads without errors

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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

### 2026-04-05T13:46:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-901-add-project-info-section-to-watchtower-c.md
- **Context:** Initial task creation

### 2026-04-05T13:48:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
