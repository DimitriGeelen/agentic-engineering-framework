---
id: T-515
name: "Fix phantom aef binary name and add post-install verification"
description: >
  Fix phantom aef binary name and add post-install verification

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-21T16:00:52Z
last_update: 2026-03-21T16:00:52Z
date_finished: null
---

# T-515: Fix phantom aef binary name and add post-install verification

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] No "aef" binary references in install.sh (already verified: none exist)
- [x] verify() function has 3-step verification with specific fix commands
- [x] install.sh syntax valid (bash -n)

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

### 2026-03-21T16:00:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /home/dimitri-mint-dev/.agentic-framework/.tasks/active/T-515-fix-phantom-aef-binary-name-and-add-post.md
- **Context:** Initial task creation
