---
id: T-363
name: "Layer 0: Fix broken purpose fields in component cards"
description: >
  Prerequisite for doc generation. Build fw docs heal command: reads each card, if purpose is broken/placeholder, extract first comment block from source file and update card. ~60% of 127 cards need fixing. See docs/reports/T-362-auto-doc-generation.md

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [documentation, fabric]
components: []
related_tasks: []
created: 2026-03-08T22:03:24Z
last_update: 2026-03-08T22:10:18Z
date_finished: 2026-03-08T22:10:18Z
---

# T-363: Layer 0: Fix broken purpose fields in component cards

## Context

Prerequisite for T-364 doc generator. Audit found only 6/127 cards needed fixing (1 broken, 4 echo, 1 thin) — much less than the 60% estimate. Fixed by extracting descriptions from source file headers.

## Acceptance Criteria

### Agent
- [x] All 127 component cards have non-trivial purpose fields (>10 chars, no placeholders)
- [x] All modified cards parse as valid YAML
- [x] Fixed cards: plugin-audit, bus-handler, mcp-reaper, claude-fw, fw, task_detail

## Verification

python3 -c "import yaml, glob; cards=[yaml.safe_load(open(f)) for f in glob.glob('.fabric/components/*.yaml')]; bad=[c['name'] for c in cards if not c.get('purpose') or len(str(c['purpose']))<10 or '=====' in str(c['purpose'])]; assert not bad, f'Broken: {bad}'; print(f'All {len(cards)} cards have valid purposes')"

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

### 2026-03-08T22:03:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-363-layer-0-fix-broken-purpose-fields-in-com.md
- **Context:** Initial task creation

### 2026-03-08T22:07:57Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-08T22:10:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
