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

status: work-completed
workflow_type: inception
owner: agent
horizon: null
arc_id: designer-corpus
tags: [designer, corpus, t2619-slice]
components: [C-004, agents/designer/designer.sh, agents/task-create/update-task.sh, tests/web/test_api_version_latest.py, tools/corpus_explain.py, tools/corpus_lint.py, web/blueprints/designer_api.py, web/blueprints/designer.py, web/templates/designer_landing.html, web/templates/inception_detail.html, web/templates/review.html]
related_tasks: [T-2619]
created: 2026-07-25T16:41:52Z
last_update: 2026-07-27T17:54:31Z
date_finished: 2026-07-27T17:54:31Z
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
  - ts: '2026-07-27T16:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
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

The corpus maps are static pictures; the operator's TROUBLESHOOT goal ("where is T-XXXX stuck" as a picture) needs live framework state projected onto them. For the operator, now, because the conformance rail (T-2621) just made aef-task-lifecycle a trustworthy substrate and the state-carrier annotations give every status a home node.

## Assumptions

- A1 (validated live): node uids survive operator editing — pair-draft round 2 proved all 19 uids preserved through a real layout pass in 832's editor.
- A2 (validated by spike): the projection from task frontmatter to carrier uids is computable sub-second from flat files, no index needed (0.49s over 265 active + 53 windowed completed).
- A3 (validated by 832 rail 197, ratification pending): the bundle can accept external annotations without forking — postMessage + re-ready/re-annotate contract.

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
  disposition: dissolved
  rationale: Superseded at shape level by 832's rail-197 advisory answer — postMessage lean, with the load-bearing contract that renderAll() rebuilds the SVG DOM so the bundle re-emits aef:ready after EVERY render and we re-send aef:annotate each time; their T-250 (inception, operator-gated) tracks it, T-246 MANIFEST capabilities flag rides along. Iframe DOM-reach fallback mutually parked as the coupling to avoid. v0 plans against the postMessage contract; build waits on their operator ratification.

- **IW-4: Where does the live-state feed come from — one Watchtower endpoint aggregating .tasks/active + focus.yaml + dispatches.jsonl keyed by map uid, or per-source fetches in the wrapper?**
  confidence: 3
  disposition: answered
  rationale: Single endpoint, spike-proven 2026-07-27 (docs/reports/T-2620-live-state-overlay-seam.md §IW-4). Projection is NOT a pure status join — needs frontmatter × horizon × active-vs-completed × focus.yaml crossed (e.g. tl_human_review = work-completed still in active/); those rules must live in one place server-side. Endpoint emits the wire-ready aef:annotate payload verbatim; wrapper forwards on every aef:ready. Live run: 0.49s cold, tl_human_review badge 183/alert (oldest 46d) — the first render already IS the troubleshoot insight.

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

**IN:** seam shape (where the overlay lives), feed shape (endpoint contract + projection rules), trigger model design notes, pair-drafting the trigger-handling workflow. **OUT:** building the overlay (post-GO build slices), any edit to the pinned bundle or /opt/832, individual-task drill-down pages (operator rule: task data is observation layer, never a navigation destination), trigger landing-surface implementation (operator decision pending).

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
- Seam shape settled with 832 at contract level (no bundle fork, no /opt/832 coupling)
- Feed computable from existing flat files at interactive cost (<2s) with projection rules in one place
- Content model honours the operator's observation-layer rule (no task-page drill-down)

**NO-GO if:**
- Annotation requires forking the pinned bundle or per-release re-integration work
- Projection needs new state capture (schema changes to task files / dispatch log)
- Overlay duplicates Watchtower task-list surfaces instead of process-level aggregates

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

**Rationale:** All four IW questions disposed with evidence (the original DEFER's three gaps each closed: T-2619 decided GO; 832 answered the seam question at rail 197 with a postMessage contract that needs no bundle fork; the feed spike ran live). Build is scoped, testable, reversible, and cleanly sliceable so the one external dependency (832's T-250 operator ratification) blocks only the slice that touches their contract:

- **Slice A — `/api/overlay?id=<map-id>` endpoint** (no external dep, curl-testable): productionize the spike's projection rules (frontmatter × horizon × active-vs-completed × focus.yaml → carrier uids, stuck-age severity) emitting the wire-ready `aef:annotate` payload.
- **Slice B — overlay wrapper page** (waits on 832 T-250 ratification): iframe the served bundle, forward the payload via postMessage on every `aef:ready`, per the rail-197 re-ready/re-annotate contract.
- **Slice C — trigger landing surface** (waits on operator decision: obs inbox vs /approvals vs overlay panel; drafted as a decision node in draft-trigger-handling).

**Evidence:**
- Research artifact: `docs/reports/T-2620-live-state-overlay-seam.md` (dialogue rounds 1-3, 832 rail-197 contract, IW-4 spike section)
- Live spike output: 0.49s cold; `tl_human_review` badge 183/alert (176 stuck >7d, oldest 46d) — first render already answers "where is work stuck"
- uid identity contract proven under real operator editing (pair-draft round 2: 19/19 uids survived)
- Conformance rail (T-2621) live on the target map; state-carrier mapping is the projection key
- 832 status pinged rail 210; their constraints (read-only presentation, unknown-uid tolerance, never serialized) all honoured by the slice design

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

**Rationale**: All four IW questions disposed with evidence (the original DEFER's three gaps each closed: T-2619 decided GO; 832 answered the seam question at rail 197 with a postMessage contract that needs no bundle fork; the feed spike ran live). Build is scoped, testable, reversible, and cleanly sliceable so the one external dependency (832's T-250 operator ratification) blocks only the slice that touches their contract:

**Date**: 2026-07-27T17:54:30Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-07-25T17:15:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-07-27T17:54:30Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** All four IW questions disposed with evidence (the original DEFER's three gaps each closed: T-2619 decided GO; 832 answered the seam question at rail 197 with a postMessage contract that needs no bundle fork; the feed spike ran live). Build is scoped, testable, reversible, and cleanly sliceable so the one external dependency (832's T-250 operator ratification) blocks only the slice that touches their contract:

## Reviewer Verdict (v1.5)

- **Scan ID:** R-29d1547d
- **Timestamp:** 2026-07-27T17:54:32Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-1752e56b
- **Timestamp:** 2026-07-27T17:54:32Z
- **Overall:** CONFIRMED
- **Claims:** 4

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/T-2620-live-state-overlay-seam.md` | file | ✓ pass |
| `T-2619` | task | ✓ pass |
| `T-250` | task | ✓ pass |
| `T-2621` | task | ✓ pass |

### 2026-07-27T17:54:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
