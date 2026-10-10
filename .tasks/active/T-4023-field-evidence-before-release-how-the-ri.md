---
id: T-4023
name: "Field evidence before release: how the Ring20 estate (running bleeding-edge)
  tells AEF whether each new feature works, per feature class (deterministic / observed
  in use / judged)"
description: >
  Inception: Field evidence before release: how the Ring20 estate (running bleeding-edge)
  tells AEF whether each new feature works, per feature class (deterministic / observed
  in use / judged)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-09T23:58:30Z
last_update: '2026-10-10T00:00:28Z'
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
  - ts: '2026-10-09T23:59:20Z'
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
  - ts: '2026-10-10T00:00:28Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=140,acs=4)
    rubric_sha: e4a00f38e801
---

# T-4023: Field evidence before release: how the Ring20 estate (running bleeding-edge) tells AEF whether each new feature works, per feature class (deterministic / observed in use / judged)

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

- **IW-1: Which projects make up the Ring20 estate testbed, and does each run bleeding-edge pinned to a candidate commit?**
  confidence: 3
  disposition: answered
  rationale: Operator 2026-10-10 chose option C (artifact §Testbed membership proposals): core = AEF, proxmox-ring20-management (its operator: YES), 055, dimitri-mint-dev; extended per change = 832, ring20-dashboard; each pinned to an immutable -be tag+sha.
- **IW-2: Who answers judged checks — the testbed agent, or its operator for human-facing features?**
  confidence: 0
  disposition:
  rationale:
- **IW-3: Does a red or not-exercised feature block the release unless waived, or is it only shown in the release question?**
  confidence: 0
  disposition:
  rationale:
- **IW-4: Is there a minimum soak period, or does the soak end once every feature has its evidence?**
  confidence: 0
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

**Rationale:**

The operator's rule (T-4020, 2026-10-10) requires field evidence before master, and today that evidence arrives only as free-text upgrade reports (ring20 and 055 sent two on 2026-10-10), which say what broke but not whether each new feature worked. A per-feature field check declared at build time, collected from the testbed with one command and shown in the release question, turns the rule into something checkable. GO on that shape in slices; the open questions (testbed members, who answers judged checks, hard gate vs shown-and-asked, soak period) are for the operator and are listed in docs/reports/T-4023-field-evidence-before-release.md.

**Revised after review round 1 (codex GO-WITH-CHANGES; field answers from all five projects asked): GO, reordered.** Build order:
1. Reachability: T-4003 live check, T-4018 mail watch.
2. Release prerequisites:
   - pre-release (-be) tags in lib/release.sh, without --latest;
   - fw update/upgrade to an exact ref (T-3874, T-3735);
   - push gate green after upgrade (T-4019);
   - a rehearsed rollback for tracked and untracked vendored trees.
3. Field checks with symptom signatures and exposure counts.
4. fw field report plus a roll-call.
5. The release table, with revert-and-recandidate on bleeding-edge (never a release branch, never cherry-pick).

Testbed: option C (operator, 2026-10-10).

Recommended defaults for the remaining questions:
- IW-2: the agent answers; the operator answers only human-facing items, at most one batched question per release.
- IW-3: problems / not-exercised / missing evidence BLOCK unless waived per change, and waived is shown apart from verified.
- IW-4: minimum soak of 2 days, ending early only if every change is mature; at most one candidate per week.
- Field reports are automatic and agent-only, addressed to AEF.

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

### 2026-10-09T23:59:20Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
