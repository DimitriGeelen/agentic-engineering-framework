---
id: T-2186
name: "Recalibrate inception workflow — make inceptions first-class + prioritizable
  (VoI scoring, disposition gate, park state)"
description: >
  Research inception: today's prioritization (horizon + arc-focus) does not rank inceptions
  against each other, and the task estimator scores inceptions as if they were build
  tasks (low blast_radius/tier/effort → LV/LC quadrant) — exactly backwards for the
  highest-leverage moves the framework makes. This inception recalibrates the workflow
  so inceptions are first-class and prioritizable via value-of-information (VoI) scoring,
  a disposition-rationale gate, and a Sovereign investment-decision park state. Seed
  prompt + open questions IW-1..IW-7 + deliverables live in docs/reports/T-2186-recalibrate-inception-workflow-seed.md.
  Producer≠judge principle is consumed
  here as given — its governance elevation is a separate spin-out. Step 0 (discovery
  prerequisite) must be done before any working conclusion is treated as fact. No
  build tasks before fw inception decide go.

status: captured
workflow_type: inception
owner: agent
horizon: next
tags: [inception, workflow, prioritization, bvp, governance]
components: []
related_tasks: []
created: 2026-06-02T21:18:05Z
last_update: 2026-06-02T21:25:46Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-02T21:20:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-02T21:25:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2186: Recalibrate inception workflow — make inceptions first-class + prioritizable (VoI scoring, disposition gate, park state)

## Problem Statement

Today's prioritization (horizon + arc-focus) does not rank inceptions against each other.
Worse, the BVP estimator scores inceptions as if they were build tasks — near-floor
cost (low blast_radius/tier/effort) + weak direct-directive support lands them in the
LV/LC "trivial" quadrant. That is exactly backwards: inceptions are among the
highest-leverage moves the framework makes, since they decide *whether and how* a
downstream class of work will help D1–D4. Without a way to rank inceptions, the
backlog mis-allocates discovery capacity.

**Full seed material:** [docs/reports/T-2186-recalibrate-inception-workflow-seed.md](../../docs/reports/T-2186-recalibrate-inception-workflow-seed.md)
— the human-supplied scope prompt with agent orientation, working conclusions to
pressure-test, Step 0 discovery prerequisite, the seven open questions (IW-1…IW-7),
deliverables, and constraints. Read the seed in full before any working conclusion is
treated as fact.

## Assumptions

The seed contains 8 working conclusions framed as "from prior reasoning — to be
confirmed, sharpened, or refuted." They MUST be pressure-tested by Step 0 against
ground truth, not assumed. Register each as a formal assumption with
`fw assumption add` once Step 0 names what to verify against. The eight in the seed:

- A1: Inception value is anticipatory (value-of-information), not intrinsic
- A2: `blast_radius` and `tier` flip from cost to value/risk for inceptions
- A3: Arc-anchored inceptions inherit arc BVP (Model B); orphan inceptions score by VoI
- A4: No new ceremony, no new "kind" — extend the existing workflow with a gate state
- A5: Gate is dispositions-with-rationale, not predicates ("answered/deferred/dissolved")
- A6: Producer ≠ judge — a separate entity scores; scrutiny scales with stakes
- A7: After the gate, fork to direct-build OR park in investment-decision state
- A8: `work-started` → `discovery-started` rename is implementation, not principle

## Exploration Plan

Time-boxed sequence (full detail in the seed):

1. **Step 0 — Discovery prerequisite.** Map the ACTUAL inception lifecycle (states,
   transitions, mandatory-vs-optional checks) in `010-TaskSystem`, `lib/`, `fw`
   inception verbs, `040-ValueDrivers`. Confirm or refute each assumption above.
   Output: Discovery note section A.
2. **Work IW-1…IW-7 to dispositions.** Each open question gets *answered* (with
   verifiable evidence), *deferred* (with reason + follow-up), or *dissolved*
   (question was malformed). Never binary "yes/no" — the §ACD discipline applies.
3. **Recalibrated lifecycle spec.** States, transitions, the gate, the park state,
   the rename. Contracts tight; judgments named with adjudicators, not predicates.
4. **Prioritization mechanism.** VoI math + inherit-vs-VoI routing + blast/tier
   sign-flip — slotted into 040 (math) and the inception doc (placement).
5. **Constituent build-task slices** as runnable `fw task create` invocations —
   filed only after `fw inception decide go`.

## Technical Constraints

This is a research inception — no platform/network/hardware constraints. The relevant
constraints are framework-internal:

- §ACD (Arc Completion Discipline) — the gate proposal MUST embody evidence-or-
  justified-absence, not a checkbox a "yes" can satisfy
- Producer ≠ judge — consumed as given; do NOT re-legislate (separate spin-out owns
  governance elevation)
- Inception 2-commit exploration limit — `fw inception decide` is mandatory before
  any build-task slice fires
- The recalibration MUST fit the existing inception lifecycle's mandatory-vs-optional
  pattern (Step 0 names this) — no parallel ceremony

## Scope Fence

**IN scope:**
- Inception workflow recalibration (states, gate, park state, rename)
- Inception scoring (VoI math, blast/tier sign-flip for `workflow_type: inception`)
- Inherit-vs-VoI routing for arc-anchored vs orphan inceptions
- 040 ↔ inception-doc ownership seam
- Documentation home recommendation (IW-7)
- Constituent build-task slices (filed only after `decide go`)

**OUT of scope:**
- Producer ≠ judge governance elevation (separate spin-out — see seed §"The seed")
- Build-task workflow changes (only inceptions are being recalibrated)
- Arc scoring changes (arc BVP stays as Model B; this inception consumes it)
- Estimator implementation rewrites (proposal layer only; build slices follow `decide go`)

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

### 2026-06-02T21:20:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-06-02T21:24:02Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-06-02T21:25:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-06-02T21:25:46Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)
