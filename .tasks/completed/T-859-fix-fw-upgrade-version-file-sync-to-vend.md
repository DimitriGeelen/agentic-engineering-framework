---
id: T-859
name: "Fix fw upgrade VERSION file sync to vendored .agentic-framework/"
description: >
  Fix fw upgrade VERSION file sync to vendored .agentic-framework/

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/upgrade.sh]
related_tasks: []
created: 2026-04-04T19:29:41Z
last_update: 2026-04-04T21:57:59Z
date_finished: 2026-04-04T21:57:59Z
---

# T-859: Fix fw upgrade VERSION file sync to vendored .agentic-framework/

## Context

`fw upgrade` updates `.framework.yaml` version (step 9) but not `.agentic-framework/VERSION`. This causes `fw doctor` to report consumers as stale even after a successful upgrade. The vendored VERSION file stays at the original install version forever.

## Acceptance Criteria

### Agent
- [x] `upgrade.sh` step 4b syncs VERSION file to vendored `.agentic-framework/VERSION`
- [x] After upgrade, consumer VERSION matches framework VERSION (verified: 1.2.6 → 1.4.508)

## Verification

grep -q 'vendored_dir.*VERSION\|VERSION.*vendored' lib/upgrade.sh

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

### 2026-04-04T19:29:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-859-fix-fw-upgrade-version-file-sync-to-vend.md
- **Context:** Initial task creation

### 2026-04-04T21:57:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
