---
id: T-5318
name: "wc v0.3.4 item 2 (optional dispatch closure): adopt TermLink's six amendments
  (A1-A6) so all three owners can adopt the item?"
description: >
  Inception: wc v0.3.4 item 2 (optional dispatch closure): adopt TermLink's six amendments
  (A1-A6) so all three owners can adopt the item?

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
waiting_on: agent
revisit_at: 2026-11-27
created: 2026-11-20T18:00:32Z
last_update: '2026-11-20T18:15:41Z'
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
  - ts: '2026-11-20T18:01:07Z'
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
  - ts: '2026-11-20T18:15:41Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=127,acs=4)
    rubric_sha: e4a00f38e801
---

# T-5318: wc v0.3.4 item 2 (optional dispatch closure): adopt TermLink's six amendments (A1-A6) so all three owners can adopt the item?

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Does ring20 (the source of item 2, whose poold closes dispatches) accept TermLink's amendments A1-A6, or need changes?**
  confidence: 3
  disposition: answered
  rationale: ring20 msg 0e5516a8: adopt with A1-A6; their closing backend is orch-supervisor (poold never closes); three small changes on their side (A2 late completion, A4 policy id, A5 retry link) plus the A6 response shape
- **IW-2: What were the six weaknesses TermLink's two reviewers found (the reasons, not only the amendments)?** (asked 010, msg cb77d7c4)
  confidence: 3
  disposition: answered
  rationale: 010 msg c2d29013: W1-W6 (five high, one medium), found independently by two reviewers; A1-A6 answer them in order; docs/reports/T-5318-dispatch-closure-amendments.md
- **IW-3: What does AEF's own backend (lib/dispatch_records.py) need to change: declare closure never or supported, and the cost of each?**
  confidence: 3
  disposition: answered
  rationale: lib/dispatch_records.py:19 keeps dispatches open, so AEF declares closure: never; cost is a typed refusal of close and tolerating the new fence reason

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

Adopt v0.3.4 item 2 (optional dispatch closure) with TermLink's amendments A1-A6, and with it items 1 and 3, so all three owners adopt the same v0.3.4. Two independent reviewers on TermLink's side found the same six weaknesses in item 2 as drafted (W1-W6: five high), each a way three backends could disagree or a caller could block someone else's retries; each amendment is the smallest fix for one. ring20, whose orchestrator is the only backend that closes, accepts all six with three small changes on its side. For AEF the cost is small: our backend never closes dispatches, so it declares `closure: never` and answers a close with a typed refusal. Build after a GO: write A1-A6 and vectors CC-30..CC-43 (CC-15a/b, CC-19a/b) into the spec, then AEF's typed refusal.

**Evidence:**

- TermLink operator rulings (010 msg e9015b84): items 1 and 3 adopted; item 2 only with A1-A6.
- The six weaknesses, found independently by two reviewers (010 msg c2d29013); docs/reports/T-5318-dispatch-closure-amendments.md.
- ring20: adopt with A1-A6 (msg 0e5516a8).
- AEF backend: lib/dispatch_records.py:19 keeps dispatches open (closure: never).

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

### 2026-11-20T18:01:03Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
