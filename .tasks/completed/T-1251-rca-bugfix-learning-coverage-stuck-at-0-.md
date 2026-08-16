---
id: T-1251
name: "RCA: Bugfix-learning coverage stuck at 0% despite T-1178 T-1192 remediation"
description: >
  Inception: RCA: Bugfix-learning coverage stuck at 0% despite T-1178 T-1192 remediation

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-14T07:01:51Z
last_update: '2026-08-16T22:24:27Z'
date_finished: 2026-04-18T22:41:21Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:43Z'
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
  - ts: '2026-08-16T22:24:27Z'
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

# T-1251: RCA: Bugfix-learning coverage stuck at 0% despite T-1178 T-1192 remediation

## Problem Statement

The audit reports `[FAIL] Bugfix-learning coverage: 0% (1/242)` — of 242 completed
"bugfix" tasks, only 1 has an associated learning entry.

T-1178 (inception, completed) and T-1192 (build, completed) previously addressed
this (G-016 structural enforcement: enhanced bugfix-learning prompt + audit escalation).
Yet coverage remains at 0%. Why did the prior remediation not move the needle?

## Assumptions

- A1: The prior fixes (T-1178/T-1192) were actually deployed and are running
- A2: The `fw fix-learned` command works correctly when invoked
- A3: Agents are simply not invoking `fw fix-learned` after bugfixes
- A4: The audit detection matches actual bugfix intent (not false positives)
- A5: The problem is capture-side (agents skip it), not detection-side (mis-counted)

## Exploration Plan

1. **Spike A (15min):** Grep episodic memory for T-1178/T-1192 remediation details;
   confirm what was actually shipped.
2. **Spike B (20min):** Sample 10 completed bugfix tasks at random. For each, check:
   (a) was it a real field-discovered bug? (b) does it have a learning? (c) why not?
3. **Spike C (15min):** Check if the bugfix-learning prompt fires and what the
   agent response usually is.
4. **Spike D (10min):** Count false positives in the 242 — tasks matching "fix"
   but not actual bugs (e.g., "Fix typo", "Fix formatting").

## Technical Constraints

- Cannot retroactively recreate learnings for 200+ historical tasks
- Must not introduce friction that causes agents to skip completion
- Changes must not weaken G-016 (the detective control)

## Scope Fence

**IN:** Why prior remediation failed; what's different about the capture flow now
**IN:** Recommend next iteration (tighten, re-prompt, structural enforcement)
**OUT:** Retroactive learning capture for historical tasks (separate question)
**OUT:** Implementing the fix (separate build task after GO)

## Acceptance Criteria

### Agent
- [x] Spike A complete: T-1178/T-1192 remediation reconstructed (advisory-only, no enforcement)
- [x] Spike B complete: sample analyzed via T-1252 data (66% false positives, ~83 real field bugs)
- [x] Spike C complete: prompt at update-task.sh:880-887 is advisory-only yellow box
- [x] Spike D complete: false-positive rate ~66% via T-1252 bulk classifier
- [x] Research artifact written to docs/reports/T-1251-bugfix-learning-rca.md
- [x] Recommendation written with rationale and GO/NO-GO/DEFER

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO — two-part structural fix

**Rationale:** T-1178/T-1192 shipped purely advisory remediation (yellow box, audit
FAIL). Proven insufficient — coverage remained at 0%. Need (a) reduce capture cost
via auto-draft from commit message, and (b) explicit opt-out flag so agents can
distinguish "skipped this learning" from "not learning-worthy".

**Evidence:**
- T-1192 episodic confirms advisory-only shipping (no blocking, no retry)
- Current prompt at update-task.sh:880-887 is visual noise easy to skip
- `fw fix-learned` requires synthesizing one-sentence learning — high cognitive cost
- Existing gates have opt-out patterns (--force, --skip-acceptance-criteria) — same design applies
- See full research artifact: docs/reports/T-1251-bugfix-learning-rca.md

**Next step if GO:** Create `T-1256-build: auto-draft bugfix learning + --no-learning opt-out flag`

**Complementary to:** T-1252 (narrow audit denominator — parallel inception)

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — two-part structural fix

Rationale: T-1178/T-1192 shipped purely advisory remediation (yellow box, audit
FAIL). Proven insufficient — coverage remained at 0%. Need (a) reduce capture cost
via auto-draft from commit message, and (b) explicit opt-out flag so agents can
distinguish "skipped this learning" from "not learning-worthy".

Evidence:
- T-1192 episodic confirms advisory-only shipping (no blocking, no retry)
- Current prompt at update-task.sh:880-887 is visual noise easy to skip
- `fw fix-learned` requires synthesizing one-sentence learning — high cognitive cost
- Existing gates have opt-out patterns (--force, --skip-acceptance-criteria) — same design applies
- See full research artifact: docs/reports/T-1251-bugfix-learning-rca.md

Next step if GO: Create `T-1256-build: auto-draft bugfix learning + --no-learning opt-out flag`

Complementary to: T-1252 (narrow audit denominator — parallel inception)

**Date**: 2026-04-18T22:41:56Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-14T07:05:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-18T22:41:21Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — two-part structural fix

Rationale: T-1178/T-1192 shipped purely advisory remediation (yellow box, audit
FAIL). Proven insufficient — coverage remained at 0%. Need (a) reduce capture cost
via auto-draft from commit message, and (b) explicit opt-out flag so agents can
distinguish "skipped this learning" from "not learning-worthy".

Evidence:
- T-1192 episodic confirms advisory-only shipping (no blocking, no retry)
- Current prompt at update-task.sh:880-887 is visual noise easy to skip
- `fw fix-learned` requires synthesizing one-sentence learning — high cognitive cost
- Existing gates have opt-out patterns (--force, --skip-acceptance-criteria) — same design applies
- See full research artifact: docs/reports/T-1251-bugfix-learning-rca.md

Next step if GO: Create `T-1256-build: auto-draft bugfix learning + --no-learning opt-out flag`

Complementary to: T-1252 (narrow audit denominator — parallel inception)

### 2026-04-18T22:41:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-18T22:41:56Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — two-part structural fix

Rationale: T-1178/T-1192 shipped purely advisory remediation (yellow box, audit
FAIL). Proven insufficient — coverage remained at 0%. Need (a) reduce capture cost
via auto-draft from commit message, and (b) explicit opt-out flag so agents can
distinguish "skipped this learning" from "not learning-worthy".

Evidence:
- T-1192 episodic confirms advisory-only shipping (no blocking, no retry)
- Current prompt at update-task.sh:880-887 is visual noise easy to skip
- `fw fix-learned` requires synthesizing one-sentence learning — high cognitive cost
- Existing gates have opt-out patterns (--force, --skip-acceptance-criteria) — same design applies
- See full research artifact: docs/reports/T-1251-bugfix-learning-rca.md

Next step if GO: Create `T-1256-build: auto-draft bugfix learning + --no-learning opt-out flag`

Complementary to: T-1252 (narrow audit denominator — parallel inception)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-909422cb
- **Timestamp:** 2026-06-02T14:56:13Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
