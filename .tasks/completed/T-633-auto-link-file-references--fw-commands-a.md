---
id: T-633
name: "Auto-link file references — fw commands and Watchtower markdown emit clickable URLs"
description: >
  Auto-link file references — fw commands and Watchtower markdown emit clickable URLs

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: [bin/fw, lib/inception.sh, web/blueprints/docs.py]
related_tasks: []
created: 2026-03-26T22:37:19Z
last_update: 2026-04-06T22:29:18Z
date_finished: 2026-03-27T06:47:34Z
---

# T-633: Auto-link file references — fw commands and Watchtower markdown emit clickable URLs

## Context

When Watchtower renders markdown (file viewer, task body), file references like `docs/reports/T-629-governance-self-audit.md` should auto-convert to clickable `/file/` links. Also, `fw` commands that output file paths should format them as clickable Watchtower URLs. Makes research artifacts always accessible without agent discipline.

## Acceptance Criteria

### Agent
- [x] Watchtower markdown renderer auto-links `docs/reports/*.md` references to `/file/` viewer
- [x] Watchtower markdown renderer auto-links `.tasks/*.md` references to `/file/` viewer
- [x] Auto-linker uses relative URLs (no hardcoded localhost or port)
- [x] T-629 evidence files updated from /tmp/ to docs/reports/ paths (12 now clickable)
- [x] `fw inception decide` outputs research artifact links after recording decision
- [x] `fw task show` outputs research artifact links if they exist
- [x] Verify auto-linked references are clickable in file viewer (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

curl -s http://localhost:3010/file/docs/reports/T-629-governance-self-audit.md -o /tmp/T-633-verify.html && grep -c 'href="/file/' /tmp/T-633-verify.html
curl -sf http://localhost:3000/ | grep -q "href"

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

### 2026-03-26T22:37:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-633-auto-link-file-references--fw-commands-a.md
- **Context:** Initial task creation

### 2026-03-27T06:47:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:18Z — status-update [task-update-agent]
- **Change:** horizon: now → next
