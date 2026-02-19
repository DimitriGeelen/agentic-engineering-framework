---
id: T-198
name: "R-033 remediation — human sovereignty structural control"
description: >
  Design and implement structural control for R-033 (human tasks auto-completed by agent, score 12 HIGH). Currently ZERO controls. Recommendation from Phase 2c: owner: humanhuman + workflow_type: buildspec|inception → require human interaction before status change. This is the highest-scoring open risk with no control.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [assurance, risk-remediation, t-194-go]
related_tasks: []
created: 2026-02-19T19:29:23Z
last_update: 2026-02-19T22:33:52Z
date_finished: 2026-02-19T22:33:52Z
---

# T-198: R-033 remediation — human sovereignty structural control

## Context

R-033 (score 12, HIGH): agent auto-completes human-owned tasks without human interaction. Design decision: Option D (sticky owner) + Option A (completion gate), both in update-task.sh.

## Acceptance Criteria

### Agent
- [x] Completion gate: `--status work-completed` blocked when `owner: human` (exit 1)
- [x] Owner protection: `--owner <non-human>` blocked when current `owner: human` (exit 1)
- [x] Both gates bypassed with `--force` (with warning)
- [x] Partial-complete re-run path (same status, line 126) unaffected by sovereignty gate
- [x] CTL-026 registered in controls.yaml
- [x] R-033 updated: controls [CTL-025, CTL-026], status implemented
- [x] OE test for CTL-026 in audit.sh

## Verification

# Sovereignty gate blocks completion of human-owned tasks (T-198 itself is agent-owned, so test with a probe)
grep -q "sovereignty gate" agents/task-create/update-task.sh
# Owner protection present
grep -q "human ownership is protected" agents/task-create/update-task.sh
# CTL-026 registered
grep -q "CTL-026" .context/project/controls.yaml
# OE test present
grep -q "CTL-026 OE" agents/audit/audit.sh

## Decisions

### 2026-02-19 — Gate design
- **Chose:** Option D (sticky owner) + Option A (completion gate)
- **Why:** D prevents circumvention (agent can't just change owner first), A blocks the completion. Together they form a two-layer defense.
- **Rejected:** Option B (workflow-type gate — too blunt, blocks legitimate inception completion); Option C (interaction tracking — too complex for bash, hard to audit)

## Updates

### 2026-02-19T19:29:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-198-r-033-remediation--human-sovereignty-str.md
- **Context:** Initial task creation

### 2026-02-19T21:04:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-19T21:04:37Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-02-19T22:31:20Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-19T22:33:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
