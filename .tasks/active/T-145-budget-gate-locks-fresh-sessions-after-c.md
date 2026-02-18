---
id: T-145
name: "Budget gate locks fresh sessions after compaction — JSONL accumulates"
description: >
  After /compact, the JSONL transcript retains all pre-compaction messages. budget-gate.sh reads the full file and sees 150K+ tokens, writing critical to .budget-status. Fresh sessions inherit this lock. The gate self-reinforces: each blocked call re-reads the JSONL and re-confirms critical. Fix: detect session boundaries (compaction markers) in JSONL, or base token count on actual active context, not historical transcript.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T09:38:27Z
last_update: 2026-02-18T09:38:27Z
date_finished: null
---

# T-145: Budget gate locks fresh sessions after compaction — JSONL accumulates

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

### 2026-02-18T09:38:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-145-budget-gate-locks-fresh-sessions-after-c.md
- **Context:** Initial task creation
