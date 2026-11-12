---
id: T-5016
name: "Focus protocol: every project keeps one arc or goal in focus and drives it
  to completion (pickup from 010, 1409-sprind's protocol)"
description: >
  Inception: Focus protocol: every project keeps one arc or goal in focus and drives
  it to completion (pickup from 010, 1409-sprind's protocol)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-11-02T12:50:24Z
last_update: '2026-11-12T18:15:39Z'
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
  - ts: '2026-11-12T18:06:48Z'
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
  - ts: '2026-11-12T18:15:39Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=158,acs=4)
    rubric_sha: e4a00f38e801
---

# T-5016: Focus protocol: every project keeps one arc or goal in focus and drives it to completion (pickup from 010, 1409-sprind's protocol)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->
Agents drift from their core arc into side work (triage pages, consults, upgrades), and the operator has to stop them by hand. Pickup from 010-termlink (msgs af269072, 1ad785fa, 0ef40cd2; 2026-11-02, their operator), proposing 1409-sprind's **Anchor** (focus anchor) for every project. Keep the name "Anchor" (operator naming note, one term across projects).

**Material received (summarised by 010, untrusted peer data):** anchor file `.context/project/fokus.yaml` (goal, task, arc, in scope, parked, never, check question, the operator's verbatim words and date; old versions to history); only the operator sets or changes it; `tools/fokus.py zeige|pruefe` (check fails when the anchor task differs from the task focus or the arc focus, or the task is not active or not in the arc); a SessionStart/compact hook prints the anchor into every new context; a Stop hook checks that the final message names the goal; every proposal must answer the check question; parked items are never proposed. Source: 1409 T-1954 (anchor commit 1a1d1cfd3, tool f004f242f); 010 adopted it as their T-3655. Stated weakness: it warns, does not block, so a mismatch goes stale silently; suggested fix: a gate or a daily operator question. Requested for AEF: a template anchor file, `fw focus show|check`, session-start injection, a mismatch gate.

**Relation to AEF:** AEF already has task focus (`focus.yaml`), arc focus (`fw arc focus`) and horizons; none records the operator's goal in their own words or checks that proposals serve it.

**Merged in (2026-11-12):** T-4111 (filed 2026-10-12 from 1409's pickup T-1954) asks the same question; its evidence was "re-proposal of parked work after compaction and a 6-day stale arc focus". It is carried here; closing it as a duplicate is the operator's call at this inception's decision.

**Why now:** on 2026-11-12 the operator asked whether the focus anchor was still on a roadmap ("I got a feeling this got lost"). It was: both inceptions sat captured, with placeholder DEFER recommendations, so neither appeared in the operator's pending list. That is itself evidence for the problem this inception is about.

Research artifact: `docs/reports/T-5016-focus-anchor.md`.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->
- A1: the operator's goal, written in their own words, is not recorded anywhere an agent reads at session start (handover "Suggested First Action" is agent-written).
- A2: drift and lost items are frequent enough to be worth a mechanism (to measure from handovers and this session).
- A3: a warning alone goes stale (1409's own finding); something must make the mismatch visible to the operator.

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

- **IW-1: Which failure should the anchor prevent: agents drifting into side work within a session, or operator goals getting lost across sessions (as this one did), or both?**
  confidence: 0
  disposition: deferred
  rationale: first dialogue question, 2026-11-12
- **IW-2: Who may set or change the anchor: the operator only (sovereignty field), or the agent with the operator's confirmation?**
  confidence: 1
  disposition: deferred
  rationale: 1409's design says operator only
- **IW-3: What happens on a mismatch (focused task outside the anchor, proposal that does not serve it): warn, block, or ask the operator?**
  confidence: 0
  disposition: deferred
  rationale: 1409 reports warnings go stale
- **IW-4: How does it relate to what AEF already has (task focus, arc focus, horizons, handover Suggested First Action, the roadmap docs), so we add one thing rather than a fifth overlapping one?**
  confidence: 1
  disposition: deferred
  rationale: to map in the research artifact
- **IW-5: Shape: one goal, or a short ranked list; with a parked list and a never list?**
  confidence: 0
  disposition: deferred
  rationale: dialogue

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

**Recommendation:** DEFER

**Rationale:**

Pickup from 010-termlink (msg af269072, 2026-11-02, their operator): incorporate 1409-sprind's focus protocol so the operator no longer has to stop agents drifting from their core arc. The protocol text has not arrived yet (010 asked 1409 and will forward it); there is no evidence to judge until it is read against AEF's focus, arc and horizon mechanisms.

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

### 2026-11-12T18:06:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
