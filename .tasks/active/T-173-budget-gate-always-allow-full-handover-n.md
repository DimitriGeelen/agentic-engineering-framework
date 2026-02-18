---
id: T-173
name: "Budget gate: always allow full handover, not just emergency skeleton"
description: >
  Current budget gate at critical (150K+) blocks Write/Edit/Bash so aggressively that even the handover routine can't fill in [TODO] sections. The human user couldn't bypass it either. Fix: (1) The gate should always allow full handover completion — if there's context space left, a proper handover is more valuable than an emergency skeleton. (2) Consider raising the critical threshold or making handover operations exempt from the gate. (3) The gate should distinguish between 'new work' (block) and 'wrap-up work' (allow). Evidence: S-2026-0218-1917 handover had unfilled TODOs because gate blocked edits at 154K.

status: captured
workflow_type: build
owner: claude-code
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T18:24:33Z
last_update: 2026-02-18T18:24:33Z
date_finished: null
---

# T-173: Budget gate: always allow full handover, not just emergency skeleton

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

### 2026-02-18T18:24:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-173-budget-gate-always-allow-full-handover-n.md
- **Context:** Initial task creation
