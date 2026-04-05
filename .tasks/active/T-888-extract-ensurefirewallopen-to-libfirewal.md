---
id: T-888
name: "Extract ensure_firewall_open to lib/firewall.sh for reuse"
description: >
  Extract ensure_firewall_open to lib/firewall.sh for reuse

status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-05T12:34:31Z
last_update: 2026-04-05T12:34:31Z
date_finished: null
---

# T-888: Extract ensure_firewall_open to lib/firewall.sh for reuse

## Context

`ensure_firewall_open` lives in `bin/watchtower.sh` but will be needed by the service registry (T-885). Extract to `lib/firewall.sh` as a shared utility.

## Acceptance Criteria

### Agent
- [x] `lib/firewall.sh` exists with `ensure_firewall_open` function
- [x] `bin/watchtower.sh` sources `lib/firewall.sh` instead of inlining the function
- [x] Watchtower still starts correctly with firewall check working

## Verification

# lib/firewall.sh exists and is sourceable
bash -c 'source lib/firewall.sh && type ensure_firewall_open'
# watchtower.sh sources it
grep -q 'lib/firewall.sh' bin/watchtower.sh

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

### 2026-04-05T12:34:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-888-extract-ensurefirewallopen-to-libfirewal.md
- **Context:** Initial task creation
