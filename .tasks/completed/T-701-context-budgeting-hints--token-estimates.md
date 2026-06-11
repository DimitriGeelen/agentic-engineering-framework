---
id: T-701
name: "Context budgeting hints — token estimates and load priority in component cards"
description: >
  Add token_estimate, load_strategy, priority fields to fabric component cards. Enhances
  P-009 budget management with structured per-unit cost data. Score: 17/20 (D1:4 D2:4
  D3:4 D4:5). Source: T-697 pattern harvest #15.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [context-budget, kcp-pattern]
components: []
related_tasks: []
created: 2026-03-29T08:57:27Z
last_update: '2026-06-11T22:24:27Z'
date_finished: 2026-03-29T14:16:01Z
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
---

# T-701: Context budgeting hints — token estimates and load priority in component cards

## Context

KCP pattern harvest (T-697 #15) proposed adding `token_estimate`, `load_strategy`, `priority` to 180 fabric component cards. Would enhance P-009 budget management with per-file context cost data. Research artifact: `docs/reports/T-701-context-budgeting-hints.md`.

## Acceptance Criteria

### Agent
- [x] Problem evaluated against current budget management
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review findings and approve decision
  **Steps:**
  1. Read recommendation below
  2. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-701 defer --rationale "your rationale"`
  **Expected:** Decision recorded
  **If not:** Ask for clarification

## Verification

# Task file has recommendation
grep -q "Recommendation" .tasks/active/T-701-context-budgeting-hints--token-estimates.md 2>/dev/null || grep -q "Recommendation" .tasks/completed/T-701-context-budgeting-hints--token-estimates.md 2>/dev/null

## Decisions

**Decision**: DEFER

**Rationale**: - Recommendation: DEFER
- Rationale: Token budgeting hints are a KCP-inspired pattern that solves a problem the framework doesn't have. P-009 budget management reads actual token usage from the Cla...

**Date**: 2026-03-29T13:33:11Z

## Recommendation

- **Recommendation:** DEFER
- **Rationale:** Token budgeting hints are a KCP-inspired pattern that solves a problem the framework doesn't have. P-009 budget management reads **actual** token usage from the Claude Code JSONL transcript — it doesn't need estimates. The agent doesn't read fabric cards to decide what to load; it reads CLAUDE.md (auto-loaded), handovers, and task files. Adding `token_estimate` to 180 component cards would be metadata with zero consumers. If the framework later adopts KCP (T-705, deferred) or builds a context-aware loader that selectively loads files based on budget, revisit then.
- **Evidence:**
  - 180 fabric component cards would need updating
  - budget-gate.sh reads JSONL transcript (actual usage), not fabric cards
  - checkpoint.sh reads JSONL transcript, not fabric cards
  - Agent reads CLAUDE.md, LATEST.md, focus.yaml at session start — not driven by fabric cards
  - No code path exists that would consume token_estimate or load_priority from cards
- **Next steps after DEFER:** Revisit if a context-aware selective loader is built, or if KCP integration (T-705) is approved

## Updates

### 2026-03-29T08:57:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-701-context-budgeting-hints--token-estimates.md
- **Context:** Initial task creation

### 2026-03-29T13:21:47Z — status-update [task-update-agent]
- **Change:** workflow_type: build → inception

### 2026-03-29T13:21:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-29T13:33:11Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** - Recommendation: DEFER
- Rationale: Token budgeting hints are a KCP-inspired pattern that solves a problem the framework doesn't have. P-009 budget management reads actual token usage from the Cla...

### 2026-03-29T14:16:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-749b6e00
- **Timestamp:** 2026-06-02T15:04:26Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `grep -q "Recommendation" .tasks/active/T-701-context-budgeting-hints--token-estimates.md 2>/dev/null || grep -q "Recommendation" .tasks/completed/T-701-context-budgeting-hints--token-estimates.md 2>/d`
