---
id: T-2670
name: "workflow fabric: queryable cross-map index (package Lock 4 / SD-15)"
description: >
  Should cross-map structure (handoffs, sub-process calls, lane/role participation)
  be indexed into a queryable registry supporting role-level queries (e.g. the operator's
  decision-surface across all maps), per the package's Workflow Fabric spec? Handoffs
  exist as map content (T-2586/T-2613) but nothing is queryable (T-2662 gap 5).

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [process-layer]
components: []
related_tasks: [T-2662]
arc_id: designer-corpus
created: 2026-07-28T16:23:14Z
last_update: 2026-09-19T16:11:06Z
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
  - ts: '2026-07-28T16:30:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-28T16:30:09Z'
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

# T-2670: workflow fabric: queryable cross-map index (package Lock 4 / SD-15)

## Problem Statement

The 2026-07-02 package's Lock 4 / SD-15 specified a Workflow Fabric: cross-map
structure (handoffs, sub-process calls, lane/role participation) indexed into a
queryable registry so role-level questions ("the operator's decision surface
across all maps") can be answered without walking every map. T-2662 found
nothing queryable (gap 5) and routed SD-15 here, with SD-13 (component linkage)
parked "inside T-2670's fabric question". The 2026-07-28 DEFER waited for the
first real cross-map question the gallery could not answer. **Why now:** the
corpus has tripled, cross-map links now exist, two bespoke cross-map scans have
been built, and arc-019 EWCR (operator-ratified 2026-08-20) specifies the
Workflow Fabric as a derived index in §8.3 and builds it in roadmap Arc 4.
Research artefact: `docs/reports/T-2670-workflow-fabric-supersession-review.md`.

## Assumptions

Registered and disposed via `fw assumption` (artefact §4):

- **A-057** — corpus still ~5 maps, walkable by eye → **invalidated** (16 store entries; cross-map markers in 10).
- **A-058** — a concrete operator-level cross-map query need has surfaced → **invalidated** (none filed; two bespoke scans built instead — the need is being met one scan at a time).
- **A-059** — arc-019 owns the Workflow Fabric derived index → **validated** (§8.3; Arc 4 items 4–6; Arc 5 item 3).

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

- **IW-1: Has the DEFER's revisit evidence arrived — has the corpus outgrown "5 maps, walkable by eye", or has a concrete cross-map query need surfaced that the gallery could not answer?**
  confidence: 3
  disposition: answered
  rationale: Scale yes, demand not as specified. `.context/designer/projects/` = 16 entries (8 aef-* + 7 drafts + scratch) vs 5 in July; cross-map markers in 10 maps; no role-level cross-map question filed since 2026-07-28, but two bespoke cross-map scans were built (`corpus_lint` cross-map pass T-2604; `corpus_explain --search` T-2942) — artefact §1.

- **IW-2: Does arc-019 EWCR own the Workflow Fabric derived index (§8.3; roadmap Arc 4 "Workflow Fabric projection", Arc 5 item 3 "derived index and impact query"), such that T-2670 is superseded rather than pending?**
  confidence: 3
  disposition: dissolved
  rationale: Yes. architecture-c9070637.md §8.3 "derived, queryable graph of procedure/step/lane entities and flow, call, handoff, component, context…"; roadmap-5be23719.md Arc 4 items 4 (projection), 5 (Component/Context join = SD-13), 6 (impact queries); Arc 5 item 3; operator GO 2026-08-20 — artefact §2.

- **IW-3: What did SD-1's GO (T-2663) leave SD-15 (Workflow Fabric) as — inherited-retired, parked here, or open?**
  confidence: 3
  disposition: answered
  rationale: Routed here, not inherited: T-2662 §4 "SD-15 Workflow Fabric — routed to T-2670" and "SD-13 — parked, revisit inside T-2670's fabric question"; T-2663's inheritance clause lists SD-3/10/13/14 only. T-2670 is the live holder of SD-15 and SD-13; both now have an arc-019 Arc 4 owner — artefact §3.

## Exploration Plan

Read-only research, no spikes (executed 2026-09-19):

1. Count the designer store and grep cross-map markers; search tasks/inbox/concerns since 2026-07-28 for a filed cross-map query need → IW-1.
2. Read architecture-c9070637.md §8.3 and roadmap-5be23719.md Arc 4 / Arc 5 → IW-2.
3. Read T-2662 §4 SD-13/SD-15 rows and T-2663's inheritance clause → IW-3.
4. Dispose assumptions through `fw assumption validate|invalidate`; write the artefact; recommend; hand the go/no-go to the operator via `fw task review`.

## Technical Constraints

None for the exploration. For the fabric itself, EWCR §8.3 fixes two
constraints the package's Lock 4 did not: the index is **derived, never
hand-maintained**, and its default projection is version-aware
(`ratified-latest` plus versions bound to live instances).

## Scope Fence

**IN:** whether T-2670 should authorise a cross-map registry build under
arc-014; disposition of IW-1..3; what transfers to arc-019 Arc 4 (SD-13, SD-15,
the two bespoke scans). **OUT:** the EWCR architecture's shape; T-2669 (audience
lenses, SD-14 — separate task); building anything.

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
- A cross-map registry is unowned by any ratified programme and a bounded slice under arc-014 could deliver it

