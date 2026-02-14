---
id: T-040
name: Wire fw note into audit, handover, and session-capture
description: >
  Integration touchpoints for observation inbox: audit warns on stale observations (>7d pending), handover shows pending count, session-capture checklist includes inbox triage. Prevents inbox from becoming a graveyard.
status: work-completed
workflow_type: build
owner: claude-code
priority: medium
tags: []
agents:
  primary:
  supporting: []
created: 2026-02-14T09:32:00Z
last_update: 2026-02-14T09:32:00Z
date_finished: 2026-02-14T09:34:00Z
---

# T-040: Wire fw note into audit, handover, and session-capture

## Design Record

[Architecture decisions, approach rationale — inline or link to artifact]

## Specification Record

[Requirements, acceptance criteria — inline or link to artifact]

## Test Files

[References to test scripts and test artifacts]

## Updates

### 2026-02-14T09:32:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-040-wire-fw-note-into-audit-handover-and-ses.md
- **Context:** Initial task creation

### 2026-02-14T09:34:00Z — build-completed [claude-code]
- **Action:** Wired observation inbox into 3 structural enforcement points
- **Changes:**
  - `agents/audit/audit.sh`: Added Section 7 (Observation Inbox Checks) — warns on urgent pending and stale (>7d) observations
  - `agents/handover/handover.sh`: Added inbox status to console output and generated document (lists pending observations with urgent flags)
  - `agents/session-capture/AGENT.md`: Added 2 checklist items for inbox review and in-session capture
- **Tested:** Audit correctly detects OBS-002 as urgent; handover generates observation section with item list; LATEST.md restored after test
