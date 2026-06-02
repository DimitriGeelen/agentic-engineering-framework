---
id: T-703
name: "Incremental adoption levels — fw init --level 1|2|3"
description: >
  Level 1 = tasks only, Level 2 = + context fabric, Level 3 = full governance. Reduces onboarding friction. Score: 18/20 (D1:4 D2:5 D3:5 D4:4). Source: T-697 pattern harvest #16.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [onboarding, kcp-pattern]
components: []
related_tasks: []
created: 2026-03-29T08:57:55Z
last_update: 2026-04-13T06:23:26Z
date_finished: 2026-03-29T13:32:45Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-703: Incremental adoption levels — fw init --level 1|2|3

## Problem Statement

`fw init` is all-or-nothing: 13 directories, 10+ YAML files, 14 hooks, 1024-line CLAUDE.md. Hypothesis: tiered adoption (Level 1=tasks, Level 2=+context, Level 3=full) would reduce onboarding friction.

**For whom:** New framework users.
**Why now:** Launch approaching (T-334), onboarding friction directly affects adoption. Scored 18/20 in KCP pattern harvest.

## Assumptions

A-1: File count is the onboarding barrier — TESTED: false. Onboarding cycles (T-104, T-107) showed zero file-count complaints. Friction is cognitive/mental-model
A-2: Levels reduce complexity — TESTED: false. Adds 3 CLAUDE.md variants, 12 test paths, upgrade-between-levels logic. Net complexity increase
A-3: Users want partial governance — UNTESTED: no evidence either way, but the value of governance is in the combination of hooks, not individual ones

## Scope Fence

**IN:** Evaluate whether `fw init --level 1|2|3` should be built
**OUT:** Actually building the tiered init, modifying existing init flow

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
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-703 no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Evidence that file count is the actual onboarding barrier (not cognitive load)
- Levels can be implemented without 3 CLAUDE.md variants

**NO-GO if:**
- Onboarding friction is primarily cognitive/mental-model, not file count
- Implementation complexity (3 templates, 12 test paths, upgrade logic) exceeds benefit

## Verification

# Research artifact exists
test -f docs/reports/T-703-incremental-adoption.md
# Contains analysis
grep -q "Recommendation" docs/reports/T-703-incremental-adoption.md

## Decisions

**Decision**: NO-GO

**Rationale**: - Recommendation: NO-GO
- Rationale: The hypothesis "too many files = onboarding friction" is not supported by evidence. Onboarding cycles (T-104, T-107, T-356) showed zero complaints about file co...

**Date**: 2026-03-29T13:33:23Z

## Recommendation

- **Recommendation:** NO-GO
- **Rationale:** The hypothesis "too many files = onboarding friction" is not supported by evidence. Onboarding cycles (T-104, T-107, T-356) showed zero complaints about file count. All friction was about understanding hooks, task requirements, and the mental model. Implementing 3 levels would triple the testing surface, require 3 CLAUDE.md variants (no include mechanism, per T-316), and add upgrade-between-levels logic — all to solve a problem that doesn't exist.
- **Evidence:**
  - Research artifact: `docs/reports/T-703-incremental-adoption.md`
  - Current init creates ~35 files in <2 seconds — user never sees most of them
  - Onboarding observations: zero file-count complaints across 4 onboarding cycles
  - T-316 NO-GO: no CLAUDE.md include mechanism — 3 variants would drift
  - Consumer CLAUDE.md is already a subset (~300 lines vs 1024)
- **Next steps after NO-GO:**
  - Consider: `fw tutorial` — interactive walkthrough of first task+edit+complete
  - Consider: shorter consumer CLAUDE.md template review
  - Consider: improve task-gate error messages with inline explanations

## Decision

**Decision**: NO-GO

**Rationale**: - Recommendation: NO-GO
- Rationale: The hypothesis "too many files = onboarding friction" is not supported by evidence. Onboarding cycles (T-104, T-107, T-356) showed zero complaints about file co...

**Date**: 2026-03-29T13:33:23Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-29T13:02:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-29T13:32:45Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** - Recommendation: NO-GO
- Rationale: The hypothesis "too many files = onboarding friction" is not supported by evidence. Onboarding cycles (T-104, T-107, T-356) showed zero complaints about file co...

### 2026-03-29T13:32:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: NO-GO

### 2026-03-29T13:33:23Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** - Recommendation: NO-GO
- Rationale: The hypothesis "too many files = onboarding friction" is not supported by evidence. Onboarding cycles (T-104, T-107, T-356) showed zero complaints about file co...

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d8e19aef
- **Timestamp:** 2026-06-02T15:04:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
