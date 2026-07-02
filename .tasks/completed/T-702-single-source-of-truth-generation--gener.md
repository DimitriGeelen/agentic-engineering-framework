---
id: T-702
name: "Single-source-of-truth generation — generate CLAUDE.md and hooks from structured
  manifest"
description: >
  Inception: Single-source-of-truth generation — generate CLAUDE.md and hooks from
  structured manifest

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-03-29T08:57:35Z
last_update: '2026-06-11T22:24:27Z'
date_finished: 2026-03-29T13:32:56Z
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

# T-702: Single-source-of-truth generation — generate CLAUDE.md and hooks from structured manifest

## Problem Statement

Three coupled artifacts must stay in sync when hooks change: CLAUDE.md (documentation), settings.json (hook config), and init.sh heredoc (consumer project generation). Manual sync across 3+ files per hook change. Upgrade.sh partially detects hook drift but not documentation drift.

**For whom:** Framework maintainers (currently one human + agent).
**Why now:** KCP pattern harvest (T-697) identified "single-source-of-truth generation" as a pattern worth evaluating.

## Assumptions

A-1: A structured manifest would reduce maintenance burden — TESTED: partially true for hooks, false for prose
A-2: CLAUDE.md can be generated — TESTED: only ~40% (hook tables, tier descriptions). 60% is hand-authored prose
A-3: The duplication is a real pain point — TESTED: yes for init.sh heredoc (150 lines duplicated), marginal for CLAUDE.md

## Exploration Plan

1. ~~Spike 1:~~ Inventory all sync points (settings.json ↔ init.sh ↔ CLAUDE.md ↔ upgrade.sh) — DONE
2. ~~Spike 2:~~ Design hypothetical manifest and evaluate generation complexity — DONE
3. ~~Spike 3:~~ Compare ROI of manifest vs targeted fixes — DONE

## Scope Fence

**IN:** Evaluate whether a structured manifest should be the source of truth for hooks + CLAUDE.md sections
**OUT:** Actually building the manifest/generator system, CLAUDE.md content changes

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact and recommendation in this task
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-702 no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Manifest approach significantly reduces maintenance burden (>50% fewer file touches per hook change)
- Generated output matches current quality of hand-authored CLAUDE.md

**NO-GO if:**
- CLAUDE.md is mostly prose that can't be generated
- Simpler fixes (copy+sed, audit check) address the real pain without new infrastructure

## Verification

# Research artifact exists
test -f docs/reports/T-702-single-source-of-truth.md
# Contains analysis
grep -q "Recommendation" docs/reports/T-702-single-source-of-truth.md

## Decisions

**Decision**: NO-GO

**Rationale**: - Recommendation: NO-GO
- Rationale: The problem is real (3-file sync on hook changes) but the proposed solution (structured manifest + generators) is over-engineered. CLAUDE.md is 60% hand-authore...

**Date**: 2026-03-29T13:33:17Z

## Recommendation

- **Recommendation:** NO-GO
- **Rationale:** The problem is real (3-file sync on hook changes) but the proposed solution (structured manifest + generators) is over-engineered. CLAUDE.md is 60% hand-authored prose that can't be generated. The worst pain point (init.sh 150-line heredoc duplication) has a 5-line fix: copy settings.json + sed for path prefix. Documentation drift can be caught by an audit check (~20 lines). Two targeted build tasks instead of one manifest system.
- **Evidence:**
  - Research artifact: `docs/reports/T-702-single-source-of-truth.md`
  - 14 hooks inventoried across 4 event types
  - init.sh heredoc is verbatim copy of settings.json (lines 543-691)
  - T-316 NO-GO confirms no CLAUDE.md include mechanism
  - Hook change frequency: ~1 per 6 tasks
- **Next steps after NO-GO:**
  - Optional: create build task for init.sh copy+sed (replaces 150-line heredoc with 5 lines)
  - Optional: create build task for audit hook-documentation check

## Decision

**Decision**: NO-GO

**Rationale**: - Recommendation: NO-GO
- Rationale: The problem is real (3-file sync on hook changes) but the proposed solution (structured manifest + generators) is over-engineered. CLAUDE.md is 60% hand-authore...

**Date**: 2026-03-29T13:33:17Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-29T12:59:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-29T13:32:56Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** - Recommendation: NO-GO
- Rationale: The problem is real (3-file sync on hook changes) but the proposed solution (structured manifest + generators) is over-engineered. CLAUDE.md is 60% hand-authore...

### 2026-03-29T13:32:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: NO-GO

### 2026-03-29T13:33:17Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** - Recommendation: NO-GO
- Rationale: The problem is real (3-file sync on hook changes) but the proposed solution (structured manifest + generators) is over-engineered. CLAUDE.md is 60% hand-authore...

### 2026-04-06T22:29:21Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-afdf7c22
- **Timestamp:** 2026-06-02T15:04:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
