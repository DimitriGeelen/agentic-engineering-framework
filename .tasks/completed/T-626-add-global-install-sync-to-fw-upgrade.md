---
id: T-626
name: "Add global install sync to fw upgrade"
description: >
  Add step to lib/upgrade.sh that syncs hook scripts to $HOME/.agentic-framework/ when upgrading from the framework repo. Part of T-625.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/upgrade.sh]
related_tasks: [T-625]
created: 2026-03-26T15:59:21Z
last_update: 2026-03-26T21:19:23Z
date_finished: 2026-03-26T21:19:23Z
---

# T-626: Add global install sync to fw upgrade

## Context

Part of T-625 inception. Add a step to `lib/upgrade.sh` that syncs hook scripts to `$HOME/.agentic-framework/` when upgrading from the framework repo. See `docs/reports/T-625-global-framework-sync.md`.

## Acceptance Criteria

### Agent
- [x] `lib/upgrade.sh` has a new step that syncs `agents/context/*.sh` and `agents/context/lib/*` to `$HOME/.agentic-framework/`
- [x] Sync only runs when `$HOME/.agentic-framework/` exists (skip if no global install)
- [x] Sync only runs when not in dry-run mode
- [x] `bash -n lib/upgrade.sh` passes (no syntax errors)

## Verification

bash -n lib/upgrade.sh
grep -q "HOME.*agentic-framework" lib/upgrade.sh

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

### 2026-03-26T15:59:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-626-add-global-install-sync-to-fw-upgrade.md
- **Context:** Initial task creation

### 2026-03-26T21:19:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ec2672bf
- **Timestamp:** 2026-06-02T15:03:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
