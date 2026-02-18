---
id: T-175
name: "Eliminate emergency/full handover distinction — single handover"
description: >
  REVISED from T-174 investigation. Original goal was to strengthen emergency handover. New insight: with budget gate at 170K (T-176) leaving 30K for handover, there's always enough room for a FULL handover. The task system (task files, git, episodic, project memory) is the real safety net — ~95% of state survives even a zero-handover crash. Therefore: (1) Eliminate the --emergency flag and emergency mode from handover.sh. (2) Always generate a full-quality handover. (3) The budget gate at critical forces handover, but it should be the SAME full handover. (4) If handover somehow can't complete, fw resume status reconstructs from durable state anyway. See docs/reports/T-174-compaction-vs-handover.md for full research.

status: captured
workflow_type: build
owner: claude-code
horizon: next
tags: []
related_tasks: []
created: 2026-02-18T18:51:26Z
last_update: 2026-02-18T18:51:26Z
date_finished: null
---

# T-175: Strengthen emergency handover for post-compaction world

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

- [ ] [First criterion]
- [ ] [Second criterion]

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

### 2026-02-18T18:51:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-175-strengthen-emergency-handover-for-post-c.md
- **Context:** Initial task creation
