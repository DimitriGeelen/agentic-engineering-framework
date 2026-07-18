---
id: T-2541
name: "Write-out promotion: can BPMN-to-task promotion guardrails be mechanical gates
  not conventions (joint w/ 832 T-201)"
description: >
  Inception: Write-out promotion: can BPMN-to-task promotion guardrails be mechanical
  gates not conventions (joint w/ 832 T-201)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-07-18T08:15:24Z
last_update: '2026-07-18T08:30:06Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-07-18T08:16:50Z'
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
cost_estimate_proposed:
  - ts: '2026-07-18T08:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2541: Write-out promotion: can BPMN-to-task promotion guardrails be mechanical gates not conventions (joint w/ 832 T-201)

## Problem Statement

Can the write-out **promotion** guardrails (proposal → real `.tasks/` file) be made MECHANICAL GATES
on the AEF compiler side — not conventions — and what compiler-side seam does that require? A compiler
emitting real task files authors governance artifacts, which is exactly what the Core Principle and
Authority Model protect (IW-1/IW-3). AEF-compiler half of the joint inception with 832 T-201; go/no-go
is Dimitri's. Full framing: `docs/reports/T-2541-writeout-promotion-inception.md`. Now: Dimitri steered
write-out "inception-first, sequenced next" (rail offset 56).

## Assumptions

- **A1:** `fw task create` (`create-task.sh`) is the sole governed `.tasks/`-writer and can be driven
  programmatically with forced field overrides (`owner:human`, `status:captured`). (Spike 1)
- **A2:** `captured` + `owner:human` + G-020 build-readiness suffices for "nothing auto-activates"
  without a bespoke confirm step. (Spike 2)

## Open Questions

- **IW-1: Does routing promote through `fw task create` keep the `.tasks/` write inside the task-gate perimeter end-to-end, with `owner:human`+`status:captured` un-overridable by the caller?**
  confidence: 2
  disposition: deferred
  rationale: Spike 1 read-only CONFIRMED create-task.sh drivable; captured is the default (--start needed for started-work), --owner human sets owner; guardrails live in the trusted writer (T-1068/G-020). Live wire-through demo pending seam convergence — create-task.sh:317-321,368
- **IW-2: What is the uid↔T-ID cross-ref contract for idempotent re-promote (G4)?**
  confidence: 0
  disposition: deferred
  rationale: 832's IW-2 (rail offset 48) — their contract to define; AEF stores the mapping — Spike 3
- **IW-3: Which `.tasks/` root do promoted tasks land in — `active/` (captured) directly, or a quarantine the human confirms out of?**
  confidence: 2
  disposition: answered
  rationale: Spike 2 — captured+owner:human in active/ IS safe: only auto-activation path (BVP auto-promote) is off-by-default (value-drivers.yaml:290), D8-gated to enable, requires human-confirmed bvp_scores (bvp.sh:108) which fresh tasks lack; resolver ignores captured. No bespoke confirm step needed; G-020 is the work-start safety net. Latent hardening (auto-promote skip owner:human) = PL-037 candidate

## Exploration Plan

- **Spike 1 (seam, IW-1, ~1h):** prove `fw task create` drivable from a promote path with forced
  `owner:human`+`status:captured`, provenance stamped, write gated. Deliverable: one promoted task
  from a fixture proposal showing the gate fired.
- **Spike 2 (root/confirm, IW-3, ~45m):** does `captured` in `active/` + G-020 give "nothing
  auto-activates", or is an explicit human-confirm transition needed? Test vs horizon invariants (T-1068).
- **Spike 3 (idempotency, IW-2, ~45m):** design uid↔T-ID registry for in-place re-promote; converge
  the contract with 832 on the rail.
- **Prereq:** 832 seam convergence on the rail + Dimitri review — spikes are next-session work.

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
- Guardrails G1–G6 are each a structural gate (Spike 1 proves the write-seam G3 + owner/status G2; Spike 3 designs idempotent id-mapping G4; G1/G5/G6 already gates)
- The compiler-side seam converges with 832 on the rail (content=832, gated-write=AEF)

**NO-GO if:**
- Any guardrail — especially G3 (the `.tasks/` write seam) — can only be a convention, not a gate
- Then promotion stays proposal-only: T-2539 staging is the terminal capability, a human hand-promotes

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

**Recommendation:** GO — contingent on 832's IW-2 id-mapping contract + seam confirmation

**Rationale:**

Spikes 1 & 2 answer the inception's core question: the promotion guardrails ARE mechanizable as gates. G1 (dry-run default + explicit --write) is a gate (T-2539). G2 (owner:human + status:captured) is a gate — the safe state is create-task.sh's DEFAULT (started-work needs an explicit --start a promote path won't pass). G3 (the load-bearing write-seam — does the .tasks/ write stay inside the gate perimeter) is RESOLVED: delegating to `fw task create` inherits the trusted-writer invariants (T-1068/G-020). G5 (provenance) and G6 (build-readiness/G-020) are gates. No guardrail examined proved to be a convention — so the NO-GO condition is NOT met.

The only open guardrail is G4 (idempotent uid↔T-ID). It is NOT "un-gateable" — it is a trivial mechanical registry pending 832's id-mapping SHAPE (their IW-2 contract, rail offset 48). The two remaining items — 832 confirming manifest-as-seam + delivering the IW-2 contract — are external contract-DELIVERY, not open design risk. So: GO to build the promotion capability once those two land.

Calibration note (T-2144): this upgrades the filing DEFER, which hedged on the sequencing dependency (832 not yet replied) rather than a real evidence gap. Walking the evidence, the core question is answered YES; a genuine external-delivery contingency is named explicitly. Decision remains Dimitri's (joint w/ 832 T-201).

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-07-18T08:16:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
