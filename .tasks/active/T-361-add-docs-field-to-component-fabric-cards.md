---
id: T-361
name: "Add docs field to Component Fabric cards + Watchtower rendering"
description: >
  From T-339 GO: (1) Add optional docs field to ~28 component cards mapping 7 deep-dive articles, (2) Add Documentation section to fabric_detail.html template, (3) Fix dep['target'] safety in traverse.sh. Optional stretch: /fabric/docs reverse-lookup page. See docs/reports/T-339-doc-fabric-linking.md for mapping and research.

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: []
components: [agents/fabric/lib/traverse.sh, web/templates/fabric_detail.html]
related_tasks: []
created: 2026-03-08T21:38:56Z
last_update: 2026-03-10T22:04:13Z
date_finished: 2026-03-08T21:46:03Z
---

# T-361: Add docs field to Component Fabric cards + Watchtower rendering

## Context

From T-339 GO decision. Research: `docs/reports/T-339-doc-fabric-linking.md`.

## Acceptance Criteria

### Agent
- [x] `docs` field added to 24 component cards mapping 7 deep-dive articles
- [x] `fabric_detail.html` renders Documentation section when `docs` field present
- [x] `traverse.sh` line 105 `dep['target']` replaced with safe `.get()`
- [x] All modified YAML cards parse correctly (127/127)
- [x] Watchtower component detail page loads with Documentation section for cards with docs

### Human
- [ ] [RUBBER-STAMP] Documentation section renders well on Watchtower component detail
  **Steps:**
  1. Open http://localhost:3000/fabric/component/agents-healing-healing
  2. Look for "Documentation" section
  **Expected:** Section shows linked deep-dive article(s) with title and path
  **If not:** Screenshot the page

## Verification

# All modified cards parse
python3 -c "import yaml, glob; [yaml.safe_load(open(f)) for f in glob.glob('.fabric/components/*.yaml')]"
# Template renders for a card with docs
curl -sf http://localhost:3000/fabric/component/agents-healing-healing | grep -q "Documentation"
# traverse.sh has no unsafe direct key access
! grep -q "dep\['target'\]" agents/fabric/lib/traverse.sh

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

### 2026-03-08T21:38:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-361-add-docs-field-to-component-fabric-cards.md
- **Context:** Initial task creation

### 2026-03-08T21:46:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:13Z — status-update [task-update-agent]
- **Change:** horizon: now → next
