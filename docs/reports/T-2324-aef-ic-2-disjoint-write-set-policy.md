# T-2324 — AEF-IC-2: Disjoint write-set policy

> **Inception research artifact** (backfilled by T-2515 from the `T-2324` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-2324-aef-ic-2-disjoint-write-set-policy.md`. **Decision recorded: DEFER.**

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

## Recommendation

**Recommendation:** DEFER

**Rationale:** Scoping inception. Three candidate policies need spike dialogue to pin against false-positive (over-conservative) vs false-negative (governance-plane corruption) trade-offs. Legitimate evidence-gap DEFER per T-2144 — revisit trigger: operator spike A/B/C session OR first downstream build pressure on planning layer.

## Decision

**Decision**: GO

**Rationale**: Scoping inception. Three candidate policies need spike dialogue to pin against false-positive (over-conservative) vs false-negative (governance-plane corruption) trade-offs. Legitimate evidence-gap DEFER per T-2144 — revisit trigger: operator spike A/B/C session OR first downstream build pressure on planning layer.

**Date**: 2026-06-26T10:32:39Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a0973cd5
- **Timestamp:** 2026-06-26T10:32:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-06-10T21:56:07Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Scoping inception. Three candidate policies need spike dialogue to pin against false-positive (over-conservative) vs false-negative (governance-plane corruption) trade-offs. Legitimate evidence-gap DEFER per T-2144 — revisit trigger: operator spike A/B/C session OR first downstream build pressure on planning layer.

### 2026-06-10T21:56:07Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)
- **Reason:** Inception decision: DEFER — parking task

### 2026-06-26T10:32:39Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Scoping inception. Three candidate policies need spike dialogue to pin against false-positive (over-conservative) vs false-negative (governance-plane corruption) trade-offs. Legitimate evidence-gap DEFER per T-2144 — revisit trigger: operator spike A/B/C session OR first downstream build pressure on planning layer.

### 2026-06-26T10:32:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)
- **Reason:** Inception decision in progress

### 2026-06-26T10:32:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
