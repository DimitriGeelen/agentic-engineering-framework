---
id: T-1158
name: "T-1134 build: Upstream _date_to_epoch to lib/compat.sh + fix 3 GNU-only date
  -d sites"
description: >
  T-1134 build: Upstream _date_to_epoch to lib/compat.sh + fix 3 GNU-only date -d
  sites

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-12T12:02:02Z
last_update: '2026-08-16T22:24:24Z'
date_finished: 2026-04-12T12:05:43Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:41Z'
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
  - ts: '2026-08-16T22:24:24Z'
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

# T-1158: T-1134 build: Upstream _date_to_epoch to lib/compat.sh + fix 3 GNU-only date -d sites

## Context

Build from T-1134 GO decision. Three framework files use GNU-only `date -d` which fails on macOS: `agents/context/lib/episodic.sh`, `agents/context/checkpoint.sh`, `metrics.sh`. Add `_date_to_epoch` to `lib/compat.sh` with GNU→BSD→python3 fallback chain, then replace all `date -d` sites.

## Acceptance Criteria

### Agent
- [x] `_date_to_epoch` function added to `lib/compat.sh` with GNU→BSD→python3 fallback
- [x] All `date -d` sites replaced with `_date_to_epoch` calls
- [x] `_date_relative` function added for relative date calculations
- [x] `_date_to_epoch "2026-04-12T12:00:00Z"` returns a valid epoch number

## Verification

bash -c 'source lib/compat.sh && result=$(_date_to_epoch "2026-04-12T12:00:00Z") && [ "$result" -gt 0 ]'
# agents/ should have no direct date -d (all replaced with _date_to_epoch)
bash -c '! grep -rn "date -d" agents/context/lib/episodic.sh agents/context/checkpoint.sh 2>/dev/null | grep -q .'

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

### 2026-04-12T12:02:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1158-t-1134-build-upstream-datetoepoch-to-lib.md
- **Context:** Initial task creation

### 2026-04-12T12:05:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ae1a57fe
- **Timestamp:** 2026-06-02T14:55:34Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `bash -c '! grep -rn "date -d" agents/context/lib/episodic.sh agents/context/checkpoint.sh 2>/dev/null | grep -q .'`
