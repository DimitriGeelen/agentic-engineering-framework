---
id: T-176
name: "Adjust budget gate thresholds for no-compaction architecture"
description: >
  From T-174 GO decision. With autoCompactEnabled:false, the 33K compaction buffer is no longer needed. Adjust budget-gate.sh thresholds: (1) Current: 100K ok→warn, 130K warn→urgent, 150K urgent→critical. (2) Proposed: 120K ok→warn, 150K warn→urgent, 170K urgent→critical. (3) The critical gate at 170K leaves 30K for handover routine (commit + handover generation). (4) Also update CLAUDE.md P-009 section with new thresholds. (5) Update checkpoint.sh fallback thresholds to match.

status: started-work
workflow_type: build
owner: claude-code
horizon: next
tags: []
related_tasks: []
created: 2026-02-18T18:51:31Z
last_update: 2026-02-18T21:19:19Z
date_finished: null
---

# T-176: Adjust budget gate thresholds for no-compaction architecture

## Context

From T-174 GO decision (D-027). With autoCompactEnabled:false, the 33K compaction buffer is freed. Safe zone extends to ~170K.

## Acceptance Criteria

- [x] budget-gate.sh thresholds updated to 120K/150K/170K
- [x] checkpoint.sh thresholds updated to 120K/150K/170K
- [x] CLAUDE.md P-009 section updated with new thresholds and percentages
- [x] lib/templates/claude-project.md updated to match CLAUDE.md

## Verification

grep -q "TOKEN_WARN=120000" agents/context/budget-gate.sh
grep -q "TOKEN_URGENT=150000" agents/context/budget-gate.sh
grep -q "TOKEN_CRITICAL=170000" agents/context/budget-gate.sh
grep -q "TOKEN_WARN=120000" agents/context/checkpoint.sh
grep -q "TOKEN_URGENT=150000" agents/context/checkpoint.sh
grep -q "TOKEN_CRITICAL=170000" agents/context/checkpoint.sh
grep -q "120K.*warn" CLAUDE.md
grep -q "150K.*urgent" CLAUDE.md
grep -q "170K.*critical" CLAUDE.md

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

### 2026-02-18T18:51:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-176-adjust-budget-gate-thresholds-for-no-com.md
- **Context:** Initial task creation

### 2026-02-18T21:19:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
