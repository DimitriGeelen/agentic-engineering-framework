---
id: T-480
name: "macOS compat: replace grep -oP and ${var,,} with portable alternatives"
description: >
  macOS BSD grep lacks -P (Perl regex) and bash ${var,,} is not POSIX. 6 grep -oP in install.sh, bin/fw, bin/watchtower.sh, action.yml. 1 ${var,,} in lib/upstream.sh. From OneDev issues #2 and #3.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [portability, bugfix]
components: []
related_tasks: []
created: 2026-03-14T13:05:22Z
last_update: 2026-03-14T13:07:31Z
date_finished: 2026-03-14T13:07:31Z
---

# T-480: macOS compat: replace grep -oP and ${var,,} with portable alternatives

## Context

macOS field report (OneDev issues #2, #3). BSD grep lacks `-P` (Perl regex) and `${var,,}` is bash 4+ only. Directive D4 (portability).

## Acceptance Criteria

### Agent
- [x] No `grep -oP` in any shell script or action.yml
- [x] No `${var,,}` in any shell script
- [x] All replaced patterns produce identical output
- [x] All modified files pass syntax check

## Verification

# No grep -oP remaining
test "$(grep -rn 'grep -oP' install.sh bin/fw action.yml bin/watchtower.sh 2>/dev/null | wc -l)" = "0"
# No ${var,,} remaining
test "$(grep -rn '\${.*,,}' lib/upstream.sh 2>/dev/null | wc -l)" = "0"
# Smoke tests
bash -c 'echo "git version 2.53.1" | grep -oE "[0-9]+\.[0-9]+" | head -1' | grep -q '2.53'
bash -c 'echo "Python 3.9.6" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+"' | grep -q '3.9.6'
bash -n install.sh
bash -n bin/watchtower.sh
bash -n lib/upstream.sh

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

### 2026-03-14T13:05:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-480-macos-compat-replace-grep--op-and-var-wi.md
- **Context:** Initial task creation

### 2026-03-14T13:07:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
