---
id: T-1516
name: "Refresh D13 audit guidance to point at T-1514 sweep + T-1515 root-cause closure"
description: >
  Refresh D13 audit guidance to point at T-1514 sweep + T-1515 root-cause closure

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-26T20:39:52Z
last_update: 2026-04-26T20:40:55Z
date_finished: 2026-04-26T20:40:55Z
---

# T-1516: Refresh D13 audit guidance to point at T-1514 sweep + T-1515 root-cause closure

## Context

D13 audit comment says class B requires "manual fix: agents/task-create/update-task.sh --status work-completed --skip-sovereignty; underlying do_inception_decide bug deserves RCA". Both halves are now stale: T-1514 made the sweep handle class B mechanically, and T-1515 closed the underlying bug. Update the comment + the warn message to point at the canonical recovery path.

## Acceptance Criteria

### Agent
- [x] D13 comment block in `agents/audit/audit.sh` reflects T-1514 sweep + T-1515 root-cause closure (no longer says "manual fix" or "deserves RCA")
- [x] Warn message recommends `bin/fw inception sweep` as the canonical recovery for both classes A and B

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Stale guidance removed
test -z "$(grep -E 'manual fix.*--skip-sovereignty|deserves RCA' agents/audit/audit.sh || true)"
# Canonical recovery path present in warn message
grep -q "fw inception sweep" agents/audit/audit.sh
# T-1514 + T-1515 cited in comment block
grep -q "T-1514" agents/audit/audit.sh
grep -q "T-1515" agents/audit/audit.sh

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

### 2026-04-26T20:39:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1516-refresh-d13-audit-guidance-to-point-at-t.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-889217f3
- **Timestamp:** 2026-06-02T14:58:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T20:40:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** D13 guidance refreshed; verifications pass
