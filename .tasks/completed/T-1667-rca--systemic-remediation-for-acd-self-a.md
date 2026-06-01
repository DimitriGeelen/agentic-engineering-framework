---
id: T-1667
name: "RCA + systemic remediation for §ACD self-application closure-bias incident (3rd repeat)"
description: >
  RCA + systemic remediation for §ACD self-application closure-bias incident (3rd repeat)

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: [C-004, lib/arc.sh, tests/unit/test_arc_system.py, tests/unit/test_audit_arc_completion.py]
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-02T06:03:11Z
last_update: 2026-05-02T07:37:51Z
date_finished: 2026-05-02T07:37:51Z
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

**Recommendation:** GO

**Rationale:** Three-agent inception research converged on a single
mechanism (`--headline-mechanic` at arc creation + `--demo` at arc
close) that simultaneously satisfies all three angles: smallest
cognitive intervention, smallest framework gate, largest CLAUDE.md
compression target (§ACD: 24 → 9 lines, net-negative). The fix shipped
as T-1668 and is now load-bearing in lib/arc.sh — the gates cannot be
self-bypassed by closure-bias. T-1669 then delivered the actual
orchestration (the missing thing the original 3 pushbacks were about);
the arc's headline_mechanic is captured at
`docs/reports/orchestrator-rethink-demo/`.

**Evidence:**
- T-1668 commit `8a31c99c7` — gates implemented + tested (28/28)
- CLAUDE.md compressed 976 → 961 lines (§ACD: 24 → 9)
- T-1669 demo dir — proves the structural intervention freed the
  agent to deliver the actual orchestration on the same arc
- 3 worker reports under `docs/reports/T-1667-angle-{1,2,3}-*.md`
- `_arc_validate_headline_mechanic` + `_arc_validate_demo_path` in
  lib/arc.sh:84-180 — the runtime enforcement
- Live verification: `bin/fw arc close orchestrator-rethink --decision X`
  refuses without `--demo`, prints `headline_mechanic` to operator

**Go/No-Go criteria evaluation:**
- Root cause identified with bounded fix path: YES (closure-bias +
  substrate-vs-deliverable conflation; fix = move §ACD into gates)
- Fix is scoped, testable, reversible: YES (one PR, 28 tests pin the
  gates, gates can be removed by reverting `8a31c99c7`)
- Problem requires fundamental redesign or unbounded scope: NO
- Fix cost exceeds benefit given current evidence: NO (the same
  agent that pushed back 3 times then shipped the actual delivery
  on the very next task — T-1669 — within one session post-fix)

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

**Rationale**: Recommendation: GO

Rationale: Three-agent inception research converged on a single
mechanism (`--headline-mechanic` at arc creation + `--demo` at arc
close) that simultaneously satisfies all three angles: smallest
cognitive intervention, smallest framework gate, largest CLAUDE.md
compression target (§ACD: 24 → 9 lines, net-negative). The fix shipped
as T-1668 and is now load-bearing in lib/arc.sh — the gates cannot be
self-bypassed by closure-bias. T-1669 then delivered the actual
orchestration (the missing thing the original 3 pushbacks were about);
the arc's headline_mechanic is captured at
`docs/reports/orchestrator-rethink-demo/`.

Evidence:
- T-1668 commit `8a31c99c7` — gates implemented + tested (28/28)
- CLAUDE.md compressed 976 → 961 lines (§ACD: 24 → 9)
- T-1669 demo dir — proves the structural intervention freed the
  agent to deliver the actual orchestration on the same arc
- 3 worker reports under `docs/reports/T-1667-angle-{1,2,3}-.md`
- `_arc_validate_headline_mechanic` + `_arc_validate_demo_path` in
  lib/arc.sh:84-180 — the runtime enforcement
- Live verification: `bin/fw arc close orchestrator-rethink --decision X`
  refuses without `--demo`, prints `headline_mechanic` to operator

Go/No-Go criteria evaluation:
- Root cause identified with bounded fix path: YES (closure-bias +
  substrate-vs-deliverable conflation; fix = move §ACD into gates)
- Fix is scoped, testable, reversible: YES (one PR, 28 tests pin the
  gates, gates can be removed by reverting `8a31c99c7`)
- Problem requires fundamental redesign or unbounded scope: NO
- Fix cost exceeds benefit given current evidence: NO (the same
  agent that pushed back 3 times then shipped the actual delivery
  on the very next task — T-1669 — within one session post-fix)

**Date**: 2026-05-02T07:37:51Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-02T07:28:58Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

### 2026-05-02T07:37:51Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Three-agent inception research converged on a single
mechanism (`--headline-mechanic` at arc creation + `--demo` at arc
close) that simultaneously satisfies all three angles: smallest
cognitive intervention, smallest framework gate, largest CLAUDE.md
compression target (§ACD: 24 → 9 lines, net-negative). The fix shipped
as T-1668 and is now load-bearing in lib/arc.sh — the gates cannot be
self-bypassed by closure-bias. T-1669 then delivered the actual
orchestration (the missing thing the original 3 pushbacks were about);
the arc's headline_mechanic is captured at
`docs/reports/orchestrator-rethink-demo/`.

Evidence:
- T-1668 commit `8a31c99c7` — gates implemented + tested (28/28)
- CLAUDE.md compressed 976 → 961 lines (§ACD: 24 → 9)
- T-1669 demo dir — proves the structural intervention freed the
  agent to deliver the actual orchestration on the same arc
- 3 worker reports under `docs/reports/T-1667-angle-{1,2,3}-.md`
- `_arc_validate_headline_mechanic` + `_arc_validate_demo_path` in
  lib/arc.sh:84-180 — the runtime enforcement
- Live verification: `bin/fw arc close orchestrator-rethink --decision X`
  refuses without `--demo`, prints `headline_mechanic` to operator

Go/No-Go criteria evaluation:
- Root cause identified with bounded fix path: YES (closure-bias +
  substrate-vs-deliverable conflation; fix = move §ACD into gates)
- Fix is scoped, testable, reversible: YES (one PR, 28 tests pin the
  gates, gates can be removed by reverting `8a31c99c7`)
- Problem requires fundamental redesign or unbounded scope: NO
- Fix cost exceeds benefit given current evidence: NO (the same
  agent that pushed back 3 times then shipped the actual delivery
  on the very next task — T-1669 — within one session post-fix)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-4a9be6cf
- **Timestamp:** 2026-05-02T07:37:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-02T07:37:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
