---
id: T-2553
name: "Corpus exercise: document 5 most-used AEF processes in the workflow designer"
description: >
  Inception: Corpus exercise: document 5 most-used AEF processes in the workflow designer

status: work-completed
workflow_type: inception
owner: human
horizon: null
arc_id: designer-corpus
tags: []
components: []
related_tasks: []
created: 2026-07-19T19:37:24Z
last_update: 2026-07-19T20:00:35Z
date_finished: 2026-07-19T20:00:35Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-07-19T19:38:03Z'
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
  - ts: '2026-07-19T19:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2553: Corpus exercise: document 5 most-used AEF processes in the workflow designer

## Problem Statement

The AEF↔832 workflow-designer integration has a closed forward pipeline (designer → gallery API →
`fw bpmn compile` → `fw bpmn promote`, joint-tested via `bpmn_promote_e2e.bats`), but **every proof
so far ran on fixtures — zero real-world corpus exists**. No actual AEF process has ever been drawn
in the designer and pushed through the pipeline. This inception scopes the corpus exercise: document
the 5 most-used/most-critical AEF processes as BPMN diagrams in the designer, run each through the
pipeline, and accumulate every discovered gap into arc `designer-corpus` (arc-014), driven to a
quality closure. Scoped in a live grill with the operator (2026-07-19, full Dialogue Log in
`docs/reports/T-2553-designer-corpus-inception.md`).

## Assumptions

- The frozen-v1 `aef:*` vocabulary + BPMN core can express *most* of the 5 selected processes;
  where it cannot, the WARN layer (T-2552 pattern) surfaces the loss instead of silently dropping it.
- 832 remains available as pair-drafting partner and vocabulary owner (rail cid t2399-auto-063412 active).
- Additive-only vocabulary extension does not break diagrams drawn earlier in the exercise.

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

- **IW-1: What is the exercise FOR — docs, pipeline-dogfood, or both?**
  confidence: 3
  disposition: answered
  rationale: Operator chose 1c (both) in grill 2026-07-19 — diagrams are real docs AND each runs the pipeline; gaps logged not fixed mid-flight (Dialogue Log, docs/reports/T-2553-designer-corpus-inception.md)

- **IW-2: Who authors the diagrams (test-validity question)?**
  confidence: 3
  disposition: answered
  rationale: Operator chose 2d (pair: 832/AEF draft, operator reviews+corrects in designer UI) — tests both the pipeline and 832's real product at bounded operator cost

- **IW-3: What is the success/quality structure?**
  confidence: 3
  disposition: answered
  rationale: Operator: accumulator arc — vocabulary gaps, issues, errors, enhancements, failings all filed as constituent tasks of arc designer-corpus (arc-014) and driven to closure; arc close gate (G-062, --demo of headline mechanic) IS the quality outcome, structurally enforced

- **IW-4: Can the aef:* vocabulary be extended mid-exercise without breaking continuity/fluidity?**
  confidence: 2
  disposition: answered
  rationale: Operator authorized+instructed extension, with 832 owning the development process. Continuity mechanism = additive-only extensions + WARN-first (T-2552 pattern buffers diagrams drawn before semantics land) + rail propose→ratify→byte-exact-fixture→joint-bats loop (proven 4x: uid, lanes, promote seam, typed events). Confidence 2: mechanism proven per-feature, not yet under corpus-rate load — proving it IS part of the exercise

- **IW-5: Who owns diagram↔reality drift?**
  confidence: 3
  disposition: answered
  rationale: Operator: the process owner — here the AEF agent. Structural drift-check (fabric-drift-style: diagram references source files, doctor WARNs on change) logged as an arc enhancement candidate, not iteration-1 scope

