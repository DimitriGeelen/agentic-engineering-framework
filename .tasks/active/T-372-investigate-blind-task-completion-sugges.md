---
id: T-372
name: "Investigate blind task-completion suggestion pattern + mitigate"
description: >
  Investigate blind task-completion suggestion pattern + mitigate

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [governance, meta]
components: []
related_tasks: []
created: 2026-03-09T05:59:39Z
last_update: 2026-03-09T05:59:39Z
date_finished: null
---

# T-372: Investigate blind task-completion suggestion pattern + mitigate

## Context

Agent suggested batch-closing 12 human-owned tasks with `--force` without reviewing Human ACs. Sovereignty gate (R-033) blocked execution but not the suggestion. Root cause: asymmetric gates — execution gated, proposal ungated. See `docs/reports/T-372-blind-completion-investigation.md`.

## Acceptance Criteria

### Agent
- [x] Root cause analysis documented (research artifact)
- [x] CLAUDE.md blind-completion anti-pattern rule added (A1+A2)
- [x] Handover surfaces unchecked Human ACs (B1)
- [x] C1 query tool verified working (`fw task verify`)
- [x] Gap G-017 registered
- [x] Learning L-084 captured

## Verification

test -f docs/reports/T-372-blind-completion-investigation.md
grep -q "Blind Completion Anti-Pattern" CLAUDE.md
grep -q "Partial-Complete\|Human Review Pending" agents/handover/handover.sh
grep -q "G-017" .context/project/gaps.yaml

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

### 2026-03-09T05:59:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-372-investigate-blind-task-completion-sugges.md
- **Context:** Initial task creation
