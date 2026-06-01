---
id: T-920
name: "Add missing depended_by reverse edges to fabric cards"
description: >
  Add missing depended_by reverse edges to fabric cards

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-05T16:00:24Z
last_update: 2026-04-05T16:01:41Z
date_finished: 2026-04-05T16:01:41Z
---

# T-920: Add missing depended_by reverse edges to fabric cards

## Context

127 forward edges (depends_on) lack corresponding reverse edges (depended_by). Adding these improves blast-radius accuracy.

## Acceptance Criteria

### Agent
- [x] Missing reverse edge count reduced from 127 to 8 (remaining 8 point to unregistered targets)
- [x] All cards remain valid YAML
- [x] No existing edges corrupted or duplicated

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

### 2026-04-05T16:00:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-920-add-missing-dependedby-reverse-edges-to-.md
- **Context:** Initial task creation

### 2026-04-05T16:01:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
