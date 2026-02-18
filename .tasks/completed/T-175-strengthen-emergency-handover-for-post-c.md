---
id: T-175
name: "Eliminate emergency/full handover distinction — single handover"
description: >
  REVISED from T-174 investigation. Original goal was to strengthen emergency handover. New insight: with budget gate at 170K (T-176) leaving 30K for handover, there's always enough room for a FULL handover. The task system (task files, git, episodic, project memory) is the real safety net — ~95% of state survives even a zero-handover crash. Therefore: (1) Eliminate the --emergency flag and emergency mode from handover.sh. (2) Always generate a full-quality handover. (3) The budget gate at critical forces handover, but it should be the SAME full handover. (4) If handover somehow can't complete, fw resume status reconstructs from durable state anyway. See docs/reports/T-174-compaction-vs-handover.md for full research.

status: work-completed
workflow_type: build
owner: claude-code
horizon: next
tags: []
related_tasks: []
created: 2026-02-18T18:51:26Z
last_update: 2026-02-18T21:27:26Z
date_finished: 2026-02-18T21:27:26Z
---

# T-175: Eliminate emergency/full handover distinction — single handover

## Context

REVISED scope from original "strengthen emergency handover." Filename mismatch: file is `T-175-strengthen-emergency-handover-for-post-c.md` but task is now about eliminating the distinction. See docs/reports/T-174-crash-resilience-analysis.md and docs/reports/T-174-compaction-vs-handover.md for research backing this decision.

## Acceptance Criteria

- [x] Emergency mode code block removed from handover.sh
- [x] --emergency flag accepted but treated as normal handover (backwards compat)
- [x] checkpoint.sh auto-trigger calls normal handover (not --emergency)
- [x] pre-compact.sh calls normal handover (not --emergency)
- [x] bin/fw help text updated (no --emergency line)
- [x] Practices updated to remove --emergency references
- [x] CLAUDE.md already clean (updated in T-173)

## Verification

# handover.sh no longer has EMERGENCY_MODE variable
grep -qv "EMERGENCY_MODE" agents/handover/handover.sh
# handover.sh still accepts --emergency (backwards compat, silent)
grep -q "emergency" agents/handover/handover.sh
# checkpoint.sh doesn't pass --emergency
grep -qv "\-\-emergency" agents/context/checkpoint.sh
# pre-compact.sh doesn't pass --emergency
grep -qv "\-\-emergency" agents/context/pre-compact.sh
# bin/fw doesn't show emergency in help
grep -qv "emergency" bin/fw

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

### 2026-02-18T21:23:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-18T21:27:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