- **IW-6: Sequencing vs frozen-v1 ratification (832 T-189/T-190) and T-2551 typed-event decision?**
  confidence: 2
  disposition: deferred
  rationale: Operator decision — agent recommendation in artifact §6: ratify frozen-v1 base FIRST (extensions become diffs against a signed baseline), record T-2551 NO-GO now with explicit revisit-on-corpus-evidence clause (this arc is exactly T-2551's revisit condition)

- **IW-7: Which 5 processes?**
  confidence: 3
  disposition: answered
  rationale: Telemetry-selected per operator instruction (counts in artifact): task lifecycle (1599+230 build tasks), inception flow (408 completed/295 decided), session/handover lifecycle (1387 handovers), dispatch-orchestration loop (992 dispatches/1240 outcomes), audit cron (748 runs + daily). Healing loop dropped (26 events — low usage)

- **IW-8: Does the vocabulary actually COVER the 5 selected processes?**
  confidence: 0
  disposition: deferred
  rationale: This is the exercise's core empirical question — answerable only by running the arc; the gap list is the deliverable (antifragility)

## Exploration Plan

On GO, spawn per-process build children under arc designer-corpus (one process = one deliverable,
Task Sizing Rules), in seam-stress order:

1. **Task lifecycle** (captured→started↔issues→work-completed, human-AC partial-complete gate) — simplest; calibrates the method. Time-box: 1 session.
2. **Inception flow** (explore→GO/NO-GO gateway→build children) — exercises inception-subprocess materialization (T-2549) + human decision gateway. 1 session.
3. **Session lifecycle** (init→work→handover→push) — timer/cron flavored. 1 session.
4. **Dispatch-orchestration loop** (resolver→worker→outcome backprop) — message-event flavored; stresses exactly what T-2551 declined to consume. 1 session.
5. **Audit cron** (timer→audit→WARN/FAIL→emit tasks) — timer+error branching. 1 session.

Per process: pair-draft BPMN (AEF or 832) → operator reviews/corrects in designer UI → gallery-persist
→ `fw bpmn compile` (log every WARN/silent loss as arc task) → promote dry-run where meaningful.
Gap protocol: log-to-arc as a task; additive vocabulary extensions proposed to 832 over the rail;
no mid-flight breaking changes.

## Technical Constraints

- Designer served at `$(bin/fw watchtower url)/designer` (sha-pinned bundle); gallery API is the 8
  `/api/*` endpoints (T-2529/T-2530) — persistence in `.context/`.
- `fw bpmn compile` emits only `{userTask, serviceTask, scriptTask}`; events WARN-only (T-2552);
  gateways/loops transited not represented. Semantic loss is expected and is the measured signal.
- Vocabulary changes require 832-side ratification (KNOWN_AEF_KEYS + designer palette) — AEF cannot
  unilaterally extend the shared contract; rail round-trip latency is a real constraint on cadence.

## Scope Fence

**IN:** the 5 telemetry-selected processes; docs+dogfood per diagram; gap/issue/enhancement
accumulation into arc-014; additive `aef:*` vocabulary proposals via the rail; operator UI review.
**OUT:** reverse exporter (auto-generating BPMN from AEF source); typed-event *consumption*
(T-2551, separate decision); designer UI development (832's product, their process); breaking
vocabulary changes; fixing discovered gaps mid-documentation (they get filed, prioritized, then fixed
as arc constituents).

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
- Scope settled with the operator (purpose, authorship, quality structure, gap protocol) — done in grill
- Forward pipeline live end-to-end (designer, gallery API, compile, promote) — verified this session
- Process selection grounded in telemetry, not taste — done (counts in artifact)
- 832 partnership active (rail loop functioning) — last exchange offsets 80–82, seam confirmed both sides

**NO-GO if:**
- Designer/gallery surface unavailable or unpinned (would test nothing real)
- 832 declines the pair-drafting / vocabulary-ratification role (continuity spine missing)
- Operator cannot commit UI review time (2d authorship model collapses to 2a, which tests only the pipeline)

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

Grill with operator (2026-07-19) settled scope: 1c both docs+pipeline-dogfood, 2d pair-draft with operator UI review, arc-accumulator model, vocabulary extension authorized with 832 owning the development process. Forward pipeline is closed and joint-tested; the one gap fixtures cannot close is zero real-world corpus. Telemetry selects the 5 processes.

**Evidence:**

- Pipeline closed end-to-end: `fw bpmn compile`/`promote` shipped+hardened (T-2531/T-2542/T-2543), joint test `bpmn_promote_e2e.bats` ratified both sides (rail offsets 80/81); `/designer` + gallery API live-verified (T-2525/T-2529/T-2530).
- Corpus gap is real and previously flagged: rendered-corpus work was deferred precisely for "no corpus = no substrate".
- Telemetry selection (this session): build-task lifecycle 1599 completed + 230 active; handovers 1387; inceptions 408 completed / 295 decided; dispatches 992 (+1240 outcomes); audit cron 748 runs. Healing dropped (26 events).
- Grill dialogue (2026-07-19) settled IW-1..IW-5, IW-7; full log in `docs/reports/T-2553-designer-corpus-inception.md`.
- Arc `designer-corpus` (arc-014) registered, anchored here, status draft — `fw arc start` on GO.

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

**Rationale**: Recommendation: GO

Rationale:

Grill with operator (2026-07-19) settled scope: 1c both docs+pipeline-dogfood, 2d pair-draft with operator UI review, arc-accumulator model, vocabulary extension authorized with 832 owning the development process. Forward pipeline is closed and joint-tested; the one gap fixtures cannot close is zero real-world corpus. Telemetry selects the 5 processes.

Evidence:

- Pipeline closed end-to-end: `fw bpmn compile`/`promote` shipped+hardened (T-2531/T-2542/T-2543), joint test `bpmn_promote_e2e.bats` ratified both sides (rail offsets 80/81); `/designer` + gallery API live-verified (T-2525/T-2529/T-2530).
- Corpus gap is real and previously flagged: rendered-corpus work was deferred precisely for "no corpus = no substrate".
- Telemetry selection (this session): build-task lifecycle 1599 completed + 230 active; handovers 1387; inceptions 408 completed / 295 decided; dispatches 992 (+1240 outcomes); audit cron 748 runs. Healing dropped (26 events).
- Grill dialogue (2026-07-19) settled IW-1..IW-5, IW-7; full log in `docs/reports/T-2553-designer-corpus-inception.md`.
- Arc `designer-corpus` (arc-014) registered, anchored here, status draft — `fw arc start` on GO.

**Date**: 2026-07-19T20:00:34Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-07-19T19:38:03Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-07-19T20:00:34Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale:

Grill with operator (2026-07-19) settled scope: 1c both docs+pipeline-dogfood, 2d pair-draft with operator UI review, arc-accumulator model, vocabulary extension authorized with 832 owning the development process. Forward pipeline is closed and joint-tested; the one gap fixtures cannot close is zero real-world corpus. Telemetry selects the 5 processes.

Evidence:

- Pipeline closed end-to-end: `fw bpmn compile`/`promote` shipped+hardened (T-2531/T-2542/T-2543), joint test `bpmn_promote_e2e.bats` ratified both sides (rail offsets 80/81); `/designer` + gallery API live-verified (T-2525/T-2529/T-2530).
- Corpus gap is real and previously flagged: rendered-corpus work was deferred precisely for "no corpus = no substrate".
- Telemetry selection (this session): build-task lifecycle 1599 completed + 230 active; handovers 1387; inceptions 408 completed / 295 decided; dispatches 992 (+1240 outcomes); audit cron 748 runs. Healing dropped (26 events).
- Grill dialogue (2026-07-19) settled IW-1..IW-5, IW-7; full log in `docs/reports/T-2553-designer-corpus-inception.md`.
- Arc `designer-corpus` (arc-014) registered, anchored here, status draft — `fw arc start` on GO.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1f0e7aa8
- **Timestamp:** 2026-07-19T20:00:36Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-2
     - evidence: `IW-2 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-5
     - evidence: `IW-5 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  3. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-7
     - evidence: `IW-7 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-3f504cfb
- **Timestamp:** 2026-07-19T20:00:36Z
- **Overall:** CONFIRMED
- **Claims:** 7

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/T-2553-designer-corpus-inception.md` | file | ✓ pass |
| `T-2531` | task | ✓ pass |
| `T-2542` | task | ✓ pass |
| `T-2543` | task | ✓ pass |
| `T-2525` | task | ✓ pass |
| `T-2529` | task | ✓ pass |
| `T-2530` | task | ✓ pass |

### 2026-07-19T20:00:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
