---
id: T-5310
name: "Standing risk arc: should AEF revive its unused risk process as a never-closing
  risk arc with a scored risk matrix (likelihood x impact, actor split, 'introduced
  by this change or existing anyway?') and a mitigation task for every medium-or-higher
  risk? (ring20 proposal)"
description: >
  Inception: Standing risk arc: should AEF revive its unused risk process as a never-closing
  risk arc with a scored risk matrix (likelihood x impact, actor split, 'introduced
  by this change or existing anyway?') and a mitigation task for every medium-or-higher
  risk? (ring20 proposal)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
waiting_on: agent
revisit_at: 2026-11-27
created: 2026-11-20T15:50:53Z
last_update: '2026-11-20T16:00:33Z'
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
  - ts: '2026-11-20T15:57:28Z'
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
  - ts: '2026-11-20T16:00:33Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=128,acs=4)
    rubric_sha: e4a00f38e801
---

# T-5310: Standing risk arc: should AEF revive its unused risk process as a never-closing risk arc with a scored risk matrix (likelihood x impact, actor split, 'introduced by this change or existing anyway?') and a mitigation task for every medium-or-higher risk? (ring20 proposal)

## Problem Statement

AEF has a risk type in its concerns register (.context/project/concerns.yaml) but it is not used: 5 risks ever (R-018, R-024, R-032, R-036, R-037), no likelihood/impact score, no rule that a risk gets a mitigation task, against 136 gaps. Risks introduced by changes (new seats, new hooks, new routes) are discussed in task text and forgotten. ring20 (msg a6cdde77, 2026-11-20, relaying the operator) uses a standing arc that never closes plus a matrix per change: description, domain, actor split (own agent or human by accident; outsider on purpose; provider/host; intruder), how to see the door is open, how to see it happening, likelihood 1-5 x impact 1-5 (low 1-5, medium 6-12, high 15-25) unmitigated and mitigated, and "introduced by this change or existing anyway?"; every medium-or-higher risk gets a mitigation task in the arc.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: What exactly is ring20's matrix template and rule set, and how did it work on their option-B review (14 risks)?** (ring20 to send)
- **IW-2: How does it fit what AEF has: the concerns register's risk type, arcs (an arc that never closes), and audit — extend, or replace?**
- **IW-3: When is a matrix required (every change, or changes of a certain kind), and who scores it (agent, reviewer, operator)?**
- **IW-4: How does it reach consumer projects (template, fw verb, audit check), and what is the cost per change?**

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

**Recommendation:** EXPLORING

**Rationale:**

ring20 (msg a6cdde77, 2026-11-20, operator request): they created a standing arc 'risk' (arc-012, never closed) and used a 14-risk matrix for their pool's option B (their T-2794). The operator noted AEF has a risk process that is not actively used: the concerns register supports type: risk, but only 5 risks exist (R-018..R-037), unscored, with no mitigation rule. Question: adopt ring20's method as a framework practice (standing-arc type plus matrix template), for AEF and for consumers.

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

### 2026-11-20T15:57:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
