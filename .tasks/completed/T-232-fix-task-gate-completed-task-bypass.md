---
id: T-232
name: "Fix task-gate completed-task bypass"
description: >
  Fix task-gate completed-task bypass

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/context/check-active-task.sh]
related_tasks: []
created: 2026-02-21T19:59:53Z
last_update: '2026-08-16T22:25:01Z'
date_finished: 2026-02-21T20:01:25Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-232: Fix task-gate completed-task bypass

## Context

check-active-task.sh only checked if CURRENT_TASK was non-empty. A completed task ID in focus.yaml passed the gate. G-013.

## Acceptance Criteria

### Agent
- [x] check-active-task.sh validates task file exists in .tasks/active/
- [x] Completed task ID in focus → blocks Write/Edit with exit 2
- [x] Gap G-013 registered in gaps.yaml

## Verification

# Completed task T-012 should be blocked
echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/test.txt"}}' | PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework CURRENT_TASK_OVERRIDE=T-012 bash -c 'cd /opt/999-Agentic-Engineering-Framework && python3 -c "import yaml; d=yaml.safe_load(open(\".context/working/focus.yaml\")); orig=d.get(\"current_task\",\"\"); d[\"current_task\"]=\"T-012\"; yaml.dump(d,open(\".context/working/focus.yaml\",\"w\"))" && echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"/tmp/test.txt\"}}" | ./agents/context/check-active-task.sh 2>&1; rc=$?; python3 -c "import yaml; d=yaml.safe_load(open(\".context/working/focus.yaml\")); d[\"current_task\"]=\"T-232\"; yaml.dump(d,open(\".context/working/focus.yaml\",\"w\"))"; test $rc -eq 2'
# Gap G-013 exists in gaps.yaml
grep -q "G-013" .context/project/gaps.yaml

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

### 2026-02-21T19:59:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-232-fix-task-gate-completed-task-bypass.md
- **Context:** Initial task creation

### 2026-02-21T20:01:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5d170eb5
- **Timestamp:** 2026-06-02T15:01:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
