---
id: T-831
name: "Session quality metrics — session-metrics.sh JSONL analyzer + handover integration"
description: >
  Session quality metrics — session-metrics.sh JSONL analyzer + handover integration

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-04T09:04:38Z
last_update: '2026-06-11T22:24:30Z'
date_finished: 2026-04-04T09:10:34Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-831: Session quality metrics — session-metrics.sh JSONL analyzer + handover integration

## Context

Build from T-830 GO. Create session-metrics.sh that analyzes JSONL transcripts to extract P0 quality metrics. Integrate into handover frontmatter. See `docs/reports/T-830-agent-b-quality-metrics.md` for full metric design.

## Acceptance Criteria

### Agent
- [x] `agents/context/session-metrics.sh` exists and runs without errors
- [x] Extracts P0 metrics from JSONL: commits_per_turn, first_commit_turn, failed_tool_calls, failed_tool_call_rate, edit_bursts
- [x] Outputs YAML to `.context/working/.session-metrics.yaml`
- [x] handover.sh reads session-metrics.yaml and injects fields into frontmatter
- [x] Timeline displays session quality metrics when available
- [x] Session metrics appear in handover frontmatter after next session (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

bash agents/context/session-metrics.sh 2>&1 | grep -q "metrics"
test -f .context/working/.session-metrics.yaml
grep -q "session_" agents/handover/handover.sh

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

### 2026-04-04T09:04:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-831-session-quality-metrics--session-metrics.md
- **Context:** Initial task creation

### 2026-04-04T09:10:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c05cb07d
- **Timestamp:** 2026-06-02T15:05:07Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `bash agents/context/session-metrics.sh 2>&1 | grep -q "metrics"`
