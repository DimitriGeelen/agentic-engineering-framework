---
id: T-693
name: "Fix learning prompt false positive — match task names starting with Fix, not containing fix anywhere"
description: >
  Fix learning prompt false positive — match task names starting with Fix, not containing fix anywhere

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-28T23:50:16Z
last_update: 2026-03-28T23:50:16Z
date_finished: null
---

# T-693: Fix learning prompt false positive — match task names starting with Fix, not containing fix anywhere

## Context

T-692 learning prompt matched "bugfix" in a task description, not as the action verb. All real fix tasks in this project start with "Fix" (e.g., "Fix bash 3.2 compat", "Fix self-audit false FAILs").

## Acceptance Criteria

### Agent
- [x] Regex matches task names starting with "Fix" (case insensitive)
- [x] Does not match task names that merely mention "fix" or "bugfix" in the description

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

### 2026-03-28T23:50:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-693-fix-learning-prompt-false-positive--matc.md
- **Context:** Initial task creation
