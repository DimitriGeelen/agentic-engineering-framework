---
id: T-2669
name: "audience lenses on corpus maps (package P1: functional/logical/technical/pseudocode)"
description: >
  Should corpus maps gain per-audience render lenses (business/functional view, technical
  view, one-way pseudocode) per the package's P1 purpose and SD-14? Nothing delivered
  (T-2662 gap 2); the overlay is a live-state lens, not an audience lens.

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [process-layer]
components: []
related_tasks: [T-2662]
arc_id: designer-corpus
created: 2026-07-28T16:22:35Z
last_update: 2026-09-19T16:17:46Z
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

# T-2669: audience lenses on corpus maps (package P1: functional/logical/technical/pseudocode)

## Problem Statement

The 2026-07-02 package's P1 purpose and SD-14 asked for per-audience render
lenses on corpus maps — business/functional view, technical view, one-way
pseudocode — so a map serves more than the agent that wrote it. T-2662 found
nothing delivered (gap 2: the overlay is a live-state lens, not an audience
lens) and routed SD-14 here with a NO-GO premised on a write-mostly corpus,
revisable once T-2622's retrieval seam showed read-pull or an operator filed a
V8 need. **Why now:** read-pull has appeared (the onboarding curriculum reads
maps for the operator), no V8 need was filed, and arc-019 EWCR
(operator-ratified 2026-08-20) specifies Business/Logical/Technical/Runtime
lenses in §10. Research artefact:
`docs/reports/T-2669-audience-lenses-supersession-review.md`.

## Assumptions

Registered and disposed via `fw assumption` (artefact §4):

