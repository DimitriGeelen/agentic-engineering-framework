---
id: T-627
name: "Sync stale consumer scripts — 001-sprechloop and 050-email-archive"
description: >
  Run fw upgrade on 001-sprechloop (1 stale script) and 050-email-archive (3 stale scripts) to bring them current. Part of T-625.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/upgrade.sh]
related_tasks: [T-625, T-626]
created: 2026-03-26T15:59:42Z
last_update: 2026-03-26T21:19:33Z
date_finished: 2026-03-26T16:02:55Z
---

# T-627: Sync stale consumer scripts — 001-sprechloop and 050-email-archive

## Context

Part of T-625. Two consumers have stale hook scripts: 001-sprechloop (check-tier0.sh) and 050-email-archive (check-tier0.sh, checkpoint.sh, budget-gate.sh). Run `fw upgrade` on both.

## Acceptance Criteria

### Agent
- [x] `fw upgrade /opt/001-sprechloop` completes successfully
- [x] `fw upgrade /opt/050-email-archive` completes successfully
- [x] All `agents/context/*.sh` scripts match framework source (diff check)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Verify all agents/context/*.sh scripts match in both consumers
bash -c 'for f in /opt/999-Agentic-Engineering-Framework/agents/context/*.sh; do diff "$f" "/opt/001-sprechloop/.agentic-framework/agents/context/$(basename $f)" || exit 1; done'
bash -c 'for f in /opt/999-Agentic-Engineering-Framework/agents/context/*.sh; do diff "$f" "/opt/050-email-archive/.agentic-framework/agents/context/$(basename $f)" || exit 1; done'

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

### 2026-03-26T15:59:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-627-sync-stale-consumer-scripts--001-sprechl.md
- **Context:** Initial task creation

### 2026-03-26T16:02:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
