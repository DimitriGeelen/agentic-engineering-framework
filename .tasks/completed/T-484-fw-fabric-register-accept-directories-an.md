---
id: T-484
name: "fw fabric register: accept directories and recursively register files"
description: >
  fw fabric register only accepts files. Passing a directory gives 'File not found'. Should detect directories and recursively register eligible files (filtered by common code extensions, skip node_modules/.git/etc).

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [usability, fabric]
components: [agents/fabric/lib/register.sh]
related_tasks: []
created: 2026-03-14T15:13:30Z
last_update: 2026-03-14T15:16:30Z
date_finished: 2026-03-14T15:16:30Z
---

# T-484: fw fabric register: accept directories and recursively register files

## Context

User field report: `fw fabric register /path/to/dir` gives "File not found" because `do_register()` only handles files. Should detect directories and register all eligible files recursively, skipping non-code and common exclusions.

## Acceptance Criteria

### Agent
- [x] `fw fabric register <dir>` recursively registers eligible files
- [x] Skips common exclusions (node_modules, .git, __pycache__, .venv, etc.)
- [x] Filters to code-like extensions (.py, .sh, .js, .ts, .yaml, .yml, .md, .html, .css, etc.)
- [x] Reports count of files registered vs skipped
- [x] Single file registration still works unchanged
- [x] Syntax check passes on register.sh

## Verification

bash -n agents/fabric/lib/register.sh
grep -q 'is_dir\|\ -d ' agents/fabric/lib/register.sh

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

### 2026-03-14T15:13:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-484-fw-fabric-register-accept-directories-an.md
- **Context:** Initial task creation

### 2026-03-14T15:16:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
