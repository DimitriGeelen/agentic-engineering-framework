---
id: T-1159
name: "T-1136 build: Show open concerns at session init — cross-session failure awareness"
description: >
  T-1136 build: Show open concerns at session init — cross-session failure awareness

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/context/lib/init.sh]
related_tasks: []
created: 2026-04-12T12:06:20Z
last_update: '2026-08-16T22:24:24Z'
date_finished: 2026-04-12T12:08:11Z
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
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
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
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1159: T-1136 build: Show open concerns at session init — cross-session failure awareness

## Context

Build from T-1136 GO. Open concerns are invisible at session start — agents must explicitly run `fw gaps`. Adding concerns summary to init output prevents cross-session failure blindness.

## Acceptance Criteria

### Agent
- [x] `agents/context/lib/init.sh` shows open concerns count at session init
- [x] Silent when no open concerns (backward compatible)
- [x] `fw context init` output includes "Concerns register" when concerns exist

## Verification

bash -c 'grep -q "concerns" agents/context/lib/init.sh'
bash -c 'bin/fw context init 2>&1 | grep -qi "concern"'

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

### 2026-04-12T12:06:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1159-t-1136-build-show-open-concerns-at-sessi.md
- **Context:** Initial task creation

### 2026-04-12T12:08:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0a5b0ac8
- **Timestamp:** 2026-06-02T14:55:34Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bash -c 'bin/fw context init 2>&1 | grep -qi "concern"'`
