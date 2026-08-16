---
id: T-365
name: "Watchtower /docs route for generated documentation"
description: >
  Add /docs route to Watchtower rendering generated component docs grouped by subsystem.
  Uses existing markdown2 rendering. Index page + individual component doc pages.
  See docs/reports/T-362-auto-doc-generation.md

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [documentation, watchtower, web]
components: [web/app.py]
related_tasks: []
created: 2026-03-08T22:03:31Z
last_update: '2026-08-16T22:25:29Z'
date_finished: 2026-03-08T22:21:47Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-365: Watchtower /docs route for generated documentation

## Context

From T-362. Serves generated docs via Watchtower with subsystem grouping.

## Acceptance Criteria

### Agent
- [x] `/docs/generated` route shows index grouped by subsystem with component count
- [x] `/docs/generated/<card_name>` route renders individual component doc
- [x] Blueprint registered in web/app.py
- [x] Templates: docs_index.html (index) and docs_detail.html (detail with fabric link)

### Human
- [x] [RUBBER-STAMP] Docs index page looks good
  **Steps:**
  1. Open http://localhost:3000/docs/generated
  **Expected:** 127 components grouped by subsystem, type badges, purpose excerpts
  **If not:** Screenshot

## Verification

curl -sf http://localhost:3000/docs/generated | grep -q "Component Reference Docs"
curl -sf http://localhost:3000/docs/generated/budget-gate | grep -q "budget-gate"
grep -q "docs_bp" web/app.py

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

### 2026-03-08T22:03:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-365-watchtower-docs-route-for-generated-docu.md
- **Context:** Initial task creation

### 2026-03-08T22:17:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-08T22:21:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:13Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-36e80b62
- **Timestamp:** 2026-06-02T15:02:24Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf http://localhost:3000/docs/generated | grep -q "Component Reference Docs"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf http://localhost:3000/docs/generated/budget-gate | grep -q "budget-gate"`
