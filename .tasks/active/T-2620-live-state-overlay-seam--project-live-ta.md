---
id: T-2620
name: "Live-state overlay seam — project live task/dispatch state onto map uids"
description: >
  Explore the minimal seam to project live framework state (.tasks/active statuses,
  focus.yaml, dispatches.jsonl) onto served designer maps, keyed by node uid (DOM
  g[data-id]). One question: where does the overlay live — Watchtower-side wrapper
  around the gallery, 832-side designer feature (seam negotiation), or postMessage
  bridge? Serves the TROUBLESHOOT goal: 'where is T-XXXX stuck' as a picture. Dependency:
  T-2619 authority-model GO.

status: started-work
workflow_type: inception
owner: agent
horizon: now
arc_id: designer-corpus
tags: [designer, corpus, t2619-slice]
components: []
related_tasks: [T-2619]
created: 2026-07-25T16:41:52Z
last_update: 2026-07-26T19:58:21Z
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
  - ts: '2026-07-25T16:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-25T16:45:08Z'
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

# T-2620: Live-state overlay seam — project live task/dispatch state onto map uids

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

- **IW-1: What live state does the operator want on the maps FIRST — task statuses on aef-task-lifecycle, dispatch outcomes on aef-dispatch-loop, or gate-refusal events?**
  confidence: 2
  disposition: answered
  rationale: Operator 2026-07-25 rounds 2-3 — settled. Headline = PROCESS-level state (WIP concentration per stage, gate-friction hotspots). Round-3 refinement: drill-down descends to GENERALIZED sub-workflows (subProcess expansion / linked maps via T-2613 handoff jumps — cascading detail levels WITHIN the map hierarchy), NEVER to individual task pages. Individual task data is the OBSERVATION layer only: it feeds the aggregates and fires TRIGGERS when thresholds breach (task stuck N days at a stage, gate refused M times) — triggers surface as actionable signals (fw note obs / inbox / approvals — landing surface TBD in this inception), not as navigation targets. Duplicating Watchtower's task list is explicitly off-purpose.

- **IW-2: Wrapper-only v0 (same-origin iframe + external annotation, no 832 change) or ask 832 for a designer-side annotation hook first?**
  confidence: 3
  disposition: answered
  rationale: Operator 2026-07-25 — "ask 832 first". Proposal posted at rail offset 196 (two candidate shapes: postMessage protocol w/ aef:ready, or window.AefDesigner API; fallback wrapper stated honestly; T-246 MANIFEST capabilities flag suggested for advertising). Awaiting 832 shape-level ack/counter.

- **IW-3: Does same-origin iframe DOM-reach actually work live against the served 0.4.0 bundle, incl. after its ?load= rendering completes?**
  confidence: 4
  disposition:
  rationale: Superseded at shape level by 832's rail-197 advisory answer — postMessage lean, with the load-bearing contract that renderAll() rebuilds the SVG DOM so the bundle re-emits aef:ready after EVERY render and we re-send aef:annotate each time; their T-250 (inception, operator-gated) tracks it, T-246 MANIFEST capabilities flag rides along. Iframe DOM-reach fallback mutually parked as the coupling to avoid. v0 plans against the postMessage contract; build waits on their operator ratification.

- **IW-4: Where does the live-state feed come from — one Watchtower endpoint aggregating .tasks/active + focus.yaml + dispatches.jsonl keyed by map uid, or per-source fetches in the wrapper?**
  confidence: 1
  disposition:
  rationale: Single aggregation endpoint likely cleaner (one contract, cacheable); needs a look at existing Watchtower blueprints before deciding.

## Exploration Plan

1. Operator dialogue: IW-1 (which state first) + IW-2 (wrapper v0 vs 832 hook, rail-ask wording) — DONE 2026-07-25 (rounds 1-3; see rationales).
2. Live spike (30 min): wrapper page iframes /designer/app?load=<task-lifecycle> and annotates one g[data-id] node post-render — IW-3. (May be superseded if 832 accepts the annotation-hook proposal, rail 196.)
3. Feed-shape look (30 min): existing Watchtower blueprints + gallery API → aggregation endpoint sketch — IW-4.
4. Rail: 832 answer to annotation-seam proposal (posted offset 196) — capture here; hook shape vs wrapper fallback decides the v0 architecture.
5. Design note before decide: trigger model — which threshold breaches (stuck-N-days, gate-refused-M-times) fire, and where the actionable signal lands (fw note obs / inbox / approvals). Operator round-3 steer: task data = observations/triggers to be actioned, never drill-down targets.
6. Design note before decide: drill-down = subProcess expansion + T-2613 cross-map handoff jumps (generalized sub-workflows), aligning with the cascading-detail architecture from T-2619 round-2 (item 4).
7. Decide via fw task review T-2620.

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

**Rationale:** Genuine evidence gaps: (1) depends on T-2619 authority-model decision; (2) seam placement needs 832 consultation on the rail — designer is their artifact, overlay may need a designer-side hook or may be pure Watchtower wrapper; (3) no spike yet on whether served-bundle DOM can be annotated without forking the pinned artifact. DEFER until T-2619 decides and 832 answers seam question.

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

### 2026-07-25T17:15:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
