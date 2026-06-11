---
id: T-021
name: Design experiment protocol for framework validation
description: >
  Define a set of deliberate experiments to validate framework assumptions and discover
  improvements. Key questions: Does overhead pay off? Which gates are load-bearing?
  Is portability real? Does context recovery work? Also answer the MVE question (minimum
  viable enforcement).
status: work-completed
workflow_type: specification
owner: human
priority: high
tags: [meta, D1, validation, experiments]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T22:20:00Z
last_update: '2026-06-11T22:23:35Z'
date_finished: 2026-02-13T22:23:07Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-021: Design experiment protocol for framework validation

## Design Record

**Approach:** Define experiments that test framework claims with observable outcomes. Each experiment should have:
- Hypothesis (what we expect)
- Method (how to test)
- Success criteria (what would confirm/refute)
- Failure indicator (what would prove us wrong)

**Key questions to answer:**
1. What's the minimum viable enforcement (MVE)?
2. Does the overhead pay off on real projects?
3. Which enforcement gates are load-bearing?
4. Is D4 (Portability) actually met?
5. Does handover + resume enable real context recovery?

## Specification Record

Acceptance criteria:
- [x] Define at least 4 experiments with hypothesis/method/criteria
- [x] Answer MVE question with rationale
- [x] Each experiment maps to a directive (D1-D4) or core mechanism
- [x] Experiments are actionable (can be run, not just theoretical)
- [x] Document expected learnings from each

## Test Files

N/A - this is a specification task

## Updates

### 2026-02-13T22:20:00Z — task-created [claude-code]
- **Action:** Created task for experiment protocol design
- **Context:** Recognized that major learnings (episodic quality gap) came from experimentation, not planning

### 2026-02-13T22:25:00Z — work-completed [claude-code]
- **Action:** Created 020-Experiments.md with full protocol
- **Output:**
  - MVE answered: Git commit hook (task reference required)
  - 5 experiments defined: E-001 through E-005
  - Each has hypothesis, method, success criteria, failure indicator
  - Prioritization matrix and recommended order
  - Updated 001-Vision.md to mark MVE question answered
- **Context:** Framework now has explicit validation path

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fceac7b2
- **Timestamp:** 2026-06-02T14:54:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
