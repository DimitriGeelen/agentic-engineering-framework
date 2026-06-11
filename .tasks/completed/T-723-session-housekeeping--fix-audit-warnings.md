---
id: T-723
name: "Session housekeeping — fix audit warnings, episodic gaps, fabric edges"
description: >
  Session housekeeping — fix audit warnings, episodic gaps, fabric edges

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-29T19:11:03Z
last_update: '2026-06-11T22:24:28Z'
date_finished: 2026-03-29T19:30:27Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-723: Session housekeeping — fix audit warnings, episodic gaps, fabric edges

## Context

Fix recurring audit warnings: 4 stale fabric edges in lib-notify.yaml (wrong path format + inverted deps), enrich skeleton episodic summaries for completed tasks, fix C-001 inception artifact references.

## Acceptance Criteria

### Agent
- [x] lib-notify.yaml fabric card has correct dependency direction and project-root-relative paths
- [x] `fw fabric drift` reports 0 stale edges for notify
- [x] Skeleton episodic summaries enriched with real content (9 tasks: T-444,452,453,519,520,521,592,593,596)
- [x] C-001 inception artifact references — current audit passes (historical trends only)
- [x] `fw audit` shows no new FAIL items

## Verification

python3 -c "import yaml; yaml.safe_load(open('.fabric/components/lib-notify.yaml'))"
bin/fw fabric drift 2>&1 | grep -q "stale: 0"

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

### 2026-03-29T19:11:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-723-session-housekeeping--fix-audit-warnings.md
- **Context:** Initial task creation

### 2026-03-29T19:30:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-39416e3d
- **Timestamp:** 2026-06-02T15:04:33Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw fabric drift 2>&1 | grep -q "stale: 0"`