- **A-060** — no measurable read-pull; corpus still write-mostly → **invalidated** (curriculum's 10 `fw corpus explain` routes; 11 tasks since 2026-07-28; T-2942).
- **A-061** — a V8 / audience-lens need has been filed → **invalidated** (none).
- **A-062** — arc-019 owns per-audience rendering → **validated** (§10; roadmap Arc 4 items 1, 3).

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

- **IW-1: Has T-2622 (agent retrieval seam) demonstrated read-pull — do agents or operators now read corpus maps during work, measurably?**
  confidence: 3
  disposition: answered
  rationale: Yes — arc-017's onboarding curriculum routes 10 `fw corpus explain` calls from its operator sections (T-2877/T-2941; T-2942 vendored the reader because all 10 were dead in consumers); 11 tasks dated 2026-08/09 reference the reader; the consumer is the operator, reading the prose rendering (artefact §1).

- **IW-2: Has an independent business-view / audience-lens need (V8) been filed since 2026-07-28 — the "operator may override" clause?**
  confidence: 3
  disposition: answered
  rationale: No — grep of tasks/active, tasks/completed, inbox.yaml, concerns.yaml for audience-lens vocabulary dated 2026-08/09 returns only T-2668/T-2669/T-3391 (artefact §2).

- **IW-3: Does any in-flight programme (arc-019 EWCR §10 operator/agent views, arc-014 T-2667 knowledge-leveling, the Workflow Designer) now own per-audience rendering, such that T-2669 is superseded rather than simply not yet justified?**
  confidence: 3
  disposition: dissolved
  rationale: arc-019 does — architecture-c9070637.md §10 "The same procedure should render in distinct lenses: Business / Logical / Technical / Runtime"; roadmap Arc 4 items 1 and 3; operator GO 2026-08-20. Pseudocode lens (SD-14) is not named there and stays retired on its own evidence (artefact §3).

## Exploration Plan

Read-only research, no spikes (executed 2026-09-19):

1. Read T-2622's outcome; count reader references in tasks/episodics since 2026-07-28; read the T-2942 note on the curriculum's `fw corpus explain` routes → IW-1.
2. Grep tasks/inbox/concerns dated 2026-08/09 for audience-lens vocabulary → IW-2.
3. Read architecture-c9070637.md §10 and roadmap Arc 4 → IW-3.
4. Dispose assumptions through `fw assumption validate|invalidate`; write the artefact; recommend; hand the go/no-go to the operator via `fw task review`.

## Technical Constraints

None for the exploration. For lenses themselves: EWCR §10 renders lenses from
the *ratified procedure* and the *ledger projection*, read-only through
Watchtower as an authenticated runner client — a different source of truth from
the designer store the package's P1 assumed.

## Scope Fence

**IN:** whether T-2669 should authorise lens builds under arc-014; disposition of
IW-1..3; what transfers to arc-019 (read-pull finding, SD-14 terminus, T-2622's
seam). **OUT:** the EWCR architecture's shape; T-2667; building anything.

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
- Audience lenses are unowned by any ratified programme and measured read-pull justifies building them under arc-014

**NO-GO if:**
- Building lenses here would duplicate views a ratified programme already specifies

**DEFER if:**
- Read-pull evidence is still absent and no successor owns the question

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

**Rationale:** Dissolved by supersession into arc-019 §10 / Arc 4 — and the July NO-GO's premise is corrected on the record. **On this form, GO means "build P1 lenses under arc-014 now"; NO-GO means "the business/logical/technical lenses are arc-019's; close as dissolved and carry the transfers".** The write-mostly premise no longer holds: the onboarding curriculum (arc-017) routes 10 `fw corpus explain` calls from its operator sections, T-2942 had to vendor the reader because those routes were dead in consumers, and 11 tasks since 2026-07-28 reference the reader — read-pull exists, from the operator, through one prose lens. No V8 need was filed. The decisive fact is ownership: EWCR §10 specifies that "the same procedure should render in distinct lenses: Business / Logical / Technical / Runtime" — P1's triple plus a runtime view — rendered from the ratified procedure and ledger projection, and roadmap Arc 4 builds the projection. A GO here would build the same three lenses over a different source of truth. The pseudocode lens (SD-14) is not in §10 and stays retired on its own evidence.

**Evidence:**
- `docs/reports/T-2669-audience-lenses-supersession-review.md` — §1 read-pull table, §2 demand search, §3 §10 mapping and SD-14 gap, §5 criteria evaluation
- Assumptions A-060 invalidated, A-061 invalidated, A-062 validated (`fw assumption list`)
- `bin/fw:566-572` (T-2942 note on the curriculum's 10 reader routes); T-2877, T-2941; `tools/corpus_explain.py`
- `docs/research/executable-workflow/architecture-c9070637.md` §10, §18; `roadmap-5be23719.md` Arc 4 items 1, 3; T-2662 §4 SD-14 row

**Transfers to arc-019 (recorded, not decided):** (1) the Business lens has a live consumer before it exists — the curriculum's 10 routes are its acceptance fixture; (2) SD-14 pseudocode lens: not in §10, terminus recorded here; (3) T-2622's seam (`fw corpus explain`, corpus in ask/recall) is the read path §10 replaces or wraps — no second reader.

## Decisions

### 2026-09-19 — recommendation shape
- **Chose:** NO-GO, disposition *dissolved by supersession*, with the July premise explicitly corrected and the verbs' meanings spelled out on the form.
- **Why:** ownership is settled by a ratified programme; leaving the old "write-mostly" rationale standing would misstate the record now that read-pull is measured.
- **Rejected:** keeping the July NO-GO unchanged (premise false); GO on the strength of read-pull (right value signal, wrong owner); DEFER (no gap).

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-09-19T16:17:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-67654561
- **Timestamp:** 2026-09-19T16:21:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-15260594
- **Timestamp:** 2026-09-19T16:21:02Z
- **Overall:** CONFIRMED
- **Claims:** 8

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/T-2669-audience-lenses-supersession-review.md` | file | ✓ pass |
| `tools/corpus_explain.py` | file | ✓ pass |
| `docs/research/executable-workflow/architecture-c9070637.md` | file | ✓ pass |
| `T-2942` | task | ✓ pass |
| `T-2877` | task | ✓ pass |
| `T-2941` | task | ✓ pass |
| `T-2662` | task | ✓ pass |
| `T-2622` | task | ✓ pass |
