---
id: T-005
name: "Generate first session handover for __PROJECT_NAME__"
description: >
  Practice the session end protocol: generate a handover document that captures state,
  work in progress, and next actions.
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

The handover is the primary mechanism for session continuity. Generate one to validate the process and establish a baseline.

## Acceptance Criteria

### Agent
- [ ] Run `fw handover --commit` to generate and commit the handover
- [ ] Handover saved to `.context/handovers/LATEST.md`
- [ ] All [TODO] sections filled in

## Verification

# Handover exists
test -f .context/handovers/LATEST.md
