---
id: T-465
name: "Fix settings.json hook generation — consumer gets 5/10 hooks"
description: >
  T-306 finding: hook generator in lib/init.sh only generates 5 of 10 hooks for consumer
  projects. Missing: budget-gate, plan blocker, pre-compact, dispatch guard, resume.
  Fix the generator to produce the complete hook set. Ref: docs/reports/T-306-framework-distribution-model.md
  Agent #4 findings.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [init, hooks, T-306]
components: []
related_tasks: []
created: 2026-03-12T18:34:24Z
last_update: '2026-08-16T22:25:31Z'
date_finished: 2026-03-12T20:59:36Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:22Z'
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
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-465: Fix settings.json hook generation — consumer gets 5/10 hooks

## Context

T-306 finding: generator missing hooks vs framework's own settings.json. Current gap: 1 missing hook (PostToolUse Write → check-fabric-new-file.sh). Original report said "5/10" but generator was updated since.

## Acceptance Criteria

### Agent
- [x] Generated settings.json matches framework's own hook count (11 hooks)
- [x] PostToolUse Write fabric-new-file hook added to generator
- [x] Generated JSON is valid
- [x] Hook count message updated (10 → 11, added "fabric new-file")

## Verification

grep -q "check-fabric-new-file" lib/init.sh
python3 -c "import json; json.loads(open('.claude/settings.json').read())"

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

### 2026-03-12T18:34:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-465-fix-settingsjson-hook-generation--consum.md
- **Context:** Initial task creation

### 2026-03-12T20:58:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-12T20:59:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c874ac19
- **Timestamp:** 2026-06-02T15:02:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
