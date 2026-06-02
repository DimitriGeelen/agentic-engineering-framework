---
id: T-708
name: "ntfy: lib/notify.sh — thin wrapper calling skills-manager alert dispatcher"
description: >
  Build lib/notify.sh that wraps skills-manager dispatch_alert. Fire-and-forget, NTFY_ENABLED opt-in, backgrounded. Related: T-707 GO.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [ntfy, notifications]
components: [lib/notify.sh]
related_tasks: []
created: 2026-03-29T11:14:11Z
last_update: 2026-05-02T05:06:44Z
date_finished: 2026-03-29T11:16:12Z
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
- [x] [RUBBER-STAMP] Receive test notification on phone
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

## Recommendation

**Recommendation:** GO

**Rationale:** All 6 Agent ACs verified — `lib/notify.sh` exists, default-disabled, fire-and-forget background, calls dispatcher, graceful degradation, sourced via standard pattern. The `[RUBBER-STAMP]` Human AC is "receive on phone" — needs the phone to validate, can't be agent-tested.

**Evidence:**
- `lib/notify.sh` defines `fw_notify()`
- Default-off via `${NTFY_ENABLED:-false}` guard
- Background dispatch via `( ... ) &` pattern
- Calls skills-manager alert dispatcher CLI
- `2>/dev/null` swallows transport errors (graceful degrade)
- Sourced by `lib/healing.sh` and other scripts via `source "$FRAMEWORK_ROOT/lib/notify.sh"`

## Updates

### 2026-03-29T11:14:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-708-libnotifysh--thin-wrapper-calling-skills.md
- **Context:** Initial task creation

### 2026-03-29T11:14:31Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-29T11:16:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:21Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-04-30T20:47:07Z — status-update [task-update-agent]
- **Change:** horizon: next → next
- **Change:** tags: +arc:ntfy

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ab790195
- **Timestamp:** 2026-06-02T15:04:28Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#6 (Agent)** — Sourced by framework scripts via `source "$FRAMEWORK_ROOT/lib/notify.sh"`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=FRAMEWORK_ROOT/lib/notify.sh in: Sourced by framework scripts via `source "$FRAMEWORK_ROOT/lib/notify.sh"``
