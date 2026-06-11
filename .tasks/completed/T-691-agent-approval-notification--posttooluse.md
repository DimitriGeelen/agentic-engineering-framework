---
id: T-691
name: "Agent approval notification — PostToolUse hook detects resolved Watchtower
  approvals and tells agent to retry"
description: >
  Agent approval notification — PostToolUse hook detects resolved Watchtower approvals
  and tells agent to retry

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-008]
related_tasks: []
created: 2026-03-28T23:40:26Z
last_update: '2026-06-11T22:24:27Z'
date_finished: 2026-03-28T23:43:31Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-691: Agent approval notification — PostToolUse hook detects resolved Watchtower approvals and tells agent to retry

## Context

T-636 Phase 3 item: Gap 1 from Spike 1 flow audit. When a human approves a Tier 0 request in Watchtower, the agent has no way to know — it must speculatively retry or wait for the human to say "I approved it". Research: docs/reports/fw-agent-t636-01-flow-audit.md

## Acceptance Criteria

### Agent
- [x] checkpoint.sh post-tool checks for resolved approvals with status `approved`
- [x] Notification emitted to stderr when an unapproved-but-resolved approval is found
- [x] Already-notified approvals tracked in .context/working/.approval-notified (no repeat notifications)
- [x] Stale pending files (>2 hours) auto-cleaned from .context/approvals/
- [x] Notification includes command preview so agent knows which command to retry
- [x] check runs at reasonable interval (every N tool calls, not every call)

## Verification

grep -q 'APPROVAL READY' agents/context/checkpoint.sh
grep -q 'approval-notified' agents/context/checkpoint.sh
grep -q 'Stale pending cleanup' agents/context/checkpoint.sh

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

### 2026-03-28T23:40:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-691-agent-approval-notification--posttooluse.md
- **Context:** Initial task creation

### 2026-03-28T23:43:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6e18a308
- **Timestamp:** 2026-06-02T15:04:22Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
