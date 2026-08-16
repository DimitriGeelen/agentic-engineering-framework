---
id: T-1240
name: "Fix Watchtower tasks page string sort — T-1000+ tasks hidden between T-1xx"
description: >
  Fix Watchtower tasks page string sort — T-1000+ tasks hidden between T-1xx

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-13T19:27:08Z
last_update: '2026-08-16T22:24:26Z'
date_finished: 2026-04-13T19:41:55Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:43Z'
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
  - ts: '2026-08-16T22:24:26Z'
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

# T-1240: Fix Watchtower tasks page string sort — T-1000+ tasks hidden between T-1xx

## Context

Task IDs sorted as strings — T-1000 appears between T-100 and T-101 instead of after T-999.
9 instances across web/ need fixing. Related: T-675 (regex fix for 3+ digit IDs).

## Acceptance Criteria

### Agent
- [x] Add `task_id_sort_key()` helper to `web/shared.py` for numeric task ID sorting
- [x] Fix all 9 string-sort instances in web/ to use numeric sort
- [x] /tasks page shows T-1000+ after T-999 (not interleaved with T-1xx)
- [x] Web tests pass (142/142)

<!-- T-1462: rubber-stamp converted to Agent AC + verification command per CLAUDE.md rule.
     Original Human AC: "[RUBBER-STAMP] Tasks page shows T-1000+ tasks at bottom" — text mechanical (curl + parse). -->

## Verification

python3 -c "from web.shared import task_id_sort_key; assert task_id_sort_key('T-1000') > task_id_sort_key('T-999')"
python3 -c "from web.shared import task_id_sort_key; assert task_id_sort_key('T-100') < task_id_sort_key('T-1000')"
curl -sf "$(bin/fw watchtower url)/tasks?view=list&sort=id" | python3 -c "import sys, re; html=sys.stdin.read(); nums=[int(x) for x in re.findall(r'T-(\d+)', html)]; high=[n for n in nums if n>=1000]; low=[n for n in nums if 900<=n<1000]; assert high and low and max(i for i,n in enumerate(nums) if n>=1000) > max(i for i,n in enumerate(nums) if 900<=n<1000), 'T-1xxx hidden between T-9xx'"

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

### 2026-04-13T19:27:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1240-fix-watchtower-tasks-page-string-sort--t.md
- **Context:** Initial task creation

### 2026-04-13T19:41:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6dc38572
- **Timestamp:** 2026-06-02T14:56:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
