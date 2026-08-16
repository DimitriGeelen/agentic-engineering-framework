---
id: T-2305
name: "BVP driver batch — propose V_PROMPT_QUALITY + V_CONTEXT_FABRIC + V_COMPONENT_FABRIC
  as 3 global free drivers"
description: >
  Inception: BVP driver batch — propose V_PROMPT_QUALITY + V_CONTEXT_FABRIC + V_COMPONENT_FABRIC
  as 3 global free drivers

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-06-10T09:47:42Z
last_update: '2026-08-16T22:25:01Z'
date_finished: 2026-06-10T10:23:35Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-06-10T09:50:57Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:01Z'
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
  - ts: '2026-06-10T10:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2305: BVP driver batch — propose V_PROMPT_QUALITY + V_CONTEXT_FABRIC + V_COMPONENT_FABRIC as 3 global free drivers

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Does V_PROMPT_QUALITY (w=7) sit at the right tier — level with D2 Reliability — or should it be one tier higher/lower?**
  confidence: 2
  disposition: answered (proposed weight 7; rejected weight 8 with rationale at §3.1)
  rationale: research artefact §3.1 R2 walks the tier reasoning; agent correction during analysis rejected w=8. Operator confirms via decide-go.

- **IW-2: Is the combined "quality / reliability / speed" framing per fabric the right granularity, or do they want separate sub-drivers per dimension?**
  confidence: 2
  disposition: answered (combined; split rejected with D-2 rationale)
  rationale: research artefact §3.2 + §3.3 R1 corrections walk the correlation argument; split would burn 6 of 5 slots for one concept per fabric. Reversibility is **costly** (per D-2) — splitting later requires re-scoring. Operator confirms via decide-go.

- **IW-3: Will V_COMPONENT_FABRIC at w=6 (one tier below V_CONTEXT_FABRIC at w=7) hold under first-use, or does the asymmetric-load-bearing argument need re-litigating?**
  confidence: 1
  disposition: deferred (first-use observation, ~30-60 day window)
  rationale: §3.3 R2 walks asymmetric-load rationale; first-use scoring patterns are the only evidence that resolves this. Tracked in §10 follow-up.

- **IW-4: Does `fw bvp recompute --scope global` verb exist in current CLI, or does the recompute step of the pickup prompt halt at the verb-check?**
  confidence: 1
  disposition: deferred (pre-action verification at pickup time)
  rationale: live-state corrigendum confirmed `fw bvp driver --add` exists but did not verify `recompute`. Pickup prompt §9.1 has the check; pickup halts at recompute step if absent (drivers still land).

- **IW-5: After landing, will arcs with previous `--none` driver decisions (e.g. those that declined arc-scoped drivers because globals "covered the territory") want to re-run `fw bvp driver suggest` given the three new globals shift the picture?**
  confidence: 1
  disposition: deferred (post-deployment observation per arc)
  rationale: §9.3 surfaces this as a recommendation; per-arc operator judgment. Not a blocking question for this inception.


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

Operator-authored design artefact (`docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md`) walks R1 (differentiation), R2 (weight), O1 (edge cases), O2 (scope test), O3 (overlap), O4 (scoring rubric) per driver — all three pass the differentiation discipline and all three score meaningfully across multiple arcs in O2. Live-state corrigendum (added at filing) reconciles "pending-implementation" framing with the shipped reality: `fw bvp driver --add` already exists; `policy/value-drivers.yaml` v3 is in place with F-RECALL + F-ORCH in the free pool (2/5 slots used); **3 slots open** — exact fit for 3 new drivers. No prereq evidence-gap per T-2144 — three IW deferrals (IW-3 weight first-use, IW-4 recompute verb status, IW-5 arc re-suggest) are post-deployment observations, not blocking gaps. Recommendation **GO** on the design; operator confirms via Watchtower decide-go, then framework runs the §8 CLI sequence (or pickup at §9 fires automatically once decided).

**Evidence:**

- Research artefact: `docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md` (full session preserved verbatim + corrigendum + per-section live-state delta notes).
- Live-state check: `bin/fw bvp driver --help` confirms `--add "name" --weight N --rationale "..."` is shipped.
- Free-driver pool state: `policy/value-drivers.yaml` has `F-RECALL` + `F-ORCH` under `free_drivers:` (2 of 5 slots used; 3 slots open).
- Differentiation walk: per driver in research artefact §3.1, §3.2, §3.3 (R1 sections).
- Cross-driver decisions: §4 D-1 (all global), D-2 (combined per fabric), D-3 (filing order), D-4 (bundled recompute).
- Live-state delta marked in §1, §7, §9.1, §10 for trace integrity.

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

**Rationale**: Operator-authored design artefact (`docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md`) walks R1 (differentiation), R2 (weight), O1 (edge cases), O2 (scope test), O3 (overlap), O4 (scoring rubric) per driver — all three pass the differentiation discipline and all three score meaningfully across multiple arcs in O2. Live-state corrigendum (added at filing) reconciles "pending-implementation" framing with the shipped reality: `fw bvp driver --add` already exists; `policy/value-drivers.yaml` v3 is in place with F-RECALL + F-ORCH in the free pool (2/5 slots used); **3 slots open** — exact fit for 3 new drivers. No prereq evidence-gap per T-2144 — three IW deferrals (IW-3 weight first-use, IW-4 recompute verb status, IW-5 arc re-suggest) are post-deployment observations, not blocking gaps. Recommendation **GO** on the design; operator confirms via Watchtower decide-go, then framework runs the §8 CLI sequence (or pickup at §9 fires automatically once decided).

**Date**: 2026-06-10T10:23:35Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-10T09:50:57Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-06-10T10:23:35Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Operator-authored design artefact (`docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md`) walks R1 (differentiation), R2 (weight), O1 (edge cases), O2 (scope test), O3 (overlap), O4 (scoring rubric) per driver — all three pass the differentiation discipline and all three score meaningfully across multiple arcs in O2. Live-state corrigendum (added at filing) reconciles "pending-implementation" framing with the shipped reality: `fw bvp driver --add` already exists; `policy/value-drivers.yaml` v3 is in place with F-RECALL + F-ORCH in the free pool (2/5 slots used); **3 slots open** — exact fit for 3 new drivers. No prereq evidence-gap per T-2144 — three IW deferrals (IW-3 weight first-use, IW-4 recompute verb status, IW-5 arc re-suggest) are post-deployment observations, not blocking gaps. Recommendation **GO** on the design; operator confirms via Watchtower decide-go, then framework runs the §8 CLI sequence (or pickup at §9 fires automatically once decided).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bf140afe
- **Timestamp:** 2026-06-10T10:23:36Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-1
     - evidence: `IW-1 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

### 2026-06-10T10:23:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
