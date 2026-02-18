---
id: T-175
name: "Strengthen emergency handover for post-compaction world"
description: >
  From T-174 GO decision. Emergency handover (handover.sh --emergency) needs to capture more context now that it replaces compaction as the primary context preservation mechanism. Add: (1) Current focus task from focus.yaml, (2) git diff summary (staged + unstaged, truncated to ~50 lines), (3) Session narrative from session.yaml if available, (4) Investigation summaries section template for manual handovers. Goal: emergency handover should be as informative as a manual handover for context recovery via fw resume.

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
