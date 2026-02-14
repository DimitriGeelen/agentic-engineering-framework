---
id: T-021
name: Design experiment protocol for framework validation
description: >
  Define a set of deliberate experiments to validate framework assumptions and discover improvements. Key questions: Does overhead pay off? Which gates are load-bearing? Is portability real? Does context recovery work? Also answer the MVE question (minimum viable enforcement).
status: work-completed
workflow_type: specification
owner: human
priority: high
tags: [meta, D1, validation, experiments]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T22:20:00Z
last_update: 2026-02-13T22:20:00Z
date_finished: 2026-02-13T22:23:07Z
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
