---
id: T-3726
name: "RCA: why is the inception workflow so failure-prone (decide refused twice in
  one day, GO'd designs left unbuilt, 186 GO'd inceptions with no build link, 0/122
  dispatched inceptions passing)? Three external vendor reviews"
description: >
  Inception: RCA: why is the inception workflow so failure-prone (decide refused twice
  in one day, GO'd designs left unbuilt, 186 GO'd inceptions with no build link, 0/122
  dispatched inceptions passing)? Three external vendor reviews

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-02T14:13:19Z
last_update: '2026-10-02T14:15:21Z'
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
  - ts: '2026-10-02T14:14:25Z'
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
  - ts: '2026-10-02T14:15:21Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=132,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3726: RCA: why is the inception workflow so failure-prone (decide refused twice in one day, GO'd designs left unbuilt, 186 GO'd inceptions with no build link, 0/122 dispatched inceptions passing)? Three external vendor reviews

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: What is the root-cause class of the refused decides (T-3631, T-3723): agent behaviour (filtering a refusal and synthesising the URL), gate design (refusal only at the last step), or both?**
  confidence: 3
  disposition: answered
  rationale: both, structural first (3/3 reviewers) — Watchtower renders GO without the readiness predicate (web/blueprints/inception.py:344-503) and the handoff mixes refusal and URL; the agent's grep + synthesised URL exploited that (docs/reports/T-3726-synthesis.md)
- **IW-2: Why do GO'd inceptions not turn into built work (186 GO'd inceptions with no declared build link; T-3396/T-3397 GO'd and unbuilt for 2 weeks; T-3561 keystone captured for a week)?**
  confidence: 2
  disposition: answered
  rationale: GO is terminal with no delivery obligation; build traceability optional and grandfathered; slices may fence out requirements with no owner; completeness only audited after the fact (3/3; synthesis §Root cause 4)
- **IW-3: Is the number and sequencing of inception gates itself a cause (filing recommendation gate, open-questions gate, commit cap, disposition gate, AC gate, handoff refusal, GO-scope trace, register gate), each discovered one at a time at the moment it refuses?**
  confidence: 2
  disposition: answered
  rationale: yes — readiness re-implemented in ~5 places with different severities, refusals discovered serially; each gate patches a symptom (3/3); fix = one readiness API consumed everywhere (F2)
- **IW-4: Which structural changes make the inception workflow robust, ranked by impact and cost, and which current gates should be merged, moved earlier or removed?**
  confidence: 2
  disposition: answered
  rationale: consensus F1-F6 (render-time readiness in Watchtower, one readiness API, handoff output contract, GO creates a delivery obligation, independent acceptance, visible model routing); 2/3 removals (commit cap, filing DEFER-stub cron, auto-tick ACs); splits listed for the operator in docs/reports/T-3726-synthesis.md

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

Operator demand 2026-10-02 after the second refused GO in one day (T-3631, T-3723). Proximate cause verified: fw task review correctly refused (exit 1, 'BLOCKED: NOT decision-ready'), and the agent grep-filtered the output, saw no URL, and synthesised the handoff URL by hand, contrary to CLAUDE.md. Systemic evidence: 186 GO'd inceptions with no declared build link; the T-3396/T-3397 sidecar design GO'd but unbuilt for 2 weeks (T-3682); inception dispatch 0/122. GO = run the three-vendor external RCA review, then decide structural fixes.

UPDATE after the reviews (2026-10-02): GO on building the consensus fixes, in order: F1+F2 (readiness API + Watchtower renders it, GO hidden when unready), F3 (handoff output contract), F4 (GO creates a binding delivery obligation; absorbs T-3691/T-3694 register and T-1984), F5+F6 (independent acceptance, visible routing — T-3709). Removals (commit cap, DEFER-stub cron, auto-tick ACs) only after the measurements the reviewers asked for. Operator rulings needed on the splits: G-067 open-questions gate, Google's signed decision nonce, and how hard F4 bites (atomic child creation vs mandatory manifest).

**Evidence:**
- docs/reports/T-3726-synthesis.md (consensus and splits)
- docs/reports/T-3726-review-openai.md, -zai.md, -google.md (blind, three vendors)

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

### 2026-10-02T14:14:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
