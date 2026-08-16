---
id: T-686
name: "Article angle 3 — landscape differentiation research"
description: >
  Article angle 3 — landscape differentiation research

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-28T22:19:38Z
last_update: '2026-08-16T22:25:37Z'
date_finished: 2026-03-29T13:34:18Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:37Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-686: Article angle 3 — landscape differentiation research

## Context

Research the AI coding agent governance landscape to position the framework for launch. Understand who the neighbors are (agent runtimes, agent frameworks, dev guardrails, AI safety tools) and where this framework sits relative to them. Research artifact: `docs/reports/T-686-landscape-differentiation.md`.

## Acceptance Criteria

### Agent
- [x] Research artifact created with landscape categories (A-D)
- [x] 20+ tools catalogued across categories
- [x] Competitive positioning matrix (structural vs prompt-based)
- [x] Evidence-backed vs speculative claims separated
- [x] GO/NO-GO recommendation with rationale

### Human
- [x] [REVIEW] Positioning angles resonate — pick preferred angle for launch content
  **Steps:**
  1. Read `docs/reports/T-686-landscape-differentiation.md` sections "Positioning Angles" and "Key Differentiation Claims"
  2. Consider which angle best matches your voice and audience
  **Expected:** One angle selected (or hybrid), notes on claims to emphasize/avoid
  **If not:** Add notes on what's missing or wrong in the analysis

## Verification

# Research artifact exists
test -f docs/reports/T-686-landscape-differentiation.md
# Contains landscape categories
grep -q "Landscape Categories" docs/reports/T-686-landscape-differentiation.md
# Contains positioning matrix
grep -q "Competitive Positioning Matrix" docs/reports/T-686-landscape-differentiation.md

## Decisions

**Decision**: GO

**Rationale**: - Recommendation: GO
- Rationale: Landscape research reveals a genuinely unoccupied niche — no existing tool does structural enforcement of task-first governance on AI coding agents. The space betw...

**Date**: 2026-03-29T13:34:18Z

## Recommendation

- **Recommendation:** GO
- **Rationale:** Landscape research reveals a genuinely unoccupied niche — no existing tool does structural enforcement of task-first governance on AI coding agents. The space between "prompt-based CLAUDE.md rules" and "full agent runtime" is empty. 20+ tools catalogued across 4 categories, zero direct competitors found. Research artifact includes competitive positioning matrix and 4 positioning angles for launch content.
- **Evidence:**
  - Research artifact: `docs/reports/T-686-landscape-differentiation.md` (landscape categories A-D, 20+ tools)
  - Competitive positioning matrix shows structural enforcement vs prompt-based gap
  - 5 evidence-backed claims identified, 2 partial claims flagged, 3 "do not claim" guardrails set
  - Key finding: only tool doing hook-enforced task gates on AI coding agents
- **Next steps after GO:** Human selects positioning angle, then build task for launch content incorporating landscape differentiation.

## Updates

### 2026-03-28T22:19:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-686-article-angle-3--landscape-differentiati.md
- **Context:** Initial task creation

### 2026-03-28T22:20:58Z — status-update [task-update-agent]
- **Change:** workflow_type: build → inception

### 2026-03-29T13:34:18Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** - Recommendation: GO
- Rationale: Landscape research reveals a genuinely unoccupied niche — no existing tool does structural enforcement of task-first governance on AI coding agents. The space betw...

### 2026-03-29T13:34:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-06T22:29:21Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f7f9d530
- **Timestamp:** 2026-06-02T15:04:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
