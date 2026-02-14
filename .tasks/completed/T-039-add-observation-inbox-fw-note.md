---
id: T-039
name: Add observation inbox (fw note)
description: >
  Lightweight capture for bugs, improvements, requirements, and design debt noticed during work. Fills the gap between too-heavy task creation and losing observations.
status: work-completed
workflow_type: build
owner: claude-code
priority: high
tags: [observation, inbox, capture, usability]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-14T09:20:55Z
last_update: 2026-02-14T09:20:55Z
date_finished: 2026-02-14T09:20:55Z
---

# T-039: Add observation inbox (fw note)

## Design Record

**Problem:** Framework had no lightweight capture for in-the-moment observations. Tasks too heavy (4 required fields), learnings wrong semantics (backward-looking), session capture too late (end of session).

**Solution:** `fw note "text"` — one required argument, auto-detected context, persistent YAML inbox.

**Key patterns borrowed:** GTD (zero-classification inbox), Zettelkasten (fleeting → permanent), IDE TODO (in-situ speed), bug bounty (structural triage SLA).

**Core insight:** Separate the moment of observation from the moment of classification.

## Updates

### 2026-02-14T09:20:55Z — build-completed [claude-code]
- **Action:** Built agents/observe/observe.sh and wired into fw CLI
- **Commands:** note (capture), list, count, triage, promote, dismiss
- **Validated:** 5-agent review unanimously recommended this approach
- **Deferred:** Audit/handover/session-capture integration (next session)
