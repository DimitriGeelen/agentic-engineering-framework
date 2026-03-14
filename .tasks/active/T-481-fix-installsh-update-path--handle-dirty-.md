---
id: T-481
name: "Fix install.sh update path — handle dirty state and macOS filemode"
description: >
  install.sh do_install() fails on update when ~/.agentic-framework has dirty files. Root causes: (1) git pull with no stash/reset — framework install dir is not user code, should always match origin. (2) macOS core.fileMode=true reports permission diffs as local changes. Fix: make update path robust.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [portability, bugfix, installer]
components: []
related_tasks: []
created: 2026-03-14T14:48:51Z
last_update: 2026-03-14T14:48:51Z
date_finished: null
---

# T-481: Fix install.sh update path — handle dirty state and macOS filemode

## Context

macOS field report: `curl ... | bash` installer fails on second run. `do_install()` does bare `git pull` which fails when `core.fileMode=true` (macOS default) reports permission diffs as local changes. The framework install dir (`~/.agentic-framework`) is not user code — it should always match origin. Related: T-480 (macOS compat), T-482 (install model inception).

## Acceptance Criteria

### Agent
- [x] `do_install()` update path resets to origin (not `git pull`)
- [x] `core.fileMode` set to false on fresh clones (macOS compat)
- [x] `core.fileMode` fixed on existing installs during update
- [x] Update shows old→new version (commit hash or tag)
- [x] install.sh passes `bash -n` syntax check

### Human
- [ ] [RUBBER-STAMP] Run installer twice on macOS — second run succeeds
  **Steps:**
  1. `rm -rf ~/.agentic-framework` (clean slate)
  2. `curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash`
  3. Run the same curl command again
  **Expected:** Second run shows "Existing installation found — updating..." and completes without error
  **If not:** Paste the error output

## Verification

bash -n install.sh
grep -q 'core.fileMode' install.sh
grep -q 'reset --hard' install.sh
! grep -q 'git.*pull' install.sh

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

### 2026-03-14T14:48:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-481-fix-installsh-update-path--handle-dirty-.md
- **Context:** Initial task creation
