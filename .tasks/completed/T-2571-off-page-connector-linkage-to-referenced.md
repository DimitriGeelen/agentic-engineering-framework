---
id: T-2571
name: "off-page connector linkage to referenced workflows (uuid registry + forward-ref
  capture)"
description: >
  Inception: off-page connector linkage to referenced workflows (uuid registry + forward-ref
  capture)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-07-20T20:49:13Z
last_update: 2026-07-20T21:54:51Z
date_finished: 2026-07-20T21:53:57Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-07-20T20:50:01Z'
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
  - ts: '2026-07-20T21:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2571: off-page connector linkage to referenced workflows (uuid registry + forward-ref capture)

## Problem Statement

Off-page connectors in designer diagrams are name-only visuals — nothing links them to the workflow they reference. The store has no immutable workflow identity (directory slug only), `/api/save` and `fw bpmn compile` have no resolution surface, so a dangling reference (referrer drawn before the target workflow exists) is silently invisible. Operator sketch (2026-07-20): mint a UUID entry at reference time, claim it when the target is created; in parallel propose a task to document the referenced workflow. Research artifact: `docs/reports/T-2571-offpage-connector-linkage.md`.

## Assumptions

Registered in `.context/project/assumptions.yaml` (fw assumption list --task T-2571):
1. 832 accepts draw-time uuid minting in their editor (Q2, offset 107) — else a store-side write-back channel is needed.
2. Proposed serialization (`workflowRef` on `aef:link`) survives 832 review (Q1) — parsing slices adjust only on objection.
3. uuid backfill of the 7 existing store projects is additive to meta.json — 832's 0.2.x client ignores unknown fields.

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

- **IW-1: What is the workflow identity model — immutable uuid in meta.json (slug as display) or slug-only pins?**
  confidence: 3
  disposition: answered
  rationale: operator steer 2026-07-20 dialogue — uuid-canonical as recommended (T-1848 precedent)
- **IW-2: How are forward references captured — pending-ref registry file, ghost store entries, or hybrid (registry + gallery ghost rendering)?**
  confidence: 3
  disposition: answered
  rationale: operator steer 2026-07-20 — ghosts, WITH back-reference visual markers (which workflows/nodes reference it + needs-mapping state); registry is the data source, gallery renders ghosts from it
- **IW-3: When is the documentation task for a referenced-but-uncreated workflow minted — at save-time through the FW_TASK_ORIGIN gate, or batch-proposed at a governed verb (refs/promote/compile)?**
  confidence: 2
  disposition: answered
  rationale: operator delegated ("most reliable") — save-time gate minting (capture-at-source, idempotent per uuid) + compile WARN + audit sweep backstop; two-layer pattern per T-2204 precedent
- **IW-4: How does a newly created workflow claim a pending uuid — designer UI picker (832-side), CLI claim verb, or name-match heuristic?**
  confidence: 2
  disposition: answered
  rationale: plain-language elaboration given 2026-07-20 (walkthrough in artifact §D); operator then delegated via broad continue directive — design locked as ghost-card "create this workflow" button (claims uuid at birth) + `fw bpmn claim <uuid> <project>` CLI fallback; name-match may only SUGGEST, never bind silently
- **IW-5: What is the AEF/832 seam split, and does 832 accept the vocabulary extension (workflowRef on aef:link)?**
  confidence: 3
  disposition: answered
  rationale: 832 offset 108 (operator-confirmed positions) — ACCEPTED: extend aef:link (workflowRef+name+linkId, orthogonal axes), targetWorkflow→workflowRef rename w/ import alias, draw-time uuid minting, claim picker feasible; contract v0 ratified at offset 109 (/api/list extended, ghosts as separate top-level array, registry in store). 832 build is design-dialogue-gated by THEIR operator — no blocker on AEF substrate (their words: "your DECIDED half proceeds independently")

## Exploration Plan

Completed (all corpus-read spikes, no build artifacts):
1. **Corpus scan** — confirmed zero `aef:link` instances with machine targets in all 7 stored projects + fixtures; identity is slug-only; no resolution surface in `/api/save` or compile. (Evidence §1-3 of artifact.)
2. **meta.json shape check** — `{id, title, versions, latest, updated}`; immutable `uuid` field is additive (assumption 3).
3. **Operator design dialogue** — 2 rounds, all four AEF-side axes decided (IW-1..IW-4).
4. **832 seam** — proposal posted offset 107 (Q1-Q3); reply pending (IW-5 deferred).

## Technical Constraints

