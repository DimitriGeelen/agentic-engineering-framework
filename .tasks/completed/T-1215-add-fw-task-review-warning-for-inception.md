---
id: T-1215
name: "Add fw task review warning for inception tasks without Recommendation section (T-1213 GO)"
description: >
  Add fw task review warning for inception tasks without Recommendation section (T-1213 GO)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/review.sh]
related_tasks: []
created: 2026-04-13T09:20:35Z
last_update: 2026-04-13T09:21:45Z
date_finished: 2026-04-13T09:21:45Z
---

# T-1215: Add fw task review warning for inception tasks without Recommendation section (T-1213 GO)

## Context

T-1213 GO, RC-2. `fw task review` creates the review marker but doesn't check if inception tasks
have a substantive `## Recommendation`. Add a warning (not a block) so the agent knows the human
will see a bare approvals card.

## Acceptance Criteria

### Agent
- [x] `lib/review.sh` checks for `## Recommendation` on inception tasks
- [x] Warning emitted when recommendation is missing/empty (not blocking)
- [x] Existing review flow still works (marker created, URL emitted)

## Verification

# review.sh still sources correctly
grep -q 'emit_review' lib/review.sh

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

### 2026-04-13T09:20:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1215-add-fw-task-review-warning-for-inception.md
- **Context:** Initial task creation

### 2026-04-13T09:21:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fca4668c
- **Timestamp:** 2026-06-02T14:55:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
