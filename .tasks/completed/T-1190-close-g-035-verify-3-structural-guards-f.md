---
id: T-1190
name: "Close G-035: verify 3 structural guards for doc/help/code parity are in place"
description: >
  Close G-035: verify 3 structural guards for doc/help/code parity are in place

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-12T21:51:34Z
last_update: '2026-08-16T22:24:25Z'
date_finished: 2026-04-12T21:52:44Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1190: Close G-035: verify 3 structural guards for doc/help/code parity are in place

## Context

G-035 (HIGH META-GAP): CLAUDE.md/fw help/code parity had no structural enforcement. Three structural guards now exist: (1) `fw doctor` Quick Reference check (T-1147); (2) `tests/lint/help-router-parity.bats` (T-1185); (3) `tests/lint/config-registry-parity.bats` (T-1187). Inception: T-1104.

## Acceptance Criteria

### Agent
- [x] `fw doctor` Quick Reference coverage check runs and passes
- [x] `tests/lint/help-router-parity.bats` exists and passes (2 tests)
- [x] `tests/lint/config-registry-parity.bats` exists and passes (3 tests)
- [x] G-035 marked resolved in concerns.yaml

## Verification

bats tests/lint/help-router-parity.bats
bats tests/lint/config-registry-parity.bats
bash -c 'bin/fw doctor 2>&1 | grep -q "Quick Reference"'

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

### 2026-04-12T21:51:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1190-close-g-035-verify-3-structural-guards-f.md
- **Context:** Initial task creation

### 2026-04-12T21:52:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-749488f4
- **Timestamp:** 2026-06-02T14:55:48Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `bash -c 'bin/fw doctor 2>&1 | grep -q "Quick Reference"'`
