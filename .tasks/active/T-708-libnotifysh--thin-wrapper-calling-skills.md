---
id: T-708
name: "lib/notify.sh — thin wrapper calling skills-manager alert dispatcher"
description: >
  Build lib/notify.sh that wraps skills-manager dispatch_alert. Fire-and-forget, NTFY_ENABLED opt-in, backgrounded. Related: T-707 GO.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [ntfy, notifications]
components: []
related_tasks: []
created: 2026-03-29T11:14:11Z
last_update: 2026-03-29T11:14:31Z
date_finished: null
---

# T-708: lib/notify.sh — thin wrapper calling skills-manager alert dispatcher

## Context

T-707 GO: ntfy integration via skills-manager MCP. Design: `docs/reports/T-707-ntfy-deep-dive.md`

## Acceptance Criteria

### Agent
- [x] `lib/notify.sh` created with `fw_notify()` function
- [x] Disabled by default — only sends when `NTFY_ENABLED=true`
- [x] Fire-and-forget — runs in background, never blocks calling script
- [x] Calls skills-manager alert dispatcher CLI
- [x] Graceful degradation — no error if skills-manager unreachable
- [x] Sourced by framework scripts via `source "$FRAMEWORK_ROOT/lib/notify.sh"`

### Human
- [ ] [RUBBER-STAMP] Receive test notification on phone
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && NTFY_ENABLED=true source lib/notify.sh && fw_notify "Test" "Framework notification test" "manual" "framework"`
  2. Check ntfy app for notification
  **Expected:** Push notification appears with title "Test"
  **If not:** Check if skills-manager alert dispatcher is running: `python3 /opt/150-skills-manager/skills/alerts/alert_dispatcher.py status`

## Verification

bash -n lib/notify.sh
grep -q "fw_notify" lib/notify.sh
grep -q "NTFY_ENABLED" lib/notify.sh

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

### 2026-03-29T11:14:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-708-libnotifysh--thin-wrapper-calling-skills.md
- **Context:** Initial task creation

### 2026-03-29T11:14:31Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
