---
id: T-206
name: "Fix add-learning YAML indentation + ID bug"
description: >
  Fix add-learning YAML indentation + ID bug

status: work-completed
workflow_type: build
owner: agent
horizon: null
related_tasks: []
created: 2026-02-19T22:54:29Z
last_update: '2026-06-11T22:24:06Z'
date_finished: 2026-02-19T22:56:28Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=3 (body:fw-recall-or-memory-link); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-206: Fix add-learning YAML indentation + ID bug

## Context

`fw context add-learning` had two bugs: grep pattern expected 2-space indent but file uses none (ID always restarted at L-001), and awk output used 2-space indent nesting new entries under previous entry. Broke YAML parsing, caused Watchtower learnings page to show 0 entries.

## Acceptance Criteria

### Agent
- [x] learnings.yaml parses without error (59 entries, no duplicate IDs)
- [x] `fw context add-learning` assigns correct next ID (L-062+)
- [x] New entries written with correct indentation (no nesting)
- [x] Watchtower /learnings page shows all 59 learnings

## Verification

python3 -c "import yaml; data=yaml.safe_load(open('.context/project/learnings.yaml')); assert len(data['learnings'])>=59, f'Expected 59+, got {len(data[\"learnings\"])}'"
grep -q "^- id: L-059" .context/project/learnings.yaml
grep -q "^- id: L-061" .context/project/learnings.yaml

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

### 2026-02-19T22:54:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-206-fix-add-learning-yaml-indentation--id-bu.md
- **Context:** Initial task creation

### 2026-02-19T22:56:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3f13a9d0
- **Timestamp:** 2026-06-02T15:00:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
