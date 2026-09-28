---
id: T-3535
name: "Per-project goals and objectives: a project headline the framework does not
  own, with an optional arc-level goal, a serves_objective mapping, and a Watchtower
  surface"
description: >
  Inception: Per-project goals and objectives: a project headline the framework does
  not own, with an optional arc-level goal, a serves_objective mapping, and a Watchtower
  surface

status: captured
workflow_type: inception
owner: human
horizon: later
tags: []
components: []
related_tasks: []
created: 2026-09-28T13:19:21Z
last_update: 2026-09-28T18:29:24Z
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
  - ts: '2026-09-28T13:20:26Z'
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
  - ts: '2026-09-28T13:30:13Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=148,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3535: Per-project goals and objectives: a project headline the framework does not own, with an optional arc-level goal, a serves_objective mapping, and a Watchtower surface

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: What is authored and what is derived?** Authored intent (headline, goals, objectives, explicit out-of-scope) versus derived progress (which arcs serve which objective, completion ratios, staleness, what shipped, arcs serving nothing). Get this wrong and the page becomes the next stale artefact — the CLAUDE.md 300K threshold sat wrong for months because nothing rendered it beside reality.
  confidence: 2
  disposition:
  rationale:

- **IW-2: Is "feature" a new first-class record, or a VIEW over closed arcs?** `fw arc create` already requires `--headline-mechanic` in the form "<who> does what, observes what user-visible result" — which is feature-shaped by construction. Deriving the feature list from closed arcs' headline mechanics would make it a free consequence of G-062 rather than a fifth thing to maintain.
  confidence: 1
  disposition:
  rationale:

- **IW-3: Does 002 already have a working shape this template should come FROM?** Operator reports it does something like this and is unsure it is maintained. The T-559 project-boundary gate refuses the cross-project read, so this needs the operator to surface it. If 002 has drifted, that drift is evidence about what decays in practice and should shape the design.
  confidence: 0
  disposition:
  rationale:

- **IW-4: Where does this land — fold the surface into arc-007 (Watchtower redesign, in flight) with the data model as build slices, or open a new arc?** Opening a 21st arc against a diagnosis of "20 in progress, 5 stale, nothing can be declined" asks the problem to solve itself.
  confidence: 2
  disposition:
  rationale:

- **IW-5: Is `serves_objective:` optional on arcs, and what does an arc serving NO objective trigger?** Optional matches the operator's ruling on arc goals (mandatory fields get filled to unblock the verb, which is worse than absent because it reads as considered). But an arc declaring nothing AND stale past 30 days is precisely what an audit rail should surface — that pairing is what makes work declinable.
  confidence: 2
  disposition:
  rationale:

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

**Rationale:**

Selection is specified top-down but no objectives artefact exists, so 'anything that does not advance them is not eligible' is unenforceable — visible as 20 concurrent arcs, 5 stale past 30 days, and 325 tasks awaiting review with no basis for declining any of them. The layer's primary job is to make work DECLINABLE, not to help pick it. GO rather than DEFER because the evidence is complete and the alternatives are enumerated; what remains is the authored-vs-derived split and where it lands, which are design decisions, not knowledge gaps. Must be per-project: once vendored, a consumer's objectives are its own, and shipping ours as framework content would be a Directive 4 violation of exactly the consumer-shape conflation class arc-004 exists to kill.

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

### 2026-09-28T13:20:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-09-28T18:29:24Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)
