---
id: T-2324
name: "AEF-IC-2: Disjoint write-set policy"
description: >
  arc-011 substrate ADR §6.2 question. AEF-side: orchestrator must prove disjoint
  write-sets before parallel dispatch. Three candidate proof shapes: static (frontmatter-declared)
  / dynamic (blast-radius predicted) / hybrid.

status: captured
workflow_type: inception
owner: agent
horizon: later
tags: [arc-parallel-execution-aef, downstream-of-T-2303, orchestrator, 
      planning-layer]
components: []
related_tasks: [T-2303, T-2323]
arc_id: parallel-execution-aef
created: 2026-06-10T21:32:35Z
last_update: '2026-06-11T20:34:39Z'
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
  - ts: '2026-06-10T21:34:50Z'
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
  - ts: '2026-06-11T20:34:39Z'
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
cost_estimate_proposed:
  - ts: '2026-06-10T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2324: AEF-IC-2: Disjoint write-set policy

## Problem Statement

T-2303 GO (recorded 2026-06-10 commit `989fc1e6e`) authorised the AEF-IC-1..IC-5 downstream-inception cluster. T-2323 (AEF-IC-1) carries the yield-point granularity question (where the harness ear lives). **This inception — AEF-IC-2 — carries the disjoint write-set policy question: how does the orchestrator certify that two pending tasks have non-overlapping write-sets before dispatching them concurrently?**

The substrate side (TermLink) has no opinion on disjoint write-sets — that is an AEF planning-layer concern in full. If the orchestrator dispatches two tasks in parallel and both write to the same file (or same `.tasks/active/T-*.md`, or same `.context/audits/` row), the governance plane corrupts in ways the framework's hooks cannot recover from cleanly. The substrate carries the dispatch; the orchestrator carries the disjoint proof.

Three candidate policy shapes surfaced during T-2303 Spike 4 (dependency-DAG ordering) prep work:

1. **Static declaration** — each task declares its write-set in frontmatter (`write_set: [path/to/file.ext, .tasks/active/T-*]`); orchestrator refuses parallel dispatch on any intersection. Pros: explicit, auditable, refuses-by-default; cons: humans must hand-curate write-sets per task (low-effort tasks become high-overhead to file).
2. **Dynamic prediction** — orchestrator runs `fw fabric blast-radius` against each task's anchor component and predicts the write-set from the dependency graph. Pros: zero per-task curation overhead; cons: blast-radius is a downstream estimate (read-paths included) — over-predicts the write-set and refuses safe parallels.
3. **Hybrid** — static declaration when present, dynamic prediction as fallback, with a `--prove-disjoint` orchestrator verb that does both and refuses the parallel dispatch unless both agree. Pros: best false-positive/false-negative balance; cons: composite mechanism harder to reason about and trip when wrong.

The decision binds: AEF-IC-3 (orchestrator planning layer) and AEF-IC-4 (sidecar+harness) both consume whichever policy wins here. Get this wrong:
- Over-conservative (false-positive on overlap) → orchestrator refuses safe parallels → parallel-execution arc never demonstrates HM (two dispatch IDs in flight at once).
- Over-aggressive (false-negative on overlap) → orchestrator dispatches a collision → governance plane corrupts (e.g. two workers ticking different ACs in the same task file; two workers writing different `## Recommendation` blocks).

**For whom:** AEF orchestrator + every worker agent inside the parallel-execution arc. **Why now:** AEF-IC-3 + IC-4 cannot land coherent designs until the disjoint-write-set proof shape is pinned. Sibling of AEF-IC-1 — both are direct prerequisites of the DAG advancing.

## Assumptions

