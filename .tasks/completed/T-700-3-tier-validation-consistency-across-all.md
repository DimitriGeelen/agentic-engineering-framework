---
id: T-700
name: "3-tier validation consistency across all fw tools"
description: >
  Codify error/warn/clean pattern across ALL fw tools. We do this inconsistently —
  doctor uses it, audit uses it, but other commands don't. One standard. Score: 19/20
  (D1:5 D2:5 D3:5 D4:4). Source: T-697 pattern harvest #6.

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-03-29T08:57:21Z
last_update: '2026-06-11T22:24:27Z'
date_finished: 2026-03-29T14:15:55Z
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

# T-700: 3-tier validation consistency across all fw tools

## Context

Framework uses OK/FAIL/WARN output inconsistently: audit.sh has structured pass/warn/fail functions, doctor/preflight/init use inline echo with different formats. KCP pattern harvest scored this 19/20.

## Acceptance Criteria

### Agent
- [x] Current validation patterns inventoried across all fw commands
- [x] Alternatives evaluated (shared library vs exit code contract vs defer)
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review findings and approve go/no-go decision
  **Steps:**
  1. Read `docs/reports/T-700-validation-consistency.md`
  2. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-700 defer --rationale "your rationale"`
  **Expected:** Decision recorded
  **If not:** Ask for clarification

## Verification

test -f docs/reports/T-700-validation-consistency.md
grep -q "Recommendation" docs/reports/T-700-validation-consistency.md

## Decisions

**Decision**: DEFER

**Rationale**: - Recommendation: DEFER
- Rationale: Inconsistency is real but painless. Zero user complaints across 4 onboarding cycles. Audit (the only high-frequency validator) already has structured output. Do...

**Date**: 2026-03-29T13:33:39Z

## Recommendation

- **Recommendation:** DEFER
- **Rationale:** Inconsistency is real but painless. Zero user complaints across 4 onboarding cycles. Audit (the only high-frequency validator) already has structured output. Doctor/preflight are human-read, occasional commands. If CI needs machine-readable doctor output, add `--json` flag — don't restructure text output.
- **Evidence:**
  - Research artifact: `docs/reports/T-700-validation-consistency.md`
  - 3 commands with structured validation, 3 with partial, 7+ without
  - 83 OK/FAIL/WARN instances in bin/fw, 83 in audit.sh, 16 in preflight.sh
  - Zero user complaints about output inconsistency
- **Next steps after DEFER:** Revisit when CI/automation needs to parse doctor/preflight output

## Updates

### 2026-03-29T08:57:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-700-3-tier-validation-consistency-across-all.md
- **Context:** Initial task creation

### 2026-03-29T13:18:46Z — status-update [task-update-agent]
- **Change:** workflow_type: build → inception

### 2026-03-29T13:18:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-29T13:33:39Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** - Recommendation: DEFER
- Rationale: Inconsistency is real but painless. Zero user complaints across 4 onboarding cycles. Audit (the only high-frequency validator) already has structured output. Do...

### 2026-03-29T14:15:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-286b9ecd
- **Timestamp:** 2026-06-02T15:04:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
