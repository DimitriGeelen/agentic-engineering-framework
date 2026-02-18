---
id: T-165
name: "Fix 20 broken Watchtower task links — YAML quoting bugs in task and episodic files"
description: >
  Fix 20 broken Watchtower task links — YAML quoting bugs in task and episodic files

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T14:02:02Z
last_update: 2026-02-18T14:05:23Z
date_finished: 2026-02-18T14:05:23Z
---

# T-165: Fix 20 broken Watchtower task links — YAML quoting bugs in task and episodic files

## Context

User reported T-152 and T-153 inaccessible. Investigation found 20 broken task links:
10 returning 500 (bad episodic YAML double-double-quotes), 10 returning 404 (unquoted colons in task name frontmatter).

## Acceptance Criteria

- [x] All 20 broken task links fixed (10 x 500, 10 x 404)
- [x] Root cause fixed in episodic.sh (strip existing quotes before re-quoting)
- [x] Root cause fixed in create-task.sh (quote name in fallback template)
- [x] Defensive fix in tasks.py (try/except on episodic YAML loading)
- [x] Full sweep: 164/164 task links return 200

## Verification

# All previously-broken tasks return 200
curl -sf http://localhost:3000/tasks/T-152 -o /dev/null
curl -sf http://localhost:3000/tasks/T-153 -o /dev/null
curl -sf http://localhost:3000/tasks/T-045 -o /dev/null
curl -sf http://localhost:3000/tasks/T-133 -o /dev/null
# Episodic YAML files parse correctly
python3 -c "import yaml; yaml.safe_load(open('.context/episodic/T-152.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('.context/episodic/T-153.yaml'))"

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

### 2026-02-18T14:02:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-165-fix-20-broken-watchtower-task-links--yam.md
- **Context:** Initial task creation

### 2026-02-18T14:05:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
