---
id: T-131
name: "Watchtower: Knowledge pages empty — surface framework learnings/patterns/decisions"
description: >
  Watchtower Knowledge nav (Learnings, Graduation, Patterns, Decisions) shows empty
  when viewing a project. Investigate: (1) Should framework-level knowledge (learnings.yaml,
  patterns.yaml, decisions.yaml from the framework repo) be inherited/visible in project
  Watchtower views? (2) Should projects auto-create seed knowledge from framework?
  (3) Should there be a fallback chain: project knowledge → framework knowledge? The
  framework has 40+ learnings, 7 failure patterns, and 15+ decisions that are relevant
  to ALL projects using it.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
related_tasks: []
created: 2026-02-17T23:30:16Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-02-18T09:38:15Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
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

# T-131: Watchtower: Knowledge pages empty — surface framework learnings/patterns/decisions

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- [Criterion 1]
- [Criterion 2]

**NO-GO if:**
- [Criterion 1]
- [Criterion 2]

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-18T09:38:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-18T09:38:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f89178e6
- **Timestamp:** 2026-06-02T14:56:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
