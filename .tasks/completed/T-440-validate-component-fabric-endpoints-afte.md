---
id: T-440
name: "Validate Component Fabric endpoints after refactoring updates"
description: >
  7 components were updated during refactoring (T-423 through T-427). Validate all
  Component Fabric endpoints are still in place and the update mechanism is working.
  Check fabric cards match actual file locations, deps are correct, and drift detection
  works.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [fabric, validation, watchtower]
components: []
related_tasks: []
created: 2026-03-11T22:09:10Z
last_update: '2026-08-16T22:25:31Z'
date_finished: 2026-03-11T22:56:36Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:21Z'
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
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:31Z'
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
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-440: Validate Component Fabric endpoints after refactoring updates

## Context

Validate fabric health after T-412 through T-431 refactoring. Fix stale edges, register missing components, ensure all endpoints work.

## Acceptance Criteria

### Agent
- [x] Fabric drift reports 0 unregistered, 0 orphaned, 0 stale edges
- [x] Fixed 4 stale edges (2 docgen directory refs, 2 missing JS card targets)
- [x] Registered missing components (markdown-render.js, generate_article.py, generate_component.py)
- [x] Enriched docgen cards with purpose, subsystem, tags
- [x] All fabric web endpoints respond 200 (/fabric, /fabric/graph, component details)
- [x] All recently-modified component locations match actual file paths

### Human
- [x] [RUBBER-STAMP] Fabric overview page renders correctly
  **Steps:**
  1. Open http://localhost:3000/fabric in browser
  2. Verify subsystem counts and component table load
  **Expected:** All subsystems listed, component table populated
  **If not:** Check Flask logs at /tmp/watchtower.log

## Verification

# Drift detection clean
fw fabric drift 2>&1 | grep -q 'stale: 0'
# Fabric endpoints respond
curl -sf http://localhost:3000/fabric > /dev/null
curl -sf http://localhost:3000/fabric/graph > /dev/null
# Component detail pages for recently modified files
curl -sf http://localhost:3000/fabric/component/shared > /dev/null
curl -sf http://localhost:3000/fabric/component/cockpit > /dev/null
curl -sf http://localhost:3000/fabric/component/quality > /dev/null

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

### 2026-03-11T22:09:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-440-validate-component-fabric-endpoints-afte.md
- **Context:** Initial task creation

### 2026-03-11T22:48:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-11T22:56:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-93de7d71
- **Timestamp:** 2026-06-02T15:02:51Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 6

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 4
     - evidence: `curl -sf http://localhost:3000/fabric > /dev/null`
  2. **empty-output-success** (partial, heuristic) @ Verification:line 5
     - evidence: `curl -sf http://localhost:3000/fabric/graph > /dev/null`
  3. **empty-output-success** (partial, heuristic) @ Verification:line 7
     - evidence: `curl -sf http://localhost:3000/fabric/component/shared > /dev/null`
  4. **empty-output-success** (partial, heuristic) @ Verification:line 8
     - evidence: `curl -sf http://localhost:3000/fabric/component/cockpit > /dev/null`
  5. **empty-output-success** (partial, heuristic) @ Verification:line 9
     - evidence: `curl -sf http://localhost:3000/fabric/component/quality > /dev/null`
  6. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `fw fabric drift 2>&1 | grep -q 'stale: 0'`
