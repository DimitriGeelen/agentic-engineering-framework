---
id: T-805
name: "Handover token summary — include session token usage in handover documents"
description: >
  Add current session token usage summary to the handover document. When fw handover
  runs, include: total tokens consumed, turns, cache hit rate, and avg tokens/turn.
  Uses fw costs current data. Enables tracking token consumption per-session in the
  handover trail.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [tokens, handover, observability]
components: [agents/handover/handover.sh]
related_tasks: []
created: 2026-04-03T19:23:46Z
last_update: '2026-08-16T22:25:40Z'
date_finished: 2026-04-12T07:55:16Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); 
      F3=0 (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-805: Handover token summary — include session token usage in handover documents

## Context

Follow-up from T-801. Handover documents track session state — adding token usage makes token consumption visible across sessions. Uses `fw costs current` parsing.

## Acceptance Criteria

### Agent
- [x] `handover.sh` includes a "Token Usage" section in the generated handover
- [x] Section shows: total tokens, turns, cache hit rate
- [x] Graceful degradation: if no JSONL transcript found, section is omitted
- [x] Handover YAML frontmatter includes `token_usage` field
- [x] Verify handover includes token data (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

grep -q "token_usage\|Token Usage" agents/handover/handover.sh
grep -q "token" agents/handover/handover.sh

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

### 2026-04-03T19:23:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-805-handover-token-summary--include-session-.md
- **Context:** Initial task creation

### 2026-04-12T07:55:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c432ad68
- **Timestamp:** 2026-06-02T15:04:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
