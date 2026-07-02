---
id: T-1118
name: "PostToolUse scanner: detect TodoWrite/TaskCreate usage in session transcript"
description: >
  PostToolUse scanner: detect TodoWrite/TaskCreate usage in session transcript

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/context/audit-task-tools.sh, bin/fw, 
      tests/unit/audit_task_tools.bats]
related_tasks: []
created: 2026-04-12T07:00:59Z
last_update: '2026-06-11T22:23:40Z'
date_finished: 2026-04-12T07:03:10Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1118: PostToolUse scanner: detect TodoWrite/TaskCreate usage in session transcript

## Context

Belt-and-braces detector for T-1115/T-1117. Even with the PreToolUse
block on TodoWrite/TaskCreate, sub-agents can bypass hooks (issue 45427
Failure Mode 1). This PostToolUse scanner detects any successful
TodoWrite/TaskCreate call and emits a warning via `additionalContext`.

## Acceptance Criteria

### Agent
- [x] `agents/context/audit-task-tools.sh` exists, reads stdin JSON,
      detects TodoWrite/TaskCreate/TaskUpdate tool_name, outputs
      additionalContext JSON warning, always exits 0
- [x] Ignores non-matching tool names (no output, exit 0)
- [x] `tests/unit/audit_task_tools.bats` passes with 10 test cases
- [x] Routable via `bin/fw hook audit-task-tools`
- [x] `fw doctor` passes (0 failures)

## Verification

test -f agents/context/audit-task-tools.sh
echo '{"tool_name":"TodoWrite"}' | bash agents/context/audit-task-tools.sh | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'additionalContext' in d"
echo '{"tool_name":"Bash"}' | bash agents/context/audit-task-tools.sh | python3 -c "import json,sys; assert sys.stdin.read().strip() == ''"
bats tests/unit/audit_task_tools.bats

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

### 2026-04-12T07:00:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1118-posttooluse-scanner-detect-todowritetask.md
- **Context:** Initial task creation

### 2026-04-12T07:03:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-58f80e50
- **Timestamp:** 2026-06-02T14:55:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