- A1: The orchestrator runs *before* dispatch — it has a chance to refuse a parallel pair and fall back to sequential. Not a runtime guard.
- A2: "Write-set" semantics = the set of paths a task will create / modify / delete. Read-paths are NOT in the write-set (fabric blast-radius's `depends_on` edges are reads).
- A3: Per-task write-set granularity is *path*-level, not *line*-level. Two workers cannot safely both edit the same file even on different lines (the merge-conflict surface is the file, not the line).
- A4: The disjoint proof carries audit weight — when the orchestrator dispatches a parallel pair, the proof shape is captured in `.context/dispatches.jsonl` so post-hoc forensics can verify the orchestrator's reasoning was sound.

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

- **IW-1: Which policy shape wins — static declaration, dynamic prediction, or hybrid?**
  confidence: 1
  disposition: deferred
  rationale: Leading candidate from T-2303 Spike 4 prep is hybrid (static-when-present + dynamic-fallback). But the cost-per-task of hand-curating `write_set:` frontmatter on every build task is the load-bearing trade-off — needs operator dialogue to pin against the over-prediction rate of fabric blast-radius. Spike A resolves.

- **IW-2: At what granularity is the write-set proved — file-path, directory, glob, or component?**
  confidence: 1
  disposition: deferred
  rationale: A3 assumes path-level. But governance-plane writes are often glob-class (`.tasks/active/T-*` covers every task file; `.context/audits/*.yaml` covers every audit row). Glob-level proof may be the right shape for governance paths, path-level for source files. Composite (glob for governance, path for source) is the likely answer but needs spike dialogue. Spike B resolves.

- **IW-3: Where is the write-set proof captured for forensics — `.context/dispatches.jsonl` row, separate `disjoint-proofs.jsonl`, or inline orchestrator stdout?**
  confidence: 1
  disposition: deferred
  rationale: A4 assumes dispatches.jsonl-inline. But the proof shape may be larger than the dispatch envelope (full write-set listings, blast-radius output, conflict-check decisions) — separate file may be cleaner. Audit-cost vs forensics-completeness trade-off. Spike C resolves.

- **IW-4: What happens on disjoint-proof failure — orchestrator falls back to sequential silently, surfaces a WARN, or refuses the dispatch entirely?**
  confidence: 2
  disposition: deferred
  rationale: Leading candidate is "fall back to sequential + emit INFO" (no governance failure, just lost parallelism). But the operator may want a WARN so over-conservative policies surface for tuning. Quick spike-D dialogue resolves.

## Exploration Plan

Four operator-dialogue spikes (A: policy shape / B: granularity / C: capture surface / D: failure mode). All four are operator-dialogue spikes — the data needed is decision rationale + worked example, not implementation results. Time-box per CLAUDE.md inception conventions: 1 dialogue session per spike, ~30 min each. Spike D is shorter (~10 min) — confirmation-shape only.

**Worked example to bring into Spike A dialogue:** consider T-2323 + T-2324 running in parallel. Both write `.tasks/active/T-*` (their own task files). Static declaration → declared write-sets are `[.tasks/active/T-2323-*.md]` vs `[.tasks/active/T-2324-*.md]` → no intersection → disjoint → parallel-safe. Dynamic prediction via `fw fabric blast-radius` → both touch the inception-render path on Watchtower → predicted write-set may include `web/blueprints/tasks.py` (read-only access, but blast-radius doesn't distinguish) → predicted intersection → refused. The static-vs-dynamic divergence on this example is the load-bearing data point.

## Technical Constraints

- **The orchestrator already exists** (`bin/fw orchestrator status`, `agents/audit/orchestrator.sh`). Disjoint-write-set policy is a NEW *planning-layer* component that runs BEFORE dispatch. Not a Claude Code modification.
- **Backward compatible with sequential single-agent mode** — when the disjoint-proof refuses or no parallel pair exists, the orchestrator falls back to sequential dispatch (existing behavior, zero new overhead).
- **Audit-trail mandatory** — every refused parallel pair MUST log the conflict-class + which paths intersected, for forensic value. Silent refusal is a §ACD-class anti-pattern (substrate hides observable consequences).
- **Composes with AEF-IC-4 (sidecar+harness)** — the disjoint-proof is consumed by IC-4's ear-check semantics (the parallel-execution flag's ON/OFF state in IC-4 depends in part on IC-2's go-ahead).

## Scope Fence

**IN scope:**
- Policy shape choice (static / dynamic / hybrid)
- Write-set granularity choice (path / directory / glob / component / composite)
- Forensics capture surface (dispatches.jsonl-inline / separate file / orchestrator stdout)
- Failure-mode surface (silent / INFO / WARN / refuse)

**OUT of scope (deferred to other inceptions):**
- Yield-point granularity — AEF-IC-1 (T-2323)
- Orchestrator planning-layer implementation — AEF-IC-3 (depends on this resolving)
- Sidecar + cooperative-poll harness — AEF-IC-4 (depends on IC-1 + IC-3)
- Substrate-side primitives (parallel-dispatch TermLink hub semantics) — TL-IC-1
- Build implementation — separate build tasks post-AEF-IC-2 GO

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
- IW-1 resolved: policy shape pinned (static / dynamic / hybrid) with operator-confirmed rationale
- IW-2 resolved: write-set granularity pinned (path / directory / glob / component / composite) with rationale citing governance vs source path classes
- IW-3 resolved: forensics capture surface chosen with rationale citing audit-cost vs forensics-completeness trade-off
- IW-4 resolved: failure-mode behaviour pinned (silent / INFO / WARN / refuse)
- Decision rationale captured in `## Decisions` + Dialogue Log (when present)
- AEF-IC-3 (orchestrator planning layer) can consume the policy as its planning-layer input

**NO-GO if:**
- Spike dialogue surfaces that the disjoint-proof problem is unbounded (e.g. fabric blast-radius cannot predict write-sets at any practical granularity → falls back to "all parallel dispatch is unsafe" → kicks parallel-execution arc to a fundamentally different mechanism, likely AEF-IC-5 absorption)
- The forensics audit-cost dominates the dispatch overhead (renders parallel-execution net-negative on small tasks)

**DEFER if:**
- Operator wants AEF-IC-1 (T-2323) to resolve first since IC-4 ear-check semantics depend on both IC-1 + IC-2 → resolving them in sequence may surface compound constraints; concrete revisit trigger logged

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

**Rationale:** Scoping inception. Three candidate policies need spike dialogue to pin against false-positive (over-conservative) vs false-negative (governance-plane corruption) trade-offs. Legitimate evidence-gap DEFER per T-2144 — revisit trigger: operator spike A/B/C session OR first downstream build pressure on planning layer.

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

**Decision**: DEFER

**Rationale**: Scoping inception. Three candidate policies need spike dialogue to pin against false-positive (over-conservative) vs false-negative (governance-plane corruption) trade-offs. Legitimate evidence-gap DEFER per T-2144 — revisit trigger: operator spike A/B/C session OR first downstream build pressure on planning layer.

**Date**: 2026-06-10T21:56:07Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-10T21:34:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a21260e9
- **Timestamp:** 2026-06-10T21:35:06Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-1
     - evidence: `IW-1 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

### 2026-06-10T21:56:07Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Scoping inception. Three candidate policies need spike dialogue to pin against false-positive (over-conservative) vs false-negative (governance-plane corruption) trade-offs. Legitimate evidence-gap DEFER per T-2144 — revisit trigger: operator spike A/B/C session OR first downstream build pressure on planning layer.

### 2026-06-10T21:56:07Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)
- **Reason:** Inception decision: DEFER — parking task
