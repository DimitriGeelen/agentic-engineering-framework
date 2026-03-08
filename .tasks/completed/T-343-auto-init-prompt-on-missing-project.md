---
id: T-343
name: "Auto-init prompt on missing project"
description: >
  Auto-init prompt on missing project

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-03-08T10:12:12Z
last_update: 2026-03-08T19:37:26Z
date_finished: 2026-03-08T10:14:47Z
---

# T-343: Auto-init prompt on missing project

## Context

When a user installs fw via Homebrew and runs any command in a non-initialized directory, nothing happens. The CLI should detect this and prompt to run `fw init` automatically.

## Acceptance Criteria

### Agent
- [x] `bin/fw` prompts Y/n when no project detected and command is not init/help/version
- [x] Y (or Enter) runs `fw init` then re-executes the original command via `exec`
- [x] n prints skip message and exits cleanly
- [x] `fw init`, `fw help`, `fw version` are excluded from the prompt

### Human
- [x] [RUBBER-STAMP] Interactive prompt works correctly in a real terminal
  **Steps:**
  1. `mkdir /tmp/test-fw-init && cd /tmp/test-fw-init`
  2. Run `fw doctor` — should prompt Y/n
  3. Press Enter (default Y) — should init then re-run doctor
  4. `rm -rf /tmp/test-fw-init && mkdir /tmp/test-fw-init && cd /tmp/test-fw-init`
  5. Run `fw help` — should NOT prompt
  6. Run `fw version` — should NOT prompt
  **Expected:** Prompt appears only for non-excluded commands, init works, re-exec succeeds
  **If not:** Note which command triggered unexpected behavior

## Verification

grep -q "Auto-init prompt" bin/fw
grep -q "Would you like to initialize" bin/fw
grep -q 'exec "$0" "$@"' bin/fw

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

### 2026-03-08T10:12:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-343-auto-init-prompt-on-missing-project.md
- **Context:** Initial task creation

### 2026-03-08T10:14:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