- Registry writes must be atomic (temp+os.replace, L-491/L-495 corpus discipline) — the registry becomes a shared surface between `/api/save`, compile, claim, and audit.
- Task minting from `/api/save` MUST route through the FW_TASK_ORIGIN create-via-gate (T-2543): owner:human, captured, horizon later, idempotent per uuid — never a raw create path.
- uuid must be minted editor-side (832) at draw time; store-side minting would require writing back into 832's diagram XML (rejected — crosses the content-ownership seam).
- 832's 0.2.x client consumes `/api/*` (T-2529 set); GET /api/workflows must be additive and CSRF-exempt like siblings.

## Scope Fence

**IN (on GO):** uuid identity in meta.json + backfill (S1); pending-ref registry + lib (S2); `fw bpmn claim` CLI (S6); then, once 832 answers Q1: compile dangling-ref WARN (S3), save-time gate minting (S4), gallery ghost cards + back-ref markers + N-unmapped marker (S5).
**OUT:** 832's editor half (connector palette/serialization, draw-time uuid mint, claim picker UI) — theirs per arc-014 scope rule 4; name-match auto-binding (suggest-only if ever); cross-host workflow references (single-store only for v1).

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

**GO if:**
- All four AEF-side design axes (identity, ghost capture, minting timing, claim moment) are operator-decided with bounded slices
- At least the substrate slices (S1 identity, S2 registry, S6 claim CLI) are buildable without waiting on 832
- Each slice is reversible (additive meta.json field, new registry file, new CLI verb — no destructive migration)

**NO-GO if:**
- 832 rejects the seam outright (no serialization carrier for the uuid → linkage impossible end-to-end)
- Identity backfill would break 832's 0.2.x client (assumption 3 fails)

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

**Recommendation:** GO — all six slices S1-S6 (seam fully ratified with 832 at offsets 108/109)

**Rationale:**

Every design axis is now decided. IW-1..IW-4 by operator dialogue (uuid-canonical identity; registry-backed ghosts with bidirectional reference markers; save-time gate minting with compile-WARN + audit-sweep backstop; explicit claim — ghost button + CLI, no silent name-match). IW-5 by 832's operator-confirmed positions (offset 108): extend `aef:link` with `workflowRef` (import alias for legacy `targetWorkflow`), `linkId` kept as an orthogonal intra-diagram axis, draw-time uuid minting accepted, claim picker feasible on their 0.3.0 line. Contract v0 ratified at offset 109 (extended /api/list, ghosts partitioned as a separate array so old pickers never open one, registry lives in the store, claims audit trail). 832's own build waits on THEIR operator's go/no-go, but they explicitly unblocked our half. All slices additive and reversible.

**Evidence:**

- Corpus scan: zero machine-linked `aef:link` instances in our store; 832 offset 108 correction — their editor DOES serialize `targetWorkflow`+`linkId`, the gap is slug-based identity (rename-fragile, forward-ref-blind), which is exactly the operator's observation with a sharper mechanism.
- meta.json shape `{id, title, versions, latest, updated}` — uuid additive (aef-dispatch-loop/meta.json read).
- Operator steers captured verbatim in artifact Dialogue Log (rounds 1-2); IW-1..IW-5 all disposed answered.
- 832 positions operator-confirmed at rail offset 108; contract v0 posted/ratified at offset 109 (dm:0e7ee6ca…:6a646ce8…).
- A-044 (draw-time minting) and A-045 (workflowRef shape) validated on offset-108 evidence; A-046 (backfill additive to 0.3.0 client) verified live in S1 before dependent slices land.
- Governance precedent for save-time minting already shipped and tested: FW_TASK_ORIGIN gate (T-2542/T-2543), DEFER-injection (T-2548/L-504).

## Decisions

### 2026-07-20 — task-minting timing (IW-3, operator-delegated on reliability)
- **Chose:** save-time capture through the FW_TASK_ORIGIN gate (idempotent per uuid) + compile WARN + audit drift sweep as backstop.
- **Why:** capture-at-source never depends on someone running a verb later; two-layer producer-gate+sweep is the proven T-2204 pattern.
- **Rejected:** batch-only proposal verb — "wired but not deployed" drift class: reliable only if invoked.

### 2026-07-20 — claim binding (IW-4)
- **Chose:** explicit claim only — ghost-card "create this workflow" (uuid inherited at birth) + `fw bpmn claim <uuid> <project>` fallback.
- **Why:** a wrong bind silently corrupts every referring diagram; explicitness keeps the failure loud.
- **Rejected:** automatic name-matching — may only ever SUGGEST a claim, never execute one.

### 2026-07-20 — uuid mint point (proposed to 832, Q2)
- **Chose (proposal):** editor mints at draw time; store only registers.
- **Why:** store-side minting requires writing back into 832's diagram XML — crosses the content-ownership seam.
- **Rejected:** store-side mint + write-back channel (fallback only if 832 refuses draw-time).

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — all six slices S1-S6 (seam fully ratified with 832 at offsets 108/109)

