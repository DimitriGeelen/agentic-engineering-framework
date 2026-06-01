---
id: T-2159
name: "horizon terminal-state fix — completion→past transition + invariant guard"
description: >
  Inception: horizon terminal-state fix — completion→past transition + invariant guard

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-06-01T09:50:36Z
last_update: 2026-06-01T09:51:34Z
date_finished: 2026-06-01T09:51:34Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-01T09:51:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-2159: horizon terminal-state fix — completion→past transition + invariant guard

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
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
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
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** DEFER

**Rationale:**

Horizon axis (now/next/later) has a one-way coupling: tasks enter horizon: now when work starts but nothing moves them off when work completes. now silently accumulates terminal tasks. Fix direction is right (a past representation); exact mechanism is the open question. Step 0 verification required before design: confirm actual horizon storage / allowed values / current transition logic / read surfaces. Four open questions: (Q1) representation shape — clear / derived-past / settable-past with invariant protection; (Q2) which lifecycle statuses count as terminal; (Q3) backfill polluted data or grandfather; (Q4) read-surface filter implications. Per prompt: standalone task-system change, NOT entangled with T-2158 (continuous-run) or T-2157 (value-drivers).

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

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

**Rationale**: Recommendation: DEFER

Rationale:

Horizon axis (now/next/later) has a one-way coupling: tasks enter horizon: now when work starts but nothing moves them off when work completes. now silently accumulates terminal tasks. Fix direction is right (a past representation); exact mechanism is the open question. Step 0 verification required before design: confirm actual horizon storage / allowed values / current transition logic / read surfaces. Four open questions: (Q1) representation shape — clear / derived-past / settable-past with invariant protection; (Q2) which lifecycle statuses count as terminal; (Q3) backfill polluted data or grandfather; (Q4) read-surface filter implications. Per prompt: standalone task-system change, NOT entangled with T-2158 (continuous-run) or T-2157 (value-drivers).

Evidence:

**Date**: 2026-06-01T09:51:33Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-01T09:51:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-06-01T09:51:33Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: DEFER

Rationale:

Horizon axis (now/next/later) has a one-way coupling: tasks enter horizon: now when work starts but nothing moves them off when work completes. now silently accumulates terminal tasks. Fix direction is right (a past representation); exact mechanism is the open question. Step 0 verification required before design: confirm actual horizon storage / allowed values / current transition logic / read surfaces. Four open questions: (Q1) representation shape — clear / derived-past / settable-past with invariant protection; (Q2) which lifecycle statuses count as terminal; (Q3) backfill polluted data or grandfather; (Q4) read-surface filter implications. Per prompt: standalone task-system change, NOT entangled with T-2158 (continuous-run) or T-2157 (value-drivers).

Evidence:

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3ba147ba
- **Timestamp:** 2026-06-01T09:51:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-01T09:51:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
