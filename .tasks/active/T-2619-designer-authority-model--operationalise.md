---
id: T-2619
name: "Designer authority model — operationalise as live mirror"
description: >
  Inception: Designer authority model — operationalise as live mirror

status: started-work
workflow_type: inception
owner: human
horizon: now
arc_id: designer-corpus
tags: [designer, corpus, authority-model]
components: []
related_tasks: [T-2618, T-2617, T-2616]
created: 2026-07-25T16:40:48Z
last_update: '2026-07-25T16:45:05Z'
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
  - ts: '2026-07-25T16:42:45Z'
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
  - ts: '2026-07-25T16:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2619: Designer authority model — operationalise as live mirror

## Problem Statement

The designer corpus (5 AEF maps: task-lifecycle v4, dispatch-loop v3, inception-flow v4, session-lifecycle v3, audit-cron v3) was built to be "a supporting tool for agent and operator to build, develop, maintain, troubleshoot, iterate functionality and features" (operator, 2026-07-25). A critical review against those goals found the maps are currently **documentation-only** while carrying the infrastructure cost of an operational tool:

- **Troubleshoot: unserved.** No live state on maps — designer renders static diagrams, Watchtower holds live state, they are not joined. Neither agent nor operator opens /designer during real troubleshooting.
- **Maintain: double maintenance.** Maps document code, synced by hand. Corpus-internal drift is defended (lint, prove, uuid permanence) but map-vs-reality divergence is undetected.
- **Consult: agents never read the maps.** CLAUDE.md remains sole workflow authority; corpus risks becoming a second, drifting source of truth that nothing reads.
- **Iterate: heavy.** Each map version is a full task with e2e ceremony; no draft mode.
- **Plumbing:use ratio ~80:20.** Supply chain (pull-at-tag, round-trip determinism) is excellent; operational pull is mostly hypothetical.

The unresolved keystone question: **which direction does authority flow between map and reality?** Three coherent futures: (1) map-as-spec (reality must conform, audited), (2) map-as-live-mirror (live state projected onto map uids), (3) map-as-docs (accept documentation, optimise read-value, stop investing in heavier machinery). We are implicitly doing 3 while paying for 1+2.

This inception decides the authority model and, on GO, authorises the constituent slices filed alongside it: T-2620 (live-state overlay seam, inception), T-2621 (map-conformance audit leg), plus retrieval / draft-mode / read-value-wiring build slices.

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

- **IW-1: Which authority direction do we commit to — map-as-spec, map-as-live-mirror, map-as-docs, or a scoped hybrid?**
  confidence: 2
  disposition:
  rationale: Review recommends mirror-first + selective spec (task-lifecycle only); operator has not yet weighed in on the trade.

- **IW-2: Does the operator actually pull on the maps today, and for what?**
  confidence: 0
  disposition:
  rationale: Agent-side behavioral evidence only (agent greps code, never opens /designer); operator usage pattern unknown — direct question in review dialogue.

- **IW-3: Can live state be projected onto the served 0.4.0 bundle without forking the pinned artifact?**
  confidence: 2
  disposition: answered
  rationale: Spike 2026-07-25 — bundle has ZERO postMessage hooks (grep=0), so no in-bundle extension point; but serving is same-origin (bundle + APIs both under Watchtower), so a wrapper page can iframe /designer/app?load=... and reach contentDocument to annotate g[data-id] nodes externally. No fork of pinned bytes, no 832 change needed for v0; a designer-side hook stays the cleaner long-term ask (rail question, T-2620). Not yet live-tested — that's T-2620's first act.

- **IW-4: Is task-lifecycle the right (only) map for spec-conformance, i.e. is the update-task.sh transition table mechanically derivable and comparable to map edges?**
  confidence: 3
  disposition: answered
  rationale: Spike 2026-07-25 — transition table is CENTRALIZED in lib/enums.sh:68-77 (VALID_TRANSITIONS, 8 pairs, YAML-loadable with inline fallback) and update-task.sh:1303 validates via is_valid_transition; fw corpus derive aef-task-lifecycle emits machine-readable uuid-stable nodes/edges. Comparison is fully mechanical → T-2621 is small and well-bounded. Other maps lack a single enforcement point — conformance stays task-lifecycle-only.

