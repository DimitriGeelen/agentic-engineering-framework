---
id: T-2330
name: "BVP driver propose-queue surface — agent proposes, operator one-click approves"
description: >
  Inception: BVP driver propose-queue surface — agent proposes, operator one-click
  approves

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-06-11T14:14:48Z
last_update: 2026-06-11T14:24:30Z
date_finished: 2026-06-11T14:24:30Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-06-11T14:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-11T14:15:03Z'
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
---

# T-2330: BVP driver propose-queue surface — agent proposes, operator one-click approves

## Problem Statement

Driver-add (`fw bvp driver --add`) is the lone Sovereign class without an "agent proposes, human one-click approves" Watchtower surface. The operator types name + weight + ≥30-char rationale three times for T-2306's V_* trio — typing friction for a decision whose hard work is judging the rationale, not transcribing it. Sibling Sovereign classes (inception decide, arc close, tier-0 approve, BVP weight commit, per-task BVP confirm) all already have propose→approve queues. The deferred T-2245 IW-3 verbs (`suggest|create|edit|retire`) were the placeholder for exactly this surface.

Full B-vs-C analysis with driver scoring: `docs/reports/T-2330-bvp-driver-propose-queue.md`.

## Assumptions

- A1: Sovereign click integrity is preserved as long as Approve runs `fw bvp driver --add --from-watchtower` and operator's rationale-review still happens (R5 anti-Goodhart).
- A2: Pattern reuse from `/approvals`, `/inception/<id>`, `/review/<id>` minimises operator learning cost.
- A3: The propose-queue surface generalises to retire/edit at marginal cost (separate slices, same pattern).

## Open Questions

- **IW-1: Storage location for proposals**
  confidence: 1
  disposition: deferred
  rationale: Sidecar `policy/value-drivers.proposed.yaml` vs in-place `bvp_drivers_proposed:` list — spike needed. Lean in-place for pattern consistency with `bvp_scores_proposed:` (T-1922). See artifact §Open Questions.

- **IW-2: Queue surface placement**
  confidence: 2
  disposition: deferred
  rationale: New `/bvp/proposed` route vs inline section on `/bvp`. Lean inline initially; promote to route if >5 pending becomes the norm.

- **IW-3: Race semantics**
  confidence: 0
  disposition: deferred
  rationale: Two agents propose same driver-id with different rationales / weights. Lean: append all, operator Approves one, others Reject. Spike needed.

- **IW-4: Reject UX**
  confidence: 1
  disposition: deferred
  rationale: Inline delete vs reject-with-rationale. Lean reject-with-rationale for L-class capture.

- **IW-5: TTL on stale proposals**
  confidence: 1
  disposition: deferred
  rationale: 30d soft-expire (banner only, not auto-delete) so operator catches the backlog signal.

- **IW-6: Scope creep to retire / edit / suggest**
  confidence: 2
  disposition: deferred
  rationale: T-2245 IW-3 deferred all four; T-2330 ships `--add` first. retire/edit follow as natural slices.

- **IW-7: Retrofit T-2306**
  confidence: 3
  disposition: answered
  rationale: Once queue lands, T-2306's V_* trio moves from "operator types 3 forms" to "agent files 3 proposals, operator clicks Approve 3×". T-2306 closes when queue ships AND operator approves three.

## Exploration Plan

1. IW-1 spike (~30min) — prototype both storage shapes in a scratch branch, compare audit/migration cost. Decide before any production code.
2. IW-3 spike (~20min) — write tests covering 2-agent same-driver-id race; decide merge policy from test ergonomics.
3. Slice plan (post-spikes): (S1) Flask `/api/bvp/driver/propose` POST + storage write; (S2) Watchtower queue section + Approve/Reject buttons + `--from-watchtower` wiring; (S3) bats + Playwright tests; (S4) retrofit T-2306.

## Technical Constraints

