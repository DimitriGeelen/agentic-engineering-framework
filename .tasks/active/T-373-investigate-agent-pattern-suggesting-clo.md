---
id: T-373
name: "Investigate agent pattern: suggesting closure of untested Human ACs"
description: >
  Investigate agent pattern: suggesting closure of untested Human ACs

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [governance, meta]
components: []
related_tasks: []
created: 2026-03-09T06:12:21Z
last_update: 2026-03-09T06:12:21Z
date_finished: null
---

# T-373: Investigate agent pattern: suggesting closure of untested Human ACs

## Context

Agent repeatedly suggested batch-closing human-owned tasks without evidence that Human ACs were satisfied. Root cause: D2 audit escalated normal human-review state to FAIL at 72h, handover framed them as problems, no rule distinguished "suggest with evidence" from "suggest without." See `docs/reports/T-372-blind-completion-investigation.md`.

## Acceptance Criteria

### Agent
- [x] Root cause identified (D2 perverse incentive + handover framing + completion bias)
- [x] D2 audit thresholds redesigned (WARN >14d, FAIL >30d, not 48h/72h)
- [x] CLAUDE.md rule: evidence-based completion suggestions only
- [x] Handover reframed: "Awaiting Your Action" not "pending problem"
- [x] Resume separates human-owned from agent-actionable tasks
- [x] Learning captured

## Verification

grep -q "awaiting human action" agents/audit/audit.sh
grep -q "You MAY suggest closing" CLAUDE.md
grep -q "Awaiting Your Action" agents/handover/handover.sh
grep -q "awaiting human review" agents/resume/resume.sh

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

### 2026-03-09T06:12:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-373-investigate-agent-pattern-suggesting-clo.md
- **Context:** Initial task creation
