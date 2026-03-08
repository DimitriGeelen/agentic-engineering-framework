---
id: T-354
name: "Tighten task gate: validate status + clear focus on completion"
description: >
  Tighten task gate: validate status + clear focus on completion

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
components: [agents/context/check-active-task.sh, agents/task-create/update-task.sh]
related_tasks: []
created: 2026-03-08T17:11:25Z
last_update: 2026-03-08T17:20:25Z
date_finished: 2026-03-08T17:20:25Z
---

# T-354: Tighten task gate: validate status + clear focus on completion

## Context

T-353 investigation revealed two structural gaps in task gate enforcement: (1) check-active-task.sh validates file existence in active/ but not task status — work-completed tasks pass the gate; (2) focus is never cleared on task completion, leaving stale focus as a bypass vector. 24/36 active tasks (67%) are work-completed, creating a wide bypass surface. Design report: `/tmp/fw-agent-gate-design.md`. Related: G-013, L-062, L-034.

## Acceptance Criteria

### Agent
- [x] Option A: check-active-task.sh blocks Write/Edit when focused task has status `captured` or `work-completed`
- [x] Option B: update-task.sh clears focus when task fully completes (not partial-complete)
- [x] Existing workflows unbroken: `started-work` and `issues` tasks still pass the gate
- [x] Legacy tasks without `status:` field produce warning, not block

## Verification

# Option A: work-completed task blocks the gate
tmpdir=$(mktemp -d) && mkdir -p "$tmpdir/.tasks/active" "$tmpdir/.context/working" && echo -e "---\nid: T-999\nstatus: work-completed\n---" > "$tmpdir/.tasks/active/T-999-test.md" && echo "current_task: T-999" > "$tmpdir/.context/working/focus.yaml" && echo '{"tool_name":"Write","tool_input":{"file_path":"'"$tmpdir"'/test.txt"}}' | PROJECT_ROOT="$tmpdir" /opt/999-Agentic-Engineering-Framework/agents/context/check-active-task.sh 2>&1; test $? -eq 2 && rm -rf "$tmpdir"
# Option A: started-work task passes the gate
tmpdir=$(mktemp -d) && mkdir -p "$tmpdir/.tasks/active" "$tmpdir/.context/working" && echo -e "---\nid: T-999\nstatus: started-work\n---" > "$tmpdir/.tasks/active/T-999-test.md" && echo "current_task: T-999" > "$tmpdir/.context/working/focus.yaml" && echo '{"tool_name":"Write","tool_input":{"file_path":"'"$tmpdir"'/test.txt"}}' | PROJECT_ROOT="$tmpdir" /opt/999-Agentic-Engineering-Framework/agents/context/check-active-task.sh 2>&1; test $? -eq 0 && rm -rf "$tmpdir"

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

### 2026-03-08T17:11:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-354-tighten-task-gate-validate-status--clear.md
- **Context:** Initial task creation

### 2026-03-08T17:20:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