- Sovereign rail (`lib/bvp.sh:67-84` `require_human_actor()`) must remain unchanged. The Approve button posts to a Flask endpoint that runs `--from-watchtower`; no new bypass.
- CSRF: existing `web/static/csrf-htmx.js` auto-injection covers htmx posts (T-2079 pattern).
- `policy/value-drivers.yaml` is hand-edited rarely; any in-place mutation must round-trip cleanly (preserve comments, ordering).

## Scope Fence

**IN scope:**
- Propose path: agent writes proposal entries, operator one-click approves via Watchtower
- Queue surface listing pending proposals with per-row Approve / Reject
- Audit trail (author + timestamp + rationale + decision)
- Race semantics for parallel proposals
- Retrofit T-2306 V_* trio

**OUT of scope (separate slices):**
- Driver-retire / driver-edit (same pattern, separate inceptions)
- Auto-approve of agent-proposed drivers (NEVER — this is the Sovereign rail)
- Cross-project driver propagation
- Token-based delegated authority (Path C — deferred until F-AUTONOMY preconditions land)

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

B-vs-C analysis (session S-2026-0611-1544): Path B HV/LC=0.21 vs Path C 0.11 (~2x ratio). B is the structural fix already half-designed by T-2245 IW-3 deferred verbs (suggest|create|edit|retire). Mirrors existing /inception/<id>, /approvals, /review/<id>, /arcs/<slug>/close 'agent proposes, human one-click approves' patterns — pattern-memory already carries. R5 anti-Goodhart preserved (Sovereign click unchanged, only typing burden removed). Generalizes to retire/edit at zero marginal cost; queue is the merge boundary for parallel-agent proposals. Path C (delegated tokens) deferred — driver-add is the wrong proving ground for a sovereignty primitive whose pattern propagates across all Sovereign verbs. Scope-fence choices still open: sidecar inbox YAML vs in-place bvp_drivers_proposed list; queue surface placement; race semantics; reject UX.

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

**Decision**: GO

**Rationale**: B-vs-C analysis (session S-2026-0611-1544): Path B HV/LC=0.21 vs Path C 0.11 (~2x ratio). B is the structural fix already half-designed by T-2245 IW-3 deferred verbs (suggest|create|edit|retire). Mirrors existing /inception/<id>, /approvals, /review/<id>, /arcs/<slug>/close 'agent proposes, human one-click approves' patterns — pattern-memory already carries. R5 anti-Goodhart preserved (Sovereign click unchanged, only typing burden removed). Generalizes to retire/edit at zero marginal cost; queue is the merge boundary for parallel-agent proposals. Path C (delegated tokens) deferred — driver-add is the wrong proving ground for a sovereignty primitive whose pattern propagates across all Sovereign verbs. Scope-fence choices still open: sidecar inbox YAML vs in-place bvp_drivers_proposed list; queue surface placement; race semantics; reject UX.

**Date**: 2026-06-11T14:24:29Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-11T14:16:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-06-11T14:24:29Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** B-vs-C analysis (session S-2026-0611-1544): Path B HV/LC=0.21 vs Path C 0.11 (~2x ratio). B is the structural fix already half-designed by T-2245 IW-3 deferred verbs (suggest|create|edit|retire). Mirrors existing /inception/<id>, /approvals, /review/<id>, /arcs/<slug>/close 'agent proposes, human one-click approves' patterns — pattern-memory already carries. R5 anti-Goodhart preserved (Sovereign click unchanged, only typing burden removed). Generalizes to retire/edit at zero marginal cost; queue is the merge boundary for parallel-agent proposals. Path C (delegated tokens) deferred — driver-add is the wrong proving ground for a sovereignty primitive whose pattern propagates across all Sovereign verbs. Scope-fence choices still open: sidecar inbox YAML vs in-place bvp_drivers_proposed list; queue surface placement; race semantics; reject UX.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a9b71e1c
- **Timestamp:** 2026-06-11T14:24:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-11T14:24:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
