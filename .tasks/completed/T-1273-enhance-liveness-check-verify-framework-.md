---
id: T-1273
name: "Enhance liveness-check: verify framework agent TermLink session is spawned
  and listening"
description: >
  Enhance liveness-check: verify framework agent TermLink session is spawned and listening

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-16T05:21:22Z
last_update: '2026-08-16T22:24:27Z'
date_finished: 2026-04-16T05:23:32Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1273: Enhance liveness-check: verify framework agent TermLink session is spawned and listening

## Context

User request: cron job should check that the TermLink hub is running AND that a framework agent session is spawned and listening. Extends T-1269 liveness-check.sh.

## Acceptance Criteria

### Agent
- [x] liveness-check.sh detects whether a framework agent TermLink session exists (tagged `agent` or `pickup`, excludes upgrade/rec workers)
- [x] JSONL output includes `fw_agent_session` (state) and `fw_agent_id` (session ID) fields
- [x] YAML snapshot includes `framework_agent` section with session state and ID
- [x] Script runs without error when no TermLink sessions exist
- [x] Existing liveness checks (hub, claude count, watchtower) still work

## Verification

agents/monitor/liveness-check.sh
grep -q 'fw_agent_session' agents/monitor/liveness-check.sh
grep -q 'framework_agent' agents/monitor/liveness-check.sh

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

### 2026-04-16T05:21:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1273-enhance-liveness-check-verify-framework-.md
- **Context:** Initial task creation

### 2026-04-16T05:23:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4d0bde32
- **Timestamp:** 2026-06-02T14:56:22Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
