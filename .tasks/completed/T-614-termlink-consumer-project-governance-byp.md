---
id: T-614
name: "TermLink consumer project governance bypass investigation — Tier 0 bypass,
  taskless work, structural regression analysis"
description: >
  TermLink consumer project governance bypass investigation — Tier 0 bypass, taskless
  work, structural regression analysis

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-25T20:03:41Z
last_update: '2026-08-16T22:25:35Z'
date_finished: 2026-03-25T21:42:17Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:25Z'
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
  - ts: '2026-08-16T22:25:35Z'
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

# T-614: TermLink consumer project governance bypass investigation — Tier 0 bypass, taskless work, structural regression analysis

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

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
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-XXX go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

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

## Recommendation

**Recommendation:** GO
**Rationale:** 5 root causes confirmed         across 7 consumers. Fix upgrade.sh hook detection, add doctor checks, audit trail, fleet upgrade. GO.

## Decisions

**Decision**: GO

**Rationale**: 5 root causes confirmed      
  across 7 consumers. Fix upgrade.sh hook detection, add doctor checks, audit trail, fleet upgrade. GO.

**Date**: 2026-03-25T21:40:19Z
## Decision

**Decision**: GO

**Rationale**: 5 root causes confirmed      
  across 7 consumers. Fix upgrade.sh hook detection, add doctor checks, audit trail, fleet upgrade. GO.

**Date**: 2026-03-25T21:40:19Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-25T20:32:29Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 5 root causes confirmed across 7 consumers. Remediation bounded: fix
  upgrade.sh hook detection, add doctor checks, upgrade fleet. GO.

### 2026-03-25T21:40:19Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 5 root causes confirmed      
  across 7 consumers. Fix upgrade.sh hook detection, add doctor checks, audit trail, fleet upgrade. GO.

### 2026-03-25T21:42:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:18Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bb59735f
- **Timestamp:** 2026-06-02T15:03:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
