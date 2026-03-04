---
id: T-310
name: "Auto-run fw doctor at end of fw init"
description: >
  Terraform pattern: init validates automatically. Currently fw init says 'run fw doctor' but doesn't run it. Fold doctor into init as final step, show results inline. Source: T-294 DX comparison finding.

status: started-work
workflow_type: build
owner: agent
horizon: later
tags: []
components: []
related_tasks: [T-294]
created: 2026-03-04T17:28:41Z
last_update: 2026-03-04T21:48:36Z
date_finished: null
---

# T-310: Auto-run fw doctor at end of fw init

## Context

Terraform pattern: init validates automatically. From T-294 DX findings.

## Acceptance Criteria

### Agent
- [x] `fw init` runs `do_doctor` after creating all artifacts
- [x] Doctor output appears inline before the "Project Initialized" summary
- [x] PROJECT_ROOT is temporarily set to target dir for doctor, then restored
- [x] Removed "fw doctor" from "Next steps" list (it already ran)
- [x] `fw test-onboarding` still passes 27/27

## Verification

# fw init runs doctor inline
grep -q "do_doctor" lib/init.sh
# Onboarding test still passes
fw test-onboarding 2>&1 | grep -q "ONBOARDING CLEAN"

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

### 2026-03-04T17:28:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-310-auto-run-fw-doctor-at-end-of-fw-init.md
- **Context:** Initial task creation

### 2026-03-04T21:48:36Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
