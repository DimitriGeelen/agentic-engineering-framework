---
id: T-3667
name: "Standing arcs (FW-NNN): never-closing arcs where tasks flow in continuously,
  get scored, park when low-value, and are bundled or mined for patterns — FW-001
  audit findings, FW-002 inception review loop"
description: >
  Inception: Standing arcs (FW-NNN): never-closing arcs where tasks flow in continuously,
  get scored, park when low-value, and are bundled or mined for patterns — FW-001
  audit findings, FW-002 inception review loop

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-01T15:59:37Z
last_update: 2026-10-01T16:00:45Z
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
  - ts: '2026-10-01T16:00:45Z'
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

# T-3667: Standing arcs (FW-NNN): never-closing arcs where tasks flow in continuously, get scored, park when low-value, and are bundled or mined for patterns — FW-001 audit findings, FW-002 inception review loop

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: What is a standing arc's lifecycle?** It needs a `standing` status that never closes, so it is exempt from the §ACD demo/close gate and the stale-arc WARN. What replaces them as health checks: inflow versus outflow, the oldest item's age, the score distribution?
  confidence: 1
  disposition:
  rationale:
- **IW-2: What files into a standing arc automatically (intake)?** Candidates: an audit WARN repeating N days → task in FW-001; an observation-inbox item older than N days; a red test past its baseline expiry (T-3621); an escalated inception → FW-002. What is manual only?
  confidence: 1
  disposition:
  rationale:
- **IW-3: How does it drain, so it never becomes a graveyard?** A periodic sweep (a dispatched worker) that clusters, bundles and extracts learnings/patterns; promotion out when the score rises; an explicit won't-fix close with a reason. What cadence, and what limits on age and count force action?
  confidence: 1
  disposition:
  rationale:
- **IW-4: How does scoring interact?** BVP scoring on intake; low score → park in the standing arc, high → promote to a delivery arc or horizon now. T-3637's "supports nothing AND stale" rail must exempt standing arcs. Which objectives does each one support (FW-001 → O-1/O-3; FW-002 → O-3/O-2)?
  confidence: 1
  disposition:
  rationale:
- **IW-5: Naming and the first set.** Should standing arcs get a distinct FW-NNN id namespace beside arc-NNN? The first set is FW-001 audit findings and FW-002 inception review loop (absorbing arc-008's continuing operator side). Are test reds (the T-3621 baseline) and peer-agent findings (055 backlog) their own standing arcs, or part of FW-001?
  confidence: 1
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

Operator proposal 2026-10-01. Continuous work has no home today: 373 pending observations, ignored audit WARNs, 114 baselined test reds, 055's unread backlog all pile up undrained, because arcs are delivery-shaped (headline, demo gate, stale WARN). A standing arc gives low-value findings a declinable parking place (O-3), turns accumulation into a bundling/pattern signal (Level D), and gives arc-008's continuing operator-side loop a cleaner home (FW-002) than a re-scope. Design choices remain (lifecycle, intake, drain, scoring, health rails), not evidence gaps.

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

### 2026-10-01T16:00:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
