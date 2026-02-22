---
id: T-220
name: "Fabric component detail — inline source code viewer"
description: >
  Add inline source code viewing to /fabric/component/<name> detail page. When user clicks a component, show the file contents with syntax highlighting. Enhances the fabric browser from metadata-only to full code inspection.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [web/blueprints/fabric.py, web/templates/base.html, web/templates/fabric_detail.html]
related_tasks: []
created: 2026-02-20T09:16:03Z
last_update: 2026-02-22T08:50:53Z
date_finished: 2026-02-22T08:50:53Z
---

# T-220: Fabric component detail — inline source code viewer

## Context

The `/fabric/component/<name>` detail page shows component metadata but not the actual source code. Adding inline source display with syntax highlighting makes the fabric browser self-contained for code inspection.

## Acceptance Criteria

### Agent
- [x] highlight.js CSS + JS added to `web/templates/base.html` (CDN)
- [x] htmx afterSwap re-highlight hook in base template
- [x] `component_detail()` in `web/blueprints/fabric.py` reads source file from component location
- [x] Source code section rendered in `web/templates/fabric_detail.html` with syntax highlighting
- [x] Language detection from file extension (.py, .sh, .yaml, .js, .html, .md)
- [x] Safety: file must exist and be under PROJECT_ROOT, capped at 2000 lines
- [x] Missing file shows muted "file not found" message instead of error

### Human
- [ ] Source code is readable with good contrast (dark theme)
- [ ] Collapsible section works smoothly

## Verification

curl -sf http://localhost:3000/fabric/component/web-app | grep -q "hljs"
curl -sf http://localhost:3000/fabric/component/web-app | grep -q "Source Code"
python3 -c "import yaml; yaml.safe_load(open('.fabric/components/web-app.yaml'))"

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

### 2026-02-20T09:16:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-220-fabric-component-detail--inline-source-c.md
- **Context:** Initial task creation

### 2026-02-22T08:50:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
