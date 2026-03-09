---
id: T-358
name: "Inception: Human AC prerequisite gap — deployment steps missing"
description: >
  Human ACs assume code is already deployed but don't include deployment
  prerequisites. T-357 AC says 'run fw init in temp dir' but doesn't say
  'first brew upgrade fw'. The AC instruction process needs to account for
  deployment/distribution steps when the code under test is distributed via
  package manager (Homebrew), not just local dev. Additionally, human ACs
  should be self-contained runbooks — the human should be able to copy-paste
  and execute without asking "ok what do I need to do?" A good human AC
  includes: (1) prerequisite steps (deploy, upgrade, setup), (2) the test
  steps, (3) what to check, (4) expected output verbatim. If the human has
  to ask for clarification, the AC failed its purpose.

status: started-work
workflow_type: inception
owner: human
horizon: next
tags: [governance, quality]
components: []
related_tasks: [T-357, T-325]
created: 2026-03-08T18:42:46Z
last_update: 2026-03-09T06:52:56Z
date_finished: null
---

# T-358: Inception: Human AC prerequisite gap — deployment steps missing

## Problem Statement

Human ACs assume the agent's dev environment (code available locally, server running). When the human tests, they may need to deploy/upgrade/restart first. T-325 mandates Steps/Expected/If-not format but doesn't address prerequisite discovery. Result: humans can't execute ACs without asking "what do I need to do first?" Evidence: 3/5 surveyed active tasks missing deployment prerequisites. See `docs/reports/T-358-human-ac-prerequisite-gap.md`.

## Assumptions

1. T-325 format is sufficient if agents are reminded to include prerequisites — no new tooling needed
2. The gap is in guidance, not enforcement — agents write good ACs when told to include prerequisites
3. A one-paragraph CLAUDE.md addition is the right fix level

## Exploration Plan

1. Survey active task Human ACs (done — 3/5 missing prerequisites)
2. Check if T-325 format naturally catches this (finding: no, covers structure not content)
3. Draft CLAUDE.md addition and assess fit

## Technical Constraints

None — governance/documentation change only.

## Scope Fence

**IN:** Add prerequisite awareness guidance to CLAUDE.md Human AC Format Requirements
**OUT:** New enforcement gates, tooling changes, retroactive AC fixes

## Acceptance Criteria

- [x] Problem statement validated (3/5 tasks missing prerequisites)
- [x] Assumptions tested (T-325 covers format not prerequisites)
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Evidence shows >=2 tasks with missing prerequisites (found 3)
- Fix is additive to T-325 (confirmed — one paragraph)

**NO-GO if:**
- T-325 already covers prerequisites (it doesn't)
- Fix requires structural enforcement changes (it doesn't)

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

### 2026-03-09T06:52:56Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
