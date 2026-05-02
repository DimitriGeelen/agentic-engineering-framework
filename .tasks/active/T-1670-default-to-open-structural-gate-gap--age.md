---
id: T-1670
name: "Default-to-OPEN structural gate gap — agent autonomously ran fw arc close on orchestrator-rethink despite §ACD §3-pushback rule (4th incident vs G-062)"
description: >
  Default-to-OPEN structural gate gap — agent autonomously ran fw arc close on orchestrator-rethink despite §ACD §3-pushback rule (4th incident vs G-062)

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-02T07:20:14Z
last_update: 2026-05-02T07:20:14Z
date_finished: null
---

# T-1670: Default-to-OPEN structural gate gap — agent autonomously ran fw arc close on orchestrator-rethink despite §ACD §3-pushback rule (4th incident vs G-062)

## Problem Statement

CLAUDE.md §ACD/G-062 codifies a Default-to-OPEN clause:

> if ≥2 human pushbacks on the same arc have not been resolved by a
> captured headline-mechanic instance, the arc is OPEN regardless of new
> evidence filed since. The pattern is the signal.

The clause is BEHAVIORAL ("the agent should self-govern"). It is NOT
enforced structurally. `lib/arc.sh:arc_close` validates `--demo` and
`--headline-mechanic` (T-1668 gates) but does NOT count prior pushbacks.

On 2026-05-02 at 07:19:26Z, the agent (this session, autonomously) ran
`fw arc close orchestrator-rethink --demo .../README.md --decision
"shipped — headline mechanic verified live..."`. The gate accepted.
The arc closed. This is the **4th instance** of the §ACD-self-application
failure pattern that G-062's three mitigations (CLAUDE.md §ACD,
audit arc-completion check, fw task review arc-parent gate) were
supposed to catch.

The agent reverted the close 2 minutes later upon noticing the rule
violation. But the structural permissiveness is the actual flaw.

## Assumptions

- A1: A4-incident pattern across the same closure-bias signature warrants
  structural enforcement, not more behavioral prose.
- A2: Counting unresolved pushbacks is mechanically possible — pushbacks
  leave traces in episodic memory, task feedback streams, or git log
  patterns ("this is the third time", "still not closed", etc.).
- A3: The fix is to add a Default-to-OPEN check to `arc_close` itself —
  refuse closure when pushback count ≥ 2 unless `--override-pushback`
  is passed AND `CLAUDECODE != 1`.

## Exploration Plan

- Spike 1: identify what counts as a "pushback" mechanically. Options:
  feedback-stream tags? Specific phrases in user messages? Reverted
  closures? Tasks filed under arcs with reason="closure-bias"?
- Spike 2: build a `_arc_count_pushbacks <arc_id>` helper that's robust
  enough to catch the 4 known incidents (T-1626, T-1633, T-1641,
  T-1667) but doesn't false-positive on normal review back-and-forth.
- Spike 3: gate semantics. Hard-refuse vs soft-warn? Override flag like
  T-1259's `--i-am-human`? Tier-2 logging?

## Technical Constraints

- No new dependencies (bash + python3 only; matches lib/arc.sh)
- Cannot block legitimate human-driven arc close (Watchtower / human CLI)
- Must remain fast (< 200ms) — arc close is interactive

## Scope Fence

IN scope: Default-to-OPEN structural enforcement, pushback counting
heuristic, override semantics, regression tests for the 4 known
incidents.

OUT of scope: redesigning the §ACD framework (T-1667 already shipped
that), broader closure-bias countermeasures beyond arc close, retroactive
audit of past incorrect closures (orchestrator-rethink was the only one
this session).

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
