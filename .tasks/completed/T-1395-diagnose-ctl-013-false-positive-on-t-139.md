---
id: T-1395
name: "Diagnose CTL-013 false-positive on T-1394 verification re-run"
description: >
  Diagnose CTL-013 false-positive on T-1394 verification re-run

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-004]
related_tasks: []
created: 2026-04-23T12:42:48Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-23T12:54:49Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1395: Diagnose CTL-013 false-positive on T-1394 verification re-run

## Context

After T-1394 closed, audit CTL-013 reports `T-1394 verification re-run: 1 command(s) failing` consistently. Manual extraction of the same commands and identical eval-from-PROJECT_ROOT all pass. Need to identify which command audit thinks is failing — adding debug print to audit.sh CTL-013 block.

## Acceptance Criteria

### Agent
- [x] Add `FW_AUDIT_VERIFY_DEBUG` flag to audit CTL-013 block that prints the failing command
- [x] Identify the actual failing command for T-1394 via debug output
- [x] Fix root cause (either in audit.sh or in T-1394 verification)
- [x] CTL-013 reports T-1394 verification re-run as fully passing

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

bash -n agents/audit/audit.sh
grep -q "FW_AUDIT_VERIFY_DEBUG" agents/audit/audit.sh
PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework TASKS_DIR=/opt/999-Agentic-Engineering-Framework/.tasks CONTEXT_DIR=/opt/999-Agentic-Engineering-Framework/.context bats tests/unit/audit_trend_window.bats >/tmp/t1395.out 2>&1 && grep -q "^ok 2" /tmp/t1395.out

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

### 2026-04-23T12:42:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1395-diagnose-ctl-013-false-positive-on-t-139.md
- **Context:** Initial task creation

### 2026-04-23T12:54:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-505552d5
- **Timestamp:** 2026-06-02T14:57:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
