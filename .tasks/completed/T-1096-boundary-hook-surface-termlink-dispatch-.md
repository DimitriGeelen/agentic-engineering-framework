---
id: T-1096
name: "Boundary hook: surface TermLink dispatch read-only escape route in BLOCK message (G-027)"
description: >
  Extend agents/context/check-project-boundary.sh BLOCK message (the same one updated in T-1089 for write ops) to mention 'fw termlink dispatch --project /path --prompt cat README.md' as the read-only escape pattern. Currently agents must ask the human to authorize each cross-project read individually. Origin: G-027. Trigger: cross-session ring20-dashboard onboarding incident 2026-04-11 — agent needed to read sibling READMEs and had no documented escape.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/check-project-boundary.sh]
related_tasks: [T-1093, T-1089]
created: 2026-04-11T12:15:46Z
last_update: 2026-04-12T07:18:03Z
date_finished: 2026-04-12T07:18:03Z
---

# T-1096: Boundary hook: surface TermLink dispatch read-only escape route in BLOCK message (G-027)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Write/Edit block message in check-project-boundary.sh mentions
      TermLink dispatch as escape route for cross-project reads
- [x] Block message includes copy-pasteable example command
- [x] Existing tests still pass

## Verification

bash -c 'echo '"'"'{"tool_name":"Write","tool_input":{"file_path":"/opt/other/file.txt"}}'"'"' | PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework bash agents/context/check-project-boundary.sh 2>&1 | grep -q "termlink"'
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-11T12:15:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1096-boundary-hook-surface-termlink-dispatch-.md
- **Context:** Initial task creation

### 2026-04-12T07:16:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T07:18:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
