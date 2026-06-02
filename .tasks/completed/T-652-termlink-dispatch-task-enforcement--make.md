---
id: T-652
name: "TermLink dispatch task enforcement — make --task mandatory in fw termlink dispatch"
description: >
  T-630 GO build task 3: Make --task flag mandatory in fw termlink dispatch. Workers spawned without task reference have zero governance. Add task requirement + enforcement language to dispatch preamble. ~8 lines changed in lib/dispatch.sh. Related: T-630, T-650, T-651.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-28T09:45:53Z
last_update: 2026-03-28T09:48:20Z
date_finished: 2026-03-28T09:48:20Z
---

# T-652: TermLink dispatch task enforcement — make --task mandatory in fw termlink dispatch

## Context

T-630 GO build task 3. TermLink workers are full Claude Code sessions with zero inherited governance. Make `--task` mandatory.

## Acceptance Criteria

### Agent
- [x] `cmd_dispatch()` in `agents/termlink/termlink.sh` validates `--task` is provided
- [x] Missing `--task` produces clear error message
- [x] Vendored copy synced to `.agentic-framework/agents/termlink/`
- [x] `bash -n` passes on modified script

## Verification

bash -n agents/termlink/termlink.sh
grep -q 'Missing --task' agents/termlink/termlink.sh

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

### 2026-03-28T09:45:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-652-termlink-dispatch-task-enforcement--make.md
- **Context:** Initial task creation

### 2026-03-28T09:48:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1357f53d
- **Timestamp:** 2026-06-02T15:04:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
