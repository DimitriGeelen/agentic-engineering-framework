---
id: T-1075
name: "Fix project boundary false positive — TermLink commands inside loops/pipes"
description: >
  Fix project boundary false positive — TermLink commands inside loops/pipes

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-09T13:06:31Z
last_update: 2026-04-09T13:08:28Z
date_finished: 2026-04-09T13:08:28Z
---

# T-1075: Fix project boundary false positive — TermLink commands inside loops/pipes

## Context

R-037 concern. TermLink exception in check-project-boundary.sh only matches commands starting with `termlink`. Commands inside loops (`for n in ...; do termlink pty inject ...`) are blocked because the loop starts with `for`, not `termlink`. Discovered during T-1071 consumer upgrades.

## Acceptance Criteria

### Agent
- [x] TermLink exception matches commands containing `termlink` anywhere (not just at start)
- [x] Existing boundary tests still pass (23/23 original tests)
- [x] TermLink commands in loops/pipes are allowed (5 new tests: start, for-loop, semicolon, &&, fw termlink)

## Verification

bats tests/integration/check_project_boundary.bats
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-09T13:06:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1075-fix-project-boundary-false-positive--ter.md
- **Context:** Initial task creation

### 2026-04-09T13:08:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d814fc67
- **Timestamp:** 2026-06-02T14:54:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
