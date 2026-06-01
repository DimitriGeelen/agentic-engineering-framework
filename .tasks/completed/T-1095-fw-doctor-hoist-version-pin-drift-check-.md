---
id: T-1095
name: "fw doctor: hoist version-pin drift check from lib/upgrade.sh as a read-only doctor check (G-026)"
description: >
  Add a fw doctor check that runs the same version-pin detection as fw upgrade (e.g. 'Pinned: vdev (behind v2.46.alpha)') without applying changes. Surfaces stale pins between upgrade runs. Origin: G-026. Trigger: cross-session ring20-dashboard onboarding incident 2026-04-11.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: [T-1093]
created: 2026-04-11T12:15:36Z
last_update: 2026-04-12T07:20:54Z
date_finished: 2026-04-12T07:20:54Z
---

# T-1095: fw doctor: hoist version-pin drift check from lib/upgrade.sh as a read-only doctor check (G-026)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `fw doctor` shows version-pin drift for consumer projects
      (already implemented in doctor Consumer Projects fleet scan,
      bin/fw lines 1109-1189: shows `WARN name (vX → vY)`)
- [x] `fw doctor` shows version-pin drift for current project when
      running as consumer (bin/fw lines 569-578)

## Verification

bash -c 'bin/fw doctor 2>&1 | grep -qE "Consumer Projects|All.*consumer"'

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

### 2026-04-11T12:15:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1095-fw-doctor-hoist-version-pin-drift-check-.md
- **Context:** Initial task creation

### 2026-04-12T07:19:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T07:20:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
