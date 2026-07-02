---
id: T-643
name: "Htmx-ify GO decision form — inline response on /approvals page"
description: >
  Htmx-ify GO decision form — inline response on /approvals page

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-27T12:21:37Z
last_update: '2026-06-11T22:24:26Z'
date_finished: 2026-03-27T12:22:36Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
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

# T-643: Htmx-ify GO decision form — inline response on /approvals page

## Context

T-636 Phase 2. GO decision forms on /approvals do a full page redirect. Make them htmx-friendly: return inline fragment when HX-Request header present, keep redirect for direct /inception page.

## Acceptance Criteria

### Agent
- [x] /inception/<T-XXX>/decide returns HTML fragment when HX-Request header present
- [x] Full redirect preserved when called without HX-Request (from inception detail page)
- [x] /approvals GO decision form uses hx-post for inline swap

## Verification

grep -q 'HX-Request' web/blueprints/inception.py

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

### 2026-03-27T12:21:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-643-htmx-ify-go-decision-form--inline-respon.md
- **Context:** Initial task creation

### 2026-03-27T12:22:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-19b45260
- **Timestamp:** 2026-06-02T15:04:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
