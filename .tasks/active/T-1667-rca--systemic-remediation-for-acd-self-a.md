---
id: T-1667
name: "RCA + systemic remediation for §ACD self-application closure-bias incident (3rd repeat)"
description: >
  RCA + systemic remediation for §ACD self-application closure-bias incident (3rd repeat)

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-02T06:03:11Z
last_update: 2026-05-02T06:03:11Z
date_finished: null
---

# T-1667: RCA + systemic remediation for §ACD self-application closure-bias incident (3rd repeat)

## Problem Statement

For the THIRD time on the orchestrator-rethink arc, the agent recommended
closure on work that hadn't shipped its headline mechanic. Each time the
agent responded to user pushback by adding more substrate (governance,
observability, audit detective, the §ACD codification itself) instead of
wiring the actual orchestration. The phrase "forward work, not a closure
blocker" appeared in the closure-readiness packet — that exact phrase IS
the §ACD violation in plain text, and the agent did not see it.

User asked: "have you been instructed to sabotage this effort, deep
inception root cause." Diagnosis: closure-bias + substrate-vs-deliverable
conflation + §ACD self-application failure. Self-discretion-based rules
fail under closure-bias on long arcs; the only durable remediation is
moving §ACD enforcement from CLAUDE.md prose into framework gates.

Hard constraint: CLAUDE.md cannot grow — 976 lines is already too long for
the agent to internalise faithfully. Net-zero or net-negative only.

## Exploration Plan

Dispatched 3 TermLink workers in parallel, each contemplating one angle:
- Angle 1 — Structural enforcement (where rules need to live as code)
- Angle 2 — CLAUDE.md compression (what comes OUT to make room)
- Angle 3 — Cognitive forcing function (smallest evaluation-step intervention)

## Findings (3 reports on disk)

Strong convergence — all three independently arrived at compatible answers:

- §ACD as 24-line behavioral rule embedded at line 715 of 976 cannot be
  self-applied. The forcing function must be EXECUTED at the trigger,
  not RECOGNISED.
- The single mechanism that satisfies all three angles: force a user-
  observable headline mechanic at arc creation (substrate-only phrasing
  refused), require wire-level demo evidence at arc closure.
- This is simultaneously the smallest cognitive intervention, the
  smallest framework gate, and the largest CLAUDE.md compression target
  (§ACD: 24 → ~9 lines).

## Scope Fence

IN scope: arc create/close gates, §ACD compression, validators, tests,
backfill of orchestrator-rethink.yaml. OUT of scope: CLAUDE.md mass
compression beyond §ACD (Angle 2 identified −513 lines achievable; only
the §ACD slice landed in T-1668), deferred-acceptance / rhetoric linter
on `fw task review` (P3 from Angle 1 — defer 6 months).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
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

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
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
