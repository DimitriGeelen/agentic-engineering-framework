---
id: T-2687
name: "promote origin-free band-feasibility to a corpus lint rule"
description: >
  Decide whether the origin-free band-feasibility interval (does ANY band origin place
  every node inside its own declared band, by interval algebra over stored aef:laneMeta
  heights) should graduate from a T-2686 test helper into a first-class fw corpus
  lint rule alongside lane-geometry. Two bounded design calls: (1) node-top vs node-centre
  resolution — 832's laneAtY uses centreY, so the rule must pick a convention or accept
  both; (2) re-baselining the whole corpus against a strictly stronger rule, since
  ordered non-overlapping spans are necessary for feasibility but not sufficient,
  so maps currently clean under lane-geometry may fail this.

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-07-29T21:58:24Z
last_update: 2026-07-29T22:01:07Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-07-29T22:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-29T22:00:10Z'
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

# T-2687: promote origin-free band-feasibility to a corpus lint rule

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

- **IW-1: does the rule resolve a node's band from its stored top-y or from its centre,
  and does the choice change any verdict?** 832's `laneAtY` uses `centreY`, so their
  renderer and a top-y rule disagree by the node half-height. A uniform offset shifts the
  feasibility interval without emptying a non-empty one, so it cannot flip a PASS to a
  FAIL — but it can change *which* origins are feasible, and it matters if the rule ever
  reports the interval to a human as advice.
  confidence: 2
  disposition:
  rationale:

- **IW-2: how many currently-clean corpus maps fail the stricter check?** Ordered
  non-overlapping spans are necessary for feasibility but not sufficient, so this rule is
  a superset of `lane-geometry`. The survey is cheap (11 maps) and decides whether this is
  a drop-in tightening or a re-baselining exercise with its own repair backlog.
  confidence: 1
  disposition:
  rationale:

- **IW-3: does feasibility replace `lane-geometry` or sit beside it?** They report
  different things: `lane-geometry` names an extremal witness *pair* of nodes (actionable —
  it is what resolved v8 to exactly two nodes), while feasibility yields an *interval* and
  no witness. Strictly stronger detection with strictly weaker diagnostics is a real
  trade-off, not an obvious upgrade.
  confidence: 2
  disposition:
  rationale:

- **IW-4: is a lane-height defect distinguishable from a node-placement defect?** An empty
  interval says the declaration is unsatisfiable but not *why* — a wrong
  `aef:laneMeta height` and a mis-placed node produce the same emptiness. If the rule
  cannot separate them it will point authors at the wrong fix, which is worse than the
  ordering rule's narrower but correctly-aimed finding.
  confidence: 1
  disposition:
  rationale:

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

**Recommendation:** GO

**Rationale:** The check is already written and already earned its keep: it produced the only proof-grade evidence in T-2686 (an EMPTY origin interval proves no band origin can satisfy the declaration, versus the shipped ordering rule which is merely necessary). It currently lives in tests/unit/test_t2686_laneset_order.py where only two maps benefit. GO rather than DEFER because the evidence is complete — what remains is two bounded design calls, not missing knowledge. 832 was invited to mirror it at rail 336, so the cross-project shape is already in motion.

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

### 2026-07-29T22:01:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
