---
id: T-827
name: "Timeline per-session token delta — show session-specific token and turn counts
  alongside cumulative"
description: >
  Timeline per-session token delta — show session-specific token and turn counts alongside
  cumulative

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [web/blueprints/timeline.py, web/templates/timeline.html]
related_tasks: []
created: 2026-04-03T23:43:16Z
last_update: '2026-06-11T22:24:30Z'
date_finished: 2026-04-03T23:45:37Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:30Z'
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

# T-827: Timeline per-session token delta — show session-specific token and turn counts alongside cumulative

## Context

Refinement of T-826. The `token_usage` field shows cumulative totals — add per-session deltas by subtracting consecutive session values.

## Acceptance Criteria

### Agent
- [x] timeline.py parses `token_usage` string into numeric values
- [x] Per-session delta calculated by subtracting previous session's cumulative
- [x] Template shows both per-session delta and cumulative total
- [x] /timeline page loads without errors
- [x] Per-session token deltas display correctly on timeline (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

grep -q "session_tokens" web/blueprints/timeline.py
grep -q "session_tokens" web/templates/timeline.html
curl -sf http://localhost:3000/timeline | grep -q "session"

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

### 2026-04-03T23:43:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-827-timeline-per-session-token-delta--show-s.md
- **Context:** Initial task creation

### 2026-04-03T23:45:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4a187d3b
- **Timestamp:** 2026-06-02T15:05:06Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `curl -sf http://localhost:3000/timeline | grep -q "session"`
