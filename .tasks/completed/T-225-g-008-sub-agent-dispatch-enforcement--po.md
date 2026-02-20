---
id: T-225
name: "G-008: Sub-agent dispatch enforcement — PostToolUse guard on Task results"
description: >
  G-008: Sub-agent dispatch enforcement — PostToolUse guard on Task results

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-02-20T11:16:30Z
last_update: 2026-02-20T11:18:53Z
date_finished: 2026-02-20T11:18:53Z
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
