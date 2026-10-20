---
id: T-4466
name: "Review panels: close a criterion as 'green-degraded' when a rung-5 panel fails
  only on UNAVAILABLE seats and at least two different vendors judged green?"
description: >
  Proposal from proxmox-ring20-management (msg 5c93f4cb, their operator's request
  2026-10-20): when a rung-5 panel cannot complete only because seats are unavailable
  (no seat amber/red) and >=2 DIFFERENT vendors judged green on the same revision,
  close the criterion as green-degraded (recorded as such, visible on the review page)
  instead of falling to the operator or a paid seat; optional per-project opt-out.
  Trigger: a security criterion fell to their operator purely because two spare seats
  were broken (AEF T-4456 antigravity auto-deny, T-4457 opencode provider errors).
  Relates to T-3580 rung enforcement and its spend step-down, and T-3582 (rung-5 panel
  not assemblable). Relaxes a review gate, so it is the operator's decision.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-10-20T12:08:28Z
last_update: 2026-10-20T15:22:58Z
date_finished: 2026-10-20T15:22:58Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-10-20T12:15:28Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=112,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-20T12:16:13Z'
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

# T-4466: Review panels: close a criterion as 'green-degraded' when a rung-5 panel fails only on UNAVAILABLE seats and at least two different vendors judged green?

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

**Rationale:** GO with conditions. Filling a broken seat is not a genuine operator decision, and today it pushed a criterion onto an operator who is not the reviewer. The safety of rung 5 is vendor diversity plus no dissent; two different vendors green with zero amber/red keeps most of that. Conditions: (1) only when every missing seat is UNAVAILABLE with a recorded reason (never a not-evaluated or a dissent); (2) at least 2 distinct vendors green on the same reviewed revision; (3) recorded as green-degraded on the criterion (like the existing STEP-DOWN line) and WARNed by fw audit; (4) never for tier-0-or-bypass, act-in-the-world or sovereignty criteria (those stay human anyway); (5) project opt-out key, default ON; (6) a per-week count of degraded closes surfaced, so a seat that is always broken gets fixed rather than routed around.

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

**Rationale**: GO with conditions. Filling a broken seat is not a genuine operator decision, and today it pushed a criterion onto an operator who is not the reviewer. The safety of rung 5 is vendor diversity plus no dissent; two different vendors green with zero amber/red keeps most of that. Conditions: (1) only when every missing seat is UNAVAILABLE with a recorded reason (never a not-evaluated or a dissent); (2) at least 2 distinct vendors green on the same reviewed revision; (3) recorded as green-degraded on the criterion (like the existing STEP-DOWN line) and WARNed by fw audit; (4) never for tier-0-or-bypass, act-in-the-world or sovereignty criteria (those stay human anyway); (5) project opt-out key, default ON; (6) a per-week count of degraded closes surfaced, so a seat that is always broken gets fixed rather than routed around.

**Date**: 2026-10-20T15:22:51Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-10-20T15:22:51Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** GO with conditions. Filling a broken seat is not a genuine operator decision, and today it pushed a criterion onto an operator who is not the reviewer. The safety of rung 5 is vendor diversity plus no dissent; two different vendors green with zero amber/red keeps most of that. Conditions: (1) only when every missing seat is UNAVAILABLE with a recorded reason (never a not-evaluated or a dissent); (2) at least 2 distinct vendors green on the same reviewed revision; (3) recorded as green-degraded on the criterion (like the existing STEP-DOWN line) and WARNed by fw audit; (4) never for tier-0-or-bypass, act-in-the-world or sovereignty criteria (those stay human anyway); (5) project opt-out key, default ON; (6) a per-week count of degraded closes surfaced, so a seat that is always broken gets fixed rather than routed around.

### 2026-10-20T15:22:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e6896088
- **Timestamp:** 2026-10-20T15:23:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-ca3d9fca
- **Timestamp:** 2026-10-20T15:23:01Z
- **Overall:** UNVERIFIED
- **Claims:** 0
- No verifiable claims found in ## Recommendation

### 2026-10-20T15:22:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
