---
id: T-3482
name: "BVP revamp inception: remove the human from score confirmation and from arc
  value-driver approval, auto-apply both, and instrument the feedback loop that lets
  scoring and driver generation be refined from measured outcomes"
description: >
  Inception: BVP revamp inception: remove the human from score confirmation and from
  arc value-driver approval, auto-apply both, and instrument the feedback loop that
  lets scoring and driver generation be refined from measured outcomes

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-09-25T21:30:13Z
last_update: 2026-09-25T21:56:31Z
date_finished: 2026-09-25T21:56:31Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-09-25T21:44:28Z'
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
  - ts: '2026-09-25T21:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=123,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3482: BVP revamp inception: remove the human from score confirmation and from arc value-driver approval, auto-apply both, and instrument the feedback loop that lets scoring and driver generation be refined from measured outcomes

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Telemetry first, or auto-apply first?**
  confidence: 2
  disposition: deferred
  rationale: SOVEREIGN — sequencing is the operator's. My recommendation is telemetry first: round 3 measured the v1 heuristic collapsing 39 tasks into two score patterns because it reads phrasing, so auto-applying it today would industrialise a scorer already proven flat. Auto-apply with no feedback loop removes the only judgment that could notice — and note it did NOT notice: the flatness was found by a worker running the estimator, not by a human confirming scores.

- **IW-2: What is the ground truth the feedback loop scores AGAINST?**
  confidence: 1
  disposition: deferred
  rationale: The hard one, and the whole revamp rests on it. A loop that refines scoring needs a signal for "was this score right". Candidates present in the corpus: did the task actually get worked; did its cost_estimate match measured cost at close; did the operator override the rank by picking something else. None is clean — the third is the most honest (revealed preference) but is exactly the human signal being removed elsewhere. Without an answer here the telemetry measures activity, not accuracy.

- **IW-3: What replaces the confirmation gate as the safety net?**
  confidence: 2
  disposition: deferred
  rationale: `lib/bvp.sh:799` documents confirmation as a sovereignty boundary (F7/D8). Removing it is an operator ruling, recorded as such. But a boundary removed without a replacement control is a silent-failure surface, which D2 forbids. Candidate: an audit rail that WARNs when a scorer's output is degenerate across a task family (low variance = the scorer is not discriminating), which is precisely the condition round 3 found by hand.

- **IW-4: Does removing the human from `--none` change the driver cap's meaning?**
  confidence: 2
  disposition: deferred
  rationale: D-586/T-3429 already made driver ADDITION default-on and reviewer-gated, deliberately keeping the negative ruling (`--none`, "this arc has no scoped drivers worth tracking") human, because a negative is sovereign. Auto-applying both directions means the M2 cap of 3 becomes the only brake on driver inflation — the failure mode the workflow's own R5 names: *"Manufacturing drivers to look thorough is worse than proposing zero."*

- **IW-5: Is the reviewer (T-3429) strong enough to be the sole gate on auto-created drivers?**
  confidence: 2
  disposition: deferred
  rationale: Its three checks are scorable / distinct / distinguishes-a-directive. Check (a) refuses a driver with no scoring spec, which is the common failure. But none of the three asks whether the driver DISCRIMINATES in practice — the same blind spot the v1 task scorer has. An auto-created driver that passes review and then scores flat is the arc-level version of IW-2.

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

**Rationale:**

Operator ruling 2026-09-25: take the human out of the loop for BVP scoring and for arc value-driver creation; create and apply drivers automatically; add telemetry so we get a feedback loop to refine driver creation and scoring. Round 3 supplied the evidence that forces this: the v1 heuristic collapses an entire 39-task backlog into two near-identical score patterns because it reads phrasing, so scoring currently cannot discriminate and selection stalls. The sovereignty boundary being removed is real (F7/D8, lib/bvp.sh:799) and its removal must be recorded as a deliberate operator ruling, not drift.

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

**Rationale**: Operator ruling 2026-09-25: take the human out of the loop for BVP scoring and for arc value-driver creation; create and apply drivers automatically; add telemetry so we get a feedback loop to refine driver creation and scoring. Round 3 supplied the evidence that forces this: the v1 heuristic collapses an entire 39-task backlog into two near-identical score patterns because it reads phrasing, so scoring currently cannot discriminate and selection stalls. The sovereignty boundary being removed is real (F7/D8, lib/bvp.sh:799) and its removal must be recorded as a deliberate operator ruling, not drift.

**Date**: 2026-09-25T21:56:30Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-09-25T21:44:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-09-25T21:56:30Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Operator ruling 2026-09-25: take the human out of the loop for BVP scoring and for arc value-driver creation; create and apply drivers automatically; add telemetry so we get a feedback loop to refine driver creation and scoring. Round 3 supplied the evidence that forces this: the v1 heuristic collapses an entire 39-task backlog into two near-identical score patterns because it reads phrasing, so scoring currently cannot discriminate and selection stalls. The sovereignty boundary being removed is real (F7/D8, lib/bvp.sh:799) and its removal must be recorded as a deliberate operator ruling, not drift.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-37153146
- **Timestamp:** 2026-09-25T21:56:32Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-9534e60c
- **Timestamp:** 2026-09-25T21:56:32Z
- **Overall:** UNVERIFIED
- **Claims:** 0
- No verifiable claims found in ## Recommendation

### 2026-09-25T21:56:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
