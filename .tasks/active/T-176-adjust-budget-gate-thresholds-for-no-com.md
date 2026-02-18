---
id: T-176
name: "Adjust budget gate thresholds for no-compaction architecture"
description: >
  From T-174 GO decision. With autoCompactEnabled:false, the 33K compaction buffer is no longer needed. Adjust budget-gate.sh thresholds: (1) Current: 100K ok→warn, 130K warn→urgent, 150K urgent→critical. (2) Proposed: 120K ok→warn, 150K warn→urgent, 170K urgent→critical. (3) The critical gate at 170K leaves 30K for handover routine (commit + handover generation). (4) Also update CLAUDE.md P-009 section with new thresholds. (5) Update checkpoint.sh fallback thresholds to match.

status: captured
workflow_type: build
owner: claude-code
horizon: next
tags: []
related_tasks: []
created: 2026-02-18T18:51:31Z
last_update: 2026-02-18T18:51:31Z
date_finished: null
---

# T-176: Adjust budget gate thresholds for no-compaction architecture

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

### 2026-02-18T18:51:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-176-adjust-budget-gate-thresholds-for-no-com.md
- **Context:** Initial task creation
