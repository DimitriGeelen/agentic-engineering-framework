---
id: T-225
name: "G-008: Sub-agent dispatch enforcement — PostToolUse guard on Task results"
description: >
  G-008: Sub-agent dispatch enforcement — PostToolUse guard on Task results

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-02-20T11:16:30Z
last_update: '2026-08-16T22:24:58Z'
date_finished: 2026-02-20T11:18:53Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-225: G-008: Sub-agent dispatch enforcement — PostToolUse guard on Task results

## Context

G-008: Sub-agent dispatch protocol has no structural enforcement. Three incidents (T-073, T-158, T-170) caused context explosion from unbounded tool output. The preamble (`agents/dispatch/preamble.md`) exists but nothing enforces its inclusion or guards against oversized results. Build a PostToolUse hook on Task/TaskOutput to warn on large results.

## Acceptance Criteria

### Agent
- [x] PostToolUse hook script exists at `agents/context/check-dispatch.sh`
- [x] Hook warns when Task/TaskOutput result exceeds 5K chars
- [x] Hook registered in `.claude/settings.json` as PostToolUse matcher for Task|TaskOutput
- [x] G-008 status updated to closed in gaps.yaml
- [x] Script is executable and handles missing/malformed input gracefully

## Verification

test -x agents/context/check-dispatch.sh
python3 -c "import json; d=json.load(open('.claude/settings.json')); ptus=[h for h in d['hooks']['PostToolUse'] if 'Task' in h.get('matcher','')]; assert len(ptus)>0, 'No Task PostToolUse hook'"
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/gaps.yaml')); g8=[g for g in d['gaps'] if g['id']=='G-008'][0]; assert g8['status']=='closed'"

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

### 2026-02-20T11:16:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-225-g-008-sub-agent-dispatch-enforcement--po.md
- **Context:** Initial task creation

### 2026-02-20T11:18:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-711f7d1b
- **Timestamp:** 2026-06-02T15:01:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