Rationale:

Every design axis is now decided. IW-1..IW-4 by operator dialogue (uuid-canonical identity; registry-backed ghosts with bidirectional reference markers; save-time gate minting with compile-WARN + audit-sweep backstop; explicit claim — ghost button + CLI, no silent name-match). IW-5 by 832's operator-confirmed positions (offset 108): extend `aef:link` with `workflowRef` (import alias for legacy `targetWorkflow`), `linkId` kept as an orthogonal intra-diagram axis, draw-time uuid minting accepted, claim picker feasible on their 0.3.0 line. Contract v0 ratified at offset 109 (extended /api/list, ghosts partitioned as a separate array so old pickers never open one, registry lives in the store, claims audit trail). 832's own build waits on THEIR operator's go/no-go, but they explicitly unblocked our half. All slices additive and reversible.

Evidence:

- Corpus scan: zero machine-linked `aef:link` instances in our store; 832 offset 108 correction — their editor DOES serialize `targetWorkflow`+`linkId`, the gap is slug-based identity (rename-fragile, forward-ref-blind), which is exactly the operator's observation with a sharper mechanism.
- meta.json shape `{id, title, versions, latest, updated}` — uuid additive (aef-dispatch-loop/meta.json read).
- Operator steers captured verbatim in artifact Dialogue Log (rounds 1-2); IW-1..IW-5 all disposed answered.
- 832 positions operator-confirmed at rail offset 108; contract v0 posted/ratified at offset 109 (dm:0e7ee6ca…:6a646ce8…).
- A-044 (draw-time minting) and A-045 (workflowRef shape) validated on offset-108 evidence; A-046 (backfill additive to 0.3.0 client) verified live in S1 before dependent slices land.
- Governance precedent for save-time minting already shipped and tested: FW_TASK_ORIGIN gate (T-2542/T-2543), DEFER-injection (T-2548/L-504).

**Date**: 2026-07-20T21:53:57Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-07-20T20:50:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-07-20T21:53:57Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — all six slices S1-S6 (seam fully ratified with 832 at offsets 108/109)

Rationale:

Every design axis is now decided. IW-1..IW-4 by operator dialogue (uuid-canonical identity; registry-backed ghosts with bidirectional reference markers; save-time gate minting with compile-WARN + audit-sweep backstop; explicit claim — ghost button + CLI, no silent name-match). IW-5 by 832's operator-confirmed positions (offset 108): extend `aef:link` with `workflowRef` (import alias for legacy `targetWorkflow`), `linkId` kept as an orthogonal intra-diagram axis, draw-time uuid minting accepted, claim picker feasible on their 0.3.0 line. Contract v0 ratified at offset 109 (extended /api/list, ghosts partitioned as a separate array so old pickers never open one, registry lives in the store, claims audit trail). 832's own build waits on THEIR operator's go/no-go, but they explicitly unblocked our half. All slices additive and reversible.

Evidence:

- Corpus scan: zero machine-linked `aef:link` instances in our store; 832 offset 108 correction — their editor DOES serialize `targetWorkflow`+`linkId`, the gap is slug-based identity (rename-fragile, forward-ref-blind), which is exactly the operator's observation with a sharper mechanism.
- meta.json shape `{id, title, versions, latest, updated}` — uuid additive (aef-dispatch-loop/meta.json read).
- Operator steers captured verbatim in artifact Dialogue Log (rounds 1-2); IW-1..IW-5 all disposed answered.
- 832 positions operator-confirmed at rail offset 108; contract v0 posted/ratified at offset 109 (dm:0e7ee6ca…:6a646ce8…).
- A-044 (draw-time minting) and A-045 (workflowRef shape) validated on offset-108 evidence; A-046 (backfill additive to 0.3.0 client) verified live in S1 before dependent slices land.
- Governance precedent for save-time minting already shipped and tested: FW_TASK_ORIGIN gate (T-2542/T-2543), DEFER-injection (T-2548/L-504).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-75e094b3
- **Timestamp:** 2026-07-20T21:53:58Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-2
     - evidence: `IW-2 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-4
     - evidence: `IW-4 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  3. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-5
     - evidence: `IW-5 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-79ecaf74
- **Timestamp:** 2026-07-20T21:53:58Z
- **Overall:** CONFIRMED
- **Claims:** 3

| Claim | Type | Status |
|-------|------|--------|
| `T-2542` | task | ✓ pass |
| `T-2543` | task | ✓ pass |
| `T-2548` | task | ✓ pass |

### 2026-07-20T21:53:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
