---
id: T-005
name: "Generate first session handover for __PROJECT_NAME__"
description: >
  Practice the session end protocol: generate a handover document that captures current
  state, work in progress, and suggested next actions for __PROJECT_NAME__.
status: captured
workflow_type: build
owner: agent
horizon: now
tags: [onboarding]
components: []
related_tasks: []
created: __DATE__
last_update: __DATE__
date_finished: null
---

# T-005: Generate first session handover for __PROJECT_NAME__

## Context

The handover is the primary mechanism for session continuity. Generate one now to validate the process and establish a baseline for future sessions.

## Acceptance Criteria

### Agent
- [ ] Run `fw handover --commit` to generate and commit the handover
- [ ] Handover saved to `.context/handovers/LATEST.md`
- [ ] All [TODO] sections filled in (not left as placeholders)

## Verification

# Handover exists
test -f .context/handovers/LATEST.md
# No unfilled TODOs in handover
test "$(grep -c '\[TODO' .context/handovers/LATEST.md || true)" = "0"
