---
id: T-1394
name: "Audit trend analysis never decays — historical WARN/FAIL counted forever even
  when resolved"
description: >
  Audit trend analysis never decays — historical WARN/FAIL counted forever even when
  resolved

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-004]
related_tasks: []
created: 2026-04-23T12:21:41Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-23T12:25:22Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1394: Audit trend analysis never decays — historical WARN/FAIL counted forever even when resolved

## Context

`agents/audit/audit.sh` "TREND ANALYSIS" section scans ALL historical audit files (56 today) and counts every WARN/FAIL ever recorded. When an issue is fixed (e.g. T-1392 closed the "Uncommitted changes present" noise), the trend STILL reports "39 times" because it sums lifetime history. The trend becomes monotonically growing noise rather than a useful signal.

Fix: rolling 14-day window. Only count WARN/FAIL from audits in the last 14 days. Older audits are excluded — the issue either recurred recently (still relevant) or it's been resolved (drop it).

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` trend analysis filters past_audits to last N days (configurable via `FW_AUDIT_TREND_WINDOW_DAYS`, default 14)
- [x] Audits older than the window are excluded from trend counting
- [x] Bats unit test: when audit files exist with stale issues only outside the window, trend reports no repeated issues
- [x] Bats unit test: when issues recur within the window (3+ times), trend reports them
- [x] Trend output includes the window size in the summary header

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
test -f tests/unit/audit_trend_window.bats
bats tests/unit/audit_trend_window.bats >/tmp/t1394.out 2>&1 && grep -q "^ok 2" /tmp/t1394.out
grep -q "FW_AUDIT_TREND_WINDOW_DAYS" agents/audit/audit.sh

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

### 2026-04-23T12:21:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1394-audit-trend-analysis-never-decays--histo.md
- **Context:** Initial task creation

### 2026-04-23T12:25:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a3ef2d6e
- **Timestamp:** 2026-06-02T14:57:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
