---
id: T-669
name: "Approvals page auto-refresh — htmx polling for live Tier 0 and Human AC updates"
description: >
  Approvals page auto-refresh — htmx polling for live Tier 0 and Human AC updates

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-28T18:01:21Z
last_update: '2026-08-16T22:25:36Z'
date_finished: 2026-03-28T18:06:01Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
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
  - ts: '2026-08-16T22:25:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-669: Approvals page auto-refresh — htmx polling for live Tier 0 and Human AC updates

## Context

The /approvals page shows Tier 0, GO decisions, and Human ACs but requires manual page refresh to see changes. Add htmx polling to auto-refresh, matching the pattern from /review/T-XXX (T-667).

## Acceptance Criteria

### Agent
- [x] Approvals page wraps dynamic content in a polling div
- [x] Polling interval is 10 seconds
- [x] `/approvals/content` endpoint returns fragment without wrapper
- [x] Page updates show new Tier 0 approvals and AC state changes without full reload

## Verification

grep -q hx-trigger web/templates/approvals.html
grep -q approvals_content web/blueprints/approvals.py

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

### 2026-03-28T18:01:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-669-approvals-page-auto-refresh--htmx-pollin.md
- **Context:** Initial task creation

### 2026-03-28T18:06:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-34d72d67
- **Timestamp:** 2026-06-02T15:04:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
