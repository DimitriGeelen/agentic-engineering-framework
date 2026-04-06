---
id: T-973
name: "Review-before-decide gate — fw inception decide requires fw task review first"
description: >
  Review-before-decide gate — fw inception decide requires fw task review first

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-06T19:53:57Z
last_update: 2026-04-06T19:53:57Z
date_finished: null
---

# T-973: Review-before-decide gate — fw inception decide requires fw task review first

## Context

Agent in freshly initialized WorkshopDesigner project gave raw `fw inception decide` command instead of using `fw task review`. T-679 rule exists but is advisory-only. Need structural gate: `fw inception decide` refuses unless `fw task review` was called first (marker file). Also: `fw task review` must output the full decision command alongside QR for inception tasks. Related: T-557, T-679, G-019.

## Acceptance Criteria

### Agent
- [x] `review.sh` creates `.context/working/.reviewed-T-XXX` marker when `emit_review()` runs
- [x] `review.sh` outputs full `fw inception decide` command for inception tasks alongside QR code
- [x] `inception.sh` `do_inception_decide()` checks for marker and blocks with helpful message if missing
- [x] Marker is cleaned up after decision is recorded
- [x] Verification commands pass

## Verification

grep -q '.reviewed-' .agentic-framework/lib/review.sh
grep -q '.reviewed-' .agentic-framework/lib/inception.sh
grep -q 'bin/fw inception decide' .agentic-framework/lib/review.sh

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

### 2026-04-06T19:53:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-973-review-before-decide-gate--fw-inception-.md
- **Context:** Initial task creation