**NO-GO if:**
- Authorising build slices here would create a second Workflow Fabric beside one a ratified programme already owns

**DEFER if:**
- The revisit evidence has still not arrived AND no successor owns the question

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

**Recommendation:** NO-GO

**Rationale:** Dissolved by supersession into arc-019 Arc 4. **On this form, GO means "build a cross-map registry under arc-014 now"; NO-GO means "T-2670's question is owned by arc-019 Arc 4 — close as dissolved and carry the transfers".** The DEFER's premise is gone — the store holds 16 entries (8 canonical `aef-*`, 7 substantive drafts) with cross-map markers in 10, not "5 maps walkable by eye" — but the demand it waited for arrived as scale and as two bespoke scans (`corpus_lint` cross-map pass, `corpus_explain --search`), not as a filed role-level question. The decisive fact is newer: EWCR §8.3 specifies the Workflow Fabric as a *derived, queryable graph of procedure/step/lane entities and flow, call, handoff, component, context* relationships that "must not become a third hand-maintained copy", and roadmap Arc 4 items 4–6 build it (projection, Component/Context join = SD-13, impact queries). A GO here would fork that. DEFER is no longer honest: a successor owns the question, and SD-13/SD-15 would stay formally parked in a task whose question has moved.

**Evidence:**
- `docs/reports/T-2670-workflow-fabric-supersession-review.md` — §1 store census and scan table, §2 EWCR §8.3 / Arc 4 mapping, §3 SD-13/SD-15 lineage, §5 criteria evaluation
- Assumptions A-057 invalidated, A-058 invalidated, A-059 validated (`fw assumption list`)
- `.context/designer/projects/` (16 entries); `tools/corpus_lint.py:614 cross_map_typed_events` (T-2604); `tools/corpus_explain.py --search` (T-2942); T-2891 fixture-hole finding
- `docs/research/executable-workflow/architecture-c9070637.md` §8.3, §18; `roadmap-5be23719.md` Arc 4 items 4–6, Arc 5 item 3; T-2662 §4 rows SD-13/SD-15

**Transfers to arc-019 Arc 4 (recorded, not decided):** (1) the two bespoke scans are the seed consumers the derived index must subsume; (2) SD-13 rides with SD-15 — zero `components:` refs on any map is the measured start; (3) corpus growth is the demand signal, arriving as scale.

## Decisions

### 2026-09-19 — recommendation shape
- **Chose:** NO-GO, disposition *dissolved by supersession*, with the GO/NO-GO meanings spelled out on the form.
- **Why:** owned by a ratified programme with a stronger design (derived, version-aware); the sibling T-2668 form was answered GO while carrying a NO-GO rationale, so the verbs' meanings are made explicit here.
- **Rejected:** DEFER (successor exists — hedge per T-2144); GO-as-approval-of-dissolution (would read as authorising a build).

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-09-19T16:11:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-86f94fc5
- **Timestamp:** 2026-09-19T16:16:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-b50ac791
- **Timestamp:** 2026-09-19T16:16:52Z
- **Overall:** CONFIRMED
- **Claims:** 6

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/T-2670-workflow-fabric-supersession-review.md` | file | ✓ pass |
| `docs/research/executable-workflow/architecture-c9070637.md` | file | ✓ pass |
| `T-2604` | task | ✓ pass |
| `T-2942` | task | ✓ pass |
| `T-2891` | task | ✓ pass |
| `T-2662` | task | ✓ pass |