- **IW-5: Does making the corpus an agent read-surface (fw corpus explain / ask index) create a conflicting second source of truth vs CLAUDE.md, or can precedence be declared cleanly?**
  confidence: 1
  disposition:
  rationale: CLAUDE.md instruction-precedence section exists as a model; corpus could be declared descriptive-subordinate until conformance rails (T-2621) mature — untested.

## Exploration Plan

1. **Dialogue (primary, in progress):** operator + agent review of goals vs current state — critical review delivered 2026-07-25, captured in research artifact `docs/reports/T-2619-designer-authority-model.md` with Dialogue Log (C-001/C-002). Resolves IW-1, IW-2. Time-box: 1-2 exchanges.
2. **Overlay feasibility spike (30 min, feeds IW-3 / T-2620):** confirm the served bundle's uid-keyed DOM can be annotated externally (query gallery API, inject a class onto one g[data-id] from a Watchtower-side snippet) without touching pinned bytes. Read-only against served page.
3. **Conformance derivability check (30 min, feeds IW-4 / T-2621):** derive edge list from aef-task-lifecycle spec via fw corpus derive; extract transition table from update-task.sh; hand-compare once to size the audit leg.
4. **Decision:** fw task review T-2619 → operator go/no-go on the authority model; on GO, promote T-2620/T-2621 horizons and file remaining slices' details.

## Technical Constraints

- Pinned artifact is read-only (T-559 frozen bytes; pull-at-tag contract) — any overlay must be external to the bundle (wrapper page, JS injection at serve time, or a negotiated 832-side hook). Forking the bundle is out.
- Designer is 832's artifact — designer-side changes route through the rail proposal loop, not our edits.
- Watchtower port is per-project (triple-file resolution, never hard-code :3000).

## Scope Fence

**IN:** the authority-model decision; feasibility evidence for overlay + conformance; filing/sequencing the constituent slices under arc-014.
**OUT:** building the overlay (T-2620 on its own GO), building the audit leg (T-2621), any designer-side (832) implementation, retrieval/draft-mode/read-value slices (filed as backlog, built only after this GO), corpus content changes to the 5 maps.

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
- Operator confirms the operational-tool goal (vs accepting documentation-only) — IW-1/IW-2
- Overlay spike shows external annotation of served maps is feasible without forking pinned bytes — IW-3
- Conformance comparison for task-lifecycle is bounded (single enforcement point, derivable edge list) — IW-4

**NO-GO if:**
- Operator values the maps primarily as onboarding/contract docs (then: stop heavier machinery, keep read-value wiring only)
- Overlay requires forking the pinned artifact or a heavy 832-side rebuild
- Map-vs-code conformance proves undecidable (no single enforcement point even for task-lifecycle)

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

Critical review (2026-07-25 dialogue): 5 corpus maps are documentation-only — troubleshoot goal unserved (no live state on maps), maintain = double maintenance (no map-vs-reality divergence detection), agents never consult maps (CLAUDE.md stays sole authority). Substrate (uuid permanence, gallery API, DOM data-id=uid) is ready for operationalisation. Recommend GO: mirror-first (live-state overlay) + selective spec-conformance (task-lifecycle only, where transitions are mechanically enforced).

**Evidence:**

- Critical review 2026-07-25 (verb-by-verb scoring + dialogue log): `docs/reports/T-2619-designer-authority-model.md`
- IW-3 spike: overlay feasible without forking pinned bytes — bundle has 0 postMessage hooks but serving is same-origin, so a Watchtower wrapper can iframe + annotate uid-keyed `g[data-id]` nodes externally (no 832 change needed for v0)
- IW-4 spike: conformance is fully mechanical — transition table centralized at `lib/enums.sh:68-77`, enforced at `update-task.sh:1303`; `fw corpus derive aef-task-lifecycle` emits uuid-stable edges to compare against
- Substrate already paid for: uuid permanence, gallery API, cross-map jumps, lane→owner governance semantics — operationalisation reuses it, option-3 (docs-only) wastes it
- Constituent slices filed under arc-014: T-2620 (overlay seam inception, DEFER pending this GO + 832 seam answer), T-2621 (conformance audit), T-2622 (fw corpus explain / retrieval), T-2623 (draft mode), T-2624 (read-value deep links)

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

### 2026-07-25T16:42:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
