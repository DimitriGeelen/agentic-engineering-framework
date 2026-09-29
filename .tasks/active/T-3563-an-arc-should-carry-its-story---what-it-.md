---
id: T-3563
name: "an arc should carry its story - what it is, why, research, decisions - not
  only a one-line demo mechanic"
description: >
  Decide what an arc must carry so that it explains itself — its purpose, background,
  research, decisions and their history — and how that is derived from the inception
  context fabric rather than retyped.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: [T-3548, T-3552, T-3553, T-1667, T-1848]
created: 2026-09-29T16:59:10Z
last_update: '2026-09-29T17:00:38Z'
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
  - ts: '2026-09-29T17:00:14Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=112,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-29T17:00:38Z'
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

# T-3563: an arc should carry its story - what it is, why, research, decisions - not only a one-line demo mechanic

## Problem Statement

Operator, 2026-09-29 (verbatim in `docs/reports/T-3563-arc-story.md`): *"there should
be way more emphasis on headline of an ARC that describes what it is, what's the
background, research decisions made, back and forth. All the context fabric that we've
created … often in our inception."*

Measured 2026-09-29 across 20 arcs: 19 have an `anchor_task`; 14 of those anchors are
inceptions with a research report in `docs/reports/`; **1** arc sets `design_doc`;
**1** sets `decision`. The story exists, one hop away, and the arc never surfaces it.
`headline_mechanic` (median 46 words) is written for G-062's demo check (*who does what
→ observes what*), not to explain the arc.

## Assumptions

- **A-1:** the explanatory material mostly already exists in anchor inceptions (research
  artefact, dialogue log, decisions), so the arc can derive its story rather than have it
  retyped.
- **A-2:** a demo-able headline mechanic and an explanatory arc brief are different
  things with different jobs; merging them would weaken the G-062 demo gate.

## Open Questions

- **IW-1: What must an arc carry so that it explains itself?**
  confidence: 3
  disposition: answered
  rationale: Converged structure from three-vendor review (amber x3) plus agent reflection, adopted by operator 2026-09-29 ("I'm fine with it") — headline_mechanic unchanged; purpose, objective+supports, success_criteria, non_goals, context, decisions, open_questions, history, evidence. See docs/reports/T-3563-arc-story.md.

- **IW-2: Is the arc story derived from the inception fabric, written by hand, or both?**
  confidence: 3
  disposition: answered
  rationale: Both, by operator ruling 2026-09-29 segment 2: an agent drafts from the anchor inception (index, don't copy), an independent external panel that never includes the drafter checks it against the sources, and the operator is shown the result non-blocking and may correct it. Replaces the reviewers' "human approval for intent fields".

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

**Rationale:** Operator 2026-09-29: far more emphasis on the arc headline — what it is, background, research, decisions, back-and-forth, the context fabric built in inceptions. Measured: 19 of 20 arcs have an anchor task, 14 anchors are inceptions with a research report in docs/reports, yet only 1 arc links a design_doc and 1 records a decision. The story exists one hop away and the arc never surfaces it. The headline_mechanic (median 46 words) is a demo check, not a description. External review by three vendors requested before design.

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
