---
id: T-3496
name: "SOVEREIGN: voi_score is a validated, consumed field that is a constant on 98.6%
  of inceptions — estimate it, retire it, or accept it"
description: >
  SOVEREIGN QUESTION, surfaced not resolved. Measured T-3495: voi_score variance 0.0008
  across 496 inceptions, 489 at exactly 0.5 (the template default), 5 distinct values
  ever used. It is REQUIRED by agents/context/check-inception-schema.py (float 0..1)
  and CONSUMED by lib/govd_envelope.py's min_voi_score breach check -- so a governance
  gate is comparing against a constant and can never discriminate. Three directions,
  each a different kind of decision: (1) ESTIMATE it, giving inceptions a real value-of-information
  signal, which means building a scorer for a judgement nobody has ever made by hand;
  (2) RETIRE it, and with it the min_voi_score breach check, accepting that inceptions
  rank by target_blast_radius alone; (3) ACCEPT it as a deliberate floor, and document
  that the breach check is a schema guard rather than a discriminator. This is an
  architectural/scope call on a governance gate, so the mandate forbids an autonomous
  agent deciding it to keep momentum.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [arc:value-prioritisation]
components: []
related_tasks: []
step_entered_at: '2026-11-19T08:44:57Z'
revisit_at: 2026-11-26
waiting_on: agent
arc_id: value-prioritisation
created: 2026-09-26T00:12:26Z
last_update: 2026-11-19T08:44:57Z
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
  - ts: '2026-09-26T00:15:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=115,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-26T00:15:25Z'
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

# T-3496: SOVEREIGN: voi_score is a validated, consumed field that is a constant on 98.6% of inceptions — estimate it, retire it, or accept it

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

**Reframed by the operator, 2026-11-19 (walkthrough of the ready inceptions):** "if I have 100 inceptions ... and we want to choose between which [inception] we do first, how do we do that? ... What would be helpful for that?" The real problem is not the field but the choice it was meant to support: with 100+ open inceptions (129 today), which is worked first? `voi_score` was the intended answer, but it is a hand-guessed number that nobody ever guessed (610 of 617 at the template's 0.5, re-measured 2026-11-19), so today every inception ranks the same. The agent's first recommendation (retire the field) answered "is this number useful?" and dropped the question behind it. Dialogue and reflection: docs/reports/T-3496-choosing-which-inception-first.md.

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

- **IW-1: Which observable facts tell us what an inception's answer is worth: what it unblocks (build tasks, peers, other inceptions waiting on it), who is waiting and since when, whether something is broken or stuck until it is answered, and what it touches? Which of these can be read from the corpus today, and how often are they present?**
- **IW-2: What does finishing it cost: how close is it to a decision (questions disposed out of filed), and how much exploration is left?**
- **IW-3: How do value and cost combine into one explainable order that shows its reasons per inception (a derived value of information, not a guessed number), and where does the agent's own judgement enter, with a written reason?**
- **IW-4: How does the order learn: record which inception the operator actually takes first and why, compare it with the computed order, and adjust the weights from the difference?**

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

**Recommendation:** EXPLORING

**Rationale:** Reopened 2026-11-19 after the operator reframed the question (see Problem Statement): the work is to find what makes "which inception first" decidable, IW-1..IW-4. Waiting on: agent.

Earlier recommendation (2026-09), kept for the record: DEFER. Genuine evidence gap, not a confidence hedge: the three directions differ in what they assume about whether value-of-information is estimable at all, and no evidence in the corpus settles that -- 489 of 496 identical scores means nobody has ever tried to make the judgement, so there is no signal to learn from either way. An agent choosing here would be deciding what the framework believes about its own prioritisation, which is sovereign.

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

### 2026-09-26T00:13:11Z — status-update [task-update-agent]
- **Change:** tags: +arc:value-prioritisation

### 2026-11-18T22:21:40Z — inception-wait [inception-lifecycle]
- **Change:** waiting_on: agent → operator
- **Revisit:** 2026-11-25

### 2026-11-19T08:43:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-11-19T08:44:57Z — inception-wait [inception-lifecycle]
- **Change:** waiting_on: operator → agent
- **Revisit:** 2026-11-26
