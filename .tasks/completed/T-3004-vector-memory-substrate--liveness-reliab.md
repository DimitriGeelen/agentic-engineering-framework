---
id: T-3004
name: "vector memory substrate — liveness, reliability, isolation, and the vendored-client
  story"
description: >
  Inception: vector memory substrate — liveness, reliability, isolation, and the vendored-client
  story

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-08-15T05:18:24Z
last_update: 2026-08-15T05:29:43Z
date_finished: 2026-08-15T05:29:43Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-08-15T05:19:37Z'
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

# T-3004: vector memory substrate — liveness, reliability, isolation, and the vendored-client story

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

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

- **IW-1: Is a vector store process actually running and reachable from this host?**
  confidence: 3
  disposition: dissolved
  rationale: The question presumed a service. There is none and none is wanted — the store is embedded sqlite-vec at `web/embeddings.py:52`; only Ollama (`:11434`, live) is a service. F0.

- **IW-2: Does any live framework code path read from it — and how many of those
  paths are reachable in a normal session, as opposed to present in the tree?**
  confidence: 3
  disposition: answered
  rationale: Yes — `focus.sh:144,152` runs recall + briefing on every `fw context focus`, via `lib/ask.py` → `web.embeddings.rag_retrieve`. Reachable every task start. F1/F3.

- **IW-3: When the store is absent or slow, what does the framework do — and is
  that difference observable to anyone? (The `timeout N … 2>/dev/null || true`
  shape in focus.sh:144,152 suggests degradation is silent by construction.)**
  confidence: 3
  disposition: answered
  rationale: Confirmed and worse than suspected — silent at four layers: `is_index_ready()` row-count only, `built_at` reports open time not build time (`:206`), zero doctor/audit rail, and the caller discards stderr. F3.

- **IW-4: Is the store's content reconstructible from the git-tracked corpus, or
  is it an authoritative store whose loss destroys state?** This decides whether
  the reliability posture should be "cache" or "database" — they warrant opposite
  designs, and conflating them is the usual source of over-engineering here.
  confidence: 3
  disposition: answered
  rationale: Pure derived cache — gitignored (`.gitignore:97`), rebuildable from tracked corpus by `build_index()`. So freshness is the reliability property that matters; durability/backup is not. Rules out slices aimed at persistence.

- **IW-5: What does a *consumer* project get today — does the vendored client
  assume a store that only exists on this host?**
  confidence: 3
  disposition: answered
  rationale: Consumers get nothing — `/003-NTB-ATC-Plugin` has no index file, and nothing in `fw init`/`upgrade` builds one. Recall is a silent no-op there. D-B.

- **IW-6: What does "absolute isolation" buy, and what does it cost?** Per-project
  store vs shared instance: isolation prevents cross-project recall bleed, but the
  framework's own §TermLink note argues the inverse for machine-wide substrates.
  Which model applies here is the question, not which is better in general.
  confidence: 3
  disposition: dissolved
  rationale: Already per-project by construction (`$PROJECT_ROOT/.context/working/`, `bin/fw:902` exports globally) — nothing to buy. The residual is direction of failure, not topology: unset `PROJECT_ROOT` falls back to the framework's own index rather than to none. F4/D-A.

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

**Recommendation:** GO — on freshness + observability. Explicit NO-GO on migration.

**Rationale:**

The migration this inception was asked to evaluate is already done and needs no work: the store is an embedded sqlite-vec file at `$PROJECT_ROOT/.context/working/fw-vec-index.db`, per-project by construction, gitignored, no server. What measurement found instead is that the substrate has been silently serving ~15% recall since 2026-03-10, because its staleness check resets its own clock (`web/embeddings.py:206` stamps `_db_built_at` on the *reuse* path, making `STALE_SECONDS` unreachable and `build_index()` at `:212` dead). Three independent instruments and one error-discarding caller all report healthy while this is true. That is a live antifragility defect with a known root cause and a small fix, and it outranks any topology change. Recording both verdicts because the NO-GO answers the question actually asked.

**Evidence:**

- No Qdrant in live source — store is sqlite-vec (`web/embeddings.py:1,52`; `web/config.py:45`). The four "qdrant" hits are two stale comments (`focus.sh:140,148`) and two regex literals.
- Index mtime **2026-03-10**; highest indexed task **T-409** vs current T-3004.
- Coverage **~15%** — 1,341 of 9,021 corpus docs (completed 373/2643, episodic 403/2645, handovers 295/1697, reports 99/643, fabric 136/1045, active 35/348).
- Root cause reproduced live: `index_stats()['built_at']` returned *14 seconds ago* while the file's mtime was March.
- `is_index_ready()` (`:175-190`) checks row count, never corpus correspondence.
- Zero doctor/audit rail for the index; zero cron rebuild entries.
- `focus.sh:144,152` — `2>/dev/null || true` on the only path that runs every task start, collapsing "dead store" / "stale store" / "no hits" into one silent outcome.
- `PROJECT_ROOT` unset resolves to the framework's own index (measured both branches); `.mcp.json` launches the `fw` server with `env: {}`. D-A.
- `/003-NTB-ATC-Plugin` has no index file at all. D-B.

Full artefact, slice table, and dialogue log: `docs/reports/T-3004-vector-memory-substrate.md`

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

**Rationale**: The migration this inception was asked to evaluate is already done and needs no work: the store is an embedded sqlite-vec file at `$PROJECT_ROOT/.context/working/fw-vec-index.db`, per-project by construction, gitignored, no server. What measurement found instead is that the substrate has been silently serving ~15% recall since 2026-03-10, because its staleness check resets its own clock (`web/embeddings.py:206` stamps `_db_built_at` on the *reuse* path, making `STALE_SECONDS` unreachable and `build_index()` at `:212` dead). Three independent instruments and one error-discarding caller all report healthy while this is true. That is a live antifragility defect with a known root cause and a small fix, and it outranks any topology change. Recording both verdicts because the NO-GO answers the question actually asked.

**Date**: 2026-08-15T05:29:43Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-15T05:19:37Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-08-15T05:29:43Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The migration this inception was asked to evaluate is already done and needs no work: the store is an embedded sqlite-vec file at `$PROJECT_ROOT/.context/working/fw-vec-index.db`, per-project by construction, gitignored, no server. What measurement found instead is that the substrate has been silently serving ~15% recall since 2026-03-10, because its staleness check resets its own clock (`web/embeddings.py:206` stamps `_db_built_at` on the *reuse* path, making `STALE_SECONDS` unreachable and `build_index()` at `:212` dead). Three independent instruments and one error-discarding caller all report healthy while this is true. That is a live antifragility defect with a known root cause and a small fix, and it outranks any topology change. Recording both verdicts because the NO-GO answers the question actually asked.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b4fb5547
- **Timestamp:** 2026-08-15T05:29:44Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-3
     - evidence: `IW-3 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-4
     - evidence: `IW-4 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  3. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-5
     - evidence: `IW-5 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-0687918a
- **Timestamp:** 2026-08-15T05:29:44Z
- **Overall:** CONTRADICTED
- **Claims:** 5

| Claim | Type | Status |
|-------|------|--------|
| `web/embeddings.py:206` | file_line | ✓ pass |
| `web/embeddings.py:1,52` | file | ✗ fail — file not found at PROJECT_ROOT |
| `web/config.py:45` | file_line | ✓ pass |
| `docs/reports/T-3004-vector-memory-substrate.md` | file | ✓ pass |
| `T-409` | task | ✓ pass |

### 2026-08-15T05:29:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
