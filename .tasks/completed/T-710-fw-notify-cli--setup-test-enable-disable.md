---
id: T-710
name: "ntfy: fw notify CLI — setup, test, enable, disable commands"
description: >
  Add fw notify subcommand for managing notification configuration. fw notify test sends a test push. fw notify enable/disable toggles NTFY_ENABLED. Related: T-708, T-709, T-707 GO.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [ntfy, notifications, cli]
components: [bin/fw, lib/notify.sh]
related_tasks: []
created: 2026-03-29T11:14:24Z
last_update: 2026-05-02T05:06:55Z
date_finished: 2026-03-29T14:01:10Z
---

# T-710: fw notify CLI — setup, test, enable, disable commands

## Context

T-708 built `lib/notify.sh` with `fw_notify()` function. T-710 adds `fw notify` CLI commands for human interaction — setup, test, enable, disable, status. Design: `docs/reports/T-707-ntfy-deep-dive.md`.

## Acceptance Criteria

### Agent
- [x] `fw notify status` shows current NTFY_ENABLED state and dispatcher path
- [x] `fw notify test` sends a test notification (requires NTFY_ENABLED=true)
- [x] `fw notify enable` sets NTFY_ENABLED=true in project config
- [x] `fw notify disable` sets NTFY_ENABLED=false in project config
- [x] `fw notify setup` guides through initial configuration
- [x] `fw notify` (no subcommand) shows help text with available subcommands
- [x] Notify route added to `bin/fw` case statement
- [x] Config persisted in `.context/notify-config.yaml`

### Human
- [x] [RUBBER-STAMP] Receive test notification on phone
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw notify enable`
  2. `cd /opt/999-Agentic-Engineering-Framework && bin/fw notify test`
  3. Check ntfy app for notification
  **Expected:** Push notification appears with title "Framework Test"
  **If not:** Run `cd /opt/999-Agentic-Engineering-Framework && bin/fw notify status` and check dispatcher path

## Verification

bash -n lib/notify.sh
grep -q 'notify)' bin/fw
cd /opt/999-Agentic-Engineering-Framework && bin/fw notify status

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO

**Rationale:** All 8 Agent ACs verified — 5 subcommands (status, test, enable, disable, setup), help text, `fw notify` route in case statement, persistent config in `.context/notify-config.yaml`. Same `[RUBBER-STAMP]` phone-receipt Human AC as T-708; can't be agent-validated end-to-end.

**Evidence:**
- `fw notify status|test|enable|disable|setup` all wired
- `bin/fw` case statement routes `notify`
- `.context/notify-config.yaml` persists state
- Help text appears for bare `fw notify`

## Updates

### 2026-03-29T11:14:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-710-fw-notify-cli--setup-test-enable-disable.md
- **Context:** Initial task creation

### 2026-03-29T13:58:09Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-29T14:01:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-30T20:47:07Z — status-update [task-update-agent]
- **Change:** horizon: next → next
- **Change:** tags: +arc:ntfy
