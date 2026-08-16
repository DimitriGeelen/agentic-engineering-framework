---
id: T-328
name: "GitHub quick wins: topics, Discussions, v1.0.0 release, AGENTS.md"
description: >
  Execute Tier 1 visibility actions: (1) Set 20 GitHub topics on repo, (2) Rewrite
  About description, (3) Enable GitHub Discussions with Q&A/Ideas/Show&Tell categories,
  (4) Create tagged release v1.0.0, (5) Add AGENTS.md file for cross-agent compatibility.
  All under 1 hour total. Ref: docs/reports/T-327-visibility-strategy.md

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-05T01:12:24Z
last_update: '2026-08-16T22:25:28Z'
date_finished: 2026-03-05T01:20:37Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-328: GitHub quick wins: topics, Discussions, v1.0.0 release, AGENTS.md

## Context

Tier 1 visibility actions from T-327 GO decision. Ref: `docs/reports/T-327-visibility-strategy.md`

## Acceptance Criteria

### Agent
- [x] GitHub repo topics set (20 topics via gh API)
- [x] GitHub repo description updated
- [x] GitHub Discussions enabled with categories
- [x] Release v1.0.0 tagged and published
- [x] AGENTS.md file created in repo root

### Human
- [x] Topics appear correctly on GitHub repo page
- [x] Discussions tab visible and usable

## Verification

test -f AGENTS.md
grep -qi "agentic" AGENTS.md

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

### 2026-03-05T01:12:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-328-github-quick-wins-topics-discussions-v10.md
- **Context:** Initial task creation

### 2026-03-05T01:13:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-05T01:20:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ef185731
- **Timestamp:** 2026-06-02T15:02:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
