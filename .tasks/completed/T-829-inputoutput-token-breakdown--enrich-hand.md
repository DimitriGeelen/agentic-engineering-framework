---
id: T-829
name: "Input/output token breakdown — enrich handover frontmatter and timeline display"
description: >
  Input/output token breakdown — enrich handover frontmatter and timeline display

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [agents/handover/handover.sh, web/blueprints/timeline.py, 
      web/templates/timeline.html]
related_tasks: []
created: 2026-04-03T23:53:55Z
last_update: '2026-06-11T22:24:30Z'
date_finished: 2026-04-03T23:57:12Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-829: Input/output token breakdown — enrich handover frontmatter and timeline display

## Context

Build task from T-828 GO decision. Add input/cache_read/cache_create/output token counts to handover frontmatter and display breakdown in /timeline. See `docs/reports/T-828-token-breakdown-inception.md`.

## Acceptance Criteria

### Agent
- [x] handover.sh extracts input/cache_read/cache_create/output from costs_main current
- [x] Handover frontmatter includes 4 new numeric token fields
- [x] timeline.py reads breakdown fields and passes to template
- [x] timeline.html shows token breakdown (tooltip on badge + detail panel when expanded)
- [x] Graceful fallback for old handovers without breakdown fields
- [x] Token breakdown visible on timeline session cards (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

grep -q "token_input" agents/handover/handover.sh
grep -q "token_input" web/blueprints/timeline.py
curl -sf http://localhost:3000/timeline | grep -q "token\|Token"

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

### 2026-04-03T23:53:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-829-inputoutput-token-breakdown--enrich-hand.md
- **Context:** Initial task creation

### 2026-04-03T23:57:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4c15c8fc
- **Timestamp:** 2026-06-02T15:05:07Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `curl -sf http://localhost:3000/timeline | grep -q "token\|Token"`
