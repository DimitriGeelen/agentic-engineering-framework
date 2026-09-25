---
id: T-3484
name: "BVP value+cost signal design: define what the feedback loop measures, from
  token cost per unit of work to cross-agent adoption as a value signal"
description: >
  Inception: BVP value+cost signal design: define what the feedback loop measures,
  from token cost per unit of work to cross-agent adoption as a value signal

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-09-25T22:04:21Z
last_update: 2026-09-25T22:28:24Z
date_finished: 2026-09-25T22:28:24Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-09-25T22:05:13Z'
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
  - ts: '2026-09-25T22:15:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=157,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3484: BVP value+cost signal design: define what the feedback loop measures, from token cost per unit of work to cross-agent adoption as a value signal

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

Operator input 2026-09-26 (T-3482 GO already recorded) proposed the signals
below. Each is recorded as a question rather than a settled fact, because
several turn out to be partly unavailable and saying so is the point.

- **IW-1: Can cost be attributed to a task or arc from real token usage?**
  confidence: 1
  disposition: deferred
  rationale: YES for dispatched work, NO for parent-session work — measured, and the asymmetry is the finding. `fw costs` reports session-level totals only (177 sessions, 12.6B tokens, no task dimension). But `.context/dispatches.jsonl` carries `task_id` on its rows AND full token accounting on 1107 of 2565 — `input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`. So a dispatched unit of work has real per-task token cost available today, with no new instrumentation. Work done in the parent session does not: its cost smears across a session touching dozens of tasks. Consequence for calibration: an average computed over the dispatched fraction alone is biased toward whatever we happen to dispatch, and CLAUDE.md's own dispatch table shows that is not a random sample (inception 0% pass, refactor 65%).

- **IW-2: Is usage a measurable value signal for framework features?**
  confidence: 2
  disposition: deferred
  rationale: Plausible and partly available — `lib/hook-telemetry.sh` and the verb-invocation surfaces exist. The trap is that a verb nobody calls may be unused OR merely unknown, and those need different responses (retire vs surface). Usage alone cannot tell them apart; it needs pairing with discoverability.

- **IW-3: Do rework volume and operator-correction volume measure value, or something else?**
  confidence: 2
  disposition: deferred
  rationale: Operator's framing: heavy rework and heavy correction lower the realised value. Agreed as a QUALITY signal. The caution is that it measures the *delivery*, not the *idea* — a high-value feature built badly scores the same as a low-value one built badly, and the response to each is opposite (rebuild vs drop). Should be a separate axis rather than folded into value.

- **IW-4: Is cross-agent adoption the strongest available value signal?**
  confidence: 3
  disposition: deferred
  rationale: Operator's suggestion, and it is the best one on the table. 832, 010-termlink and 1409-sprind vendor this framework and choose independently what to adopt. Adoption by a party with no stake in our self-assessment is the only NON-CIRCULAR value evidence available — every other signal is generated by the system that is being judged. Caveat: it lags (peers upgrade on their own cadence; 010-termlink is still on v1.6.29 against our v1.7.120), and absence of adoption is ambiguous between "not valuable" and "not yet upgraded".

- **IW-5: What is the post-implementation revisit, and what triggers it?**
  confidence: 2
  disposition: deferred
  rationale: Operator: after implementing, measure whether it is actually used and used effectively, then review and ask whether it worked. This is the keystone — it is the only proposed signal that closes the loop on a DECISION rather than on a delivery, and the corpus already shows the failure it would catch (arc-020 shipped complete and unused for weeks; 185 GO'd inceptions whose propagation nobody checked). Open: what triggers it, how long after close, and who is asked.

- **IW-6: Does adding operator review at revisit-time reintroduce the human we just removed?**
  confidence: 2
  disposition: deferred
  rationale: T-3482 removes the human from scoring at FILING time. IW-5 adds a human judgment at REVISIT time. That is not a contradiction — it moves the human from predicting value to confirming realised value, which is the judgement a human is actually good at — but it must be stated deliberately, or it will read later as the boundary quietly coming back.

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

T-3482 GO recorded. IW-2 (what ground truth the loop scores against) now has operator input: cost from real token usage; value from usage, rework, operator-correction volume, a post-implementation revisit, and cross-agent adoption by peer projects. This task turns those into measurable definitions and states honestly where attribution does not yet exist.

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

**Rationale**: T-3482 GO recorded. IW-2 (what ground truth the loop scores against) now has operator input: cost from real token usage; value from usage, rework, operator-correction volume, a post-implementation revisit, and cross-agent adoption by peer projects. This task turns those into measurable definitions and states honestly where attribution does not yet exist.

**Date**: 2026-09-25T22:28:23Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-09-25T22:05:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-09-25T22:28:23Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** T-3482 GO recorded. IW-2 (what ground truth the loop scores against) now has operator input: cost from real token usage; value from usage, rework, operator-correction volume, a post-implementation revisit, and cross-agent adoption by peer projects. This task turns those into measurable definitions and states honestly where attribution does not yet exist.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5bbe6696
- **Timestamp:** 2026-09-25T22:28:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-23824136
- **Timestamp:** 2026-09-25T22:28:25Z
- **Overall:** CONFIRMED
- **Claims:** 1

| Claim | Type | Status |
|-------|------|--------|
| `T-3482` | task | ✓ pass |

### 2026-09-25T22:28:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
