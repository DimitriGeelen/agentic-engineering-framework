---
id: T-198
name: "R-033 remediation — human sovereignty structural control"
description: >
  Design and implement structural control for R-033 (human tasks auto-completed by
  agent, score 12 HIGH). Currently ZERO controls. Recommendation from Phase 2c: owner:
  humanhuman + workflow_type: buildspec|inception → require human interaction before
  status change. This is the highest-scoring open risk with no control.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [assurance, risk-remediation, t-194-go]
related_tasks: []
created: 2026-02-19T19:29:23Z
last_update: '2026-06-11T22:24:05Z'
date_finished: 2026-02-19T22:33:52Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c385b8fd
- **Timestamp:** 2026-06-02T15:00:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
