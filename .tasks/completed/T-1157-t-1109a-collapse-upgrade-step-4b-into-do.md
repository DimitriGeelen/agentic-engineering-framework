---
id: T-1157
name: "T-1109a: Collapse upgrade step 4b into do_vendor call — single vendor chokepoint"
description: >
  T-1109a: Collapse upgrade step 4b into do_vendor call — single vendor chokepoint

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/upgrade.sh]
related_tasks: []
created: 2026-04-12T11:57:29Z
last_update: 2026-04-12T12:01:15Z
date_finished: 2026-04-12T12:01:15Z
---

# T-1157: T-1109a: Collapse upgrade step 4b into do_vendor call — single vendor chokepoint

## Context

Build from T-1109 GO decision. `lib/upgrade.sh:do_upgrade()` step 4b (lines 320-446) maintains a handcrafted 120-line per-file sync that diverged from `bin/fw:do_vendor()`'s includes list. `do_vendor` includes `web/`, step 4b does not. Fix: replace step 4b body with a `do_vendor` call. See `docs/reports/T-1109-web-sync-rca.md`.

## Acceptance Criteria

### Agent
- [x] Step 4b body replaced with `do_vendor --target --source` call
- [x] `do_upgrade()` no longer has its own file enumeration (no `agent_dirs`, no per-file cp loops)
- [x] VERSION file still synced after upgrade (do_vendor handles this)

## Verification

# Step 4b no longer has per-file sync loops
bash -c '! grep -q "agent_dirs=" lib/upgrade.sh'
# do_vendor is called from do_upgrade
bash -c 'grep -q "do_vendor" lib/upgrade.sh'

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

### 2026-04-12T11:57:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1157-t-1109a-collapse-upgrade-step-4b-into-do.md
- **Context:** Initial task creation

### 2026-04-12T12:01:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2ca19dc0
- **Timestamp:** 2026-06-02T14:55:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
