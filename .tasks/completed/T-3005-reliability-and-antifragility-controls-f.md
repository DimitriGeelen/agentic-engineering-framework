---
id: T-3005
name: "reliability and antifragility controls for the vector memory substrate"
description: >
  Inception: reliability and antifragility controls for the vector memory substrate

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-08-15T05:33:05Z
last_update: 2026-08-15T05:42:47Z
date_finished: 2026-08-15T05:42:47Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-08-15T05:34:26Z'
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

# T-3005: reliability and antifragility controls for the vector memory substrate

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

### Critique of the T-3004 RCA (the ask: review it critically)

- **IW-1: Is `embeddings.py:206` the root cause, or a symptom of something T-395
  did?** T-395 added *both* `STALE_SECONDS` (rebuild when old) and the reuse branch
  (avoid rebuilding). Those two intents contradict; the reuse branch won. If so the
  root cause is not "a line resets a clock" but "a performance fix silently removed
  a capability that sat next to it, and nothing detected the loss" — a materially
  different and more transferable class.
  confidence: 3
  disposition: answered
  rationale: Confirmed — T-395 added both `STALE_SECONDS` and the reuse branch that defeats it in one change. `:206` is the mechanism; the class is capability-loss-without-detection (sibling of L-352/G-064). C2.

- **IW-2: Is the recall path actually running?** T-3004 asserted "runs on every
  task start" from a code read, never from observation. Three `work-on` invocations
  in this session printed *Related knowledge* but no *Task Briefing*. Falsification
  test queued: time `lib/ask.py` against focus.sh's 15s budget.
  confidence: 3
  disposition: answered
  rationale: FALSIFIED the T-3004 claim. rc=1 in 1s with `503 max pending requests` — not slow, hard-failing. And the visible recall is `memory-recall.py` (yaml+re over learnings.yaml), not the vector store at all. C1.

- **IW-3: Is 15% coverage merely reduced recall, or actively misleading recall?**
  The indexed 15% is the *oldest* slice, so recall may confidently surface
  superseded patterns. T-3004 asserted harm without measuring it. If recall is
  wrong rather than thin, urgency and mitigation both change.
  confidence: 3
  disposition: answered
  rationale: PARTLY RETRACTED. SQL probes: 0 hits for the superseded label, and 0 for worktree/fw integrate/arc_id/BVP/headline_mechanic. The harm is omission, not contradiction. Residual "omission→fabrication downstream" kept explicitly as an unmeasured hypothesis. C4.

### Designing the controls

- **IW-4: What is the freshness signal, given `built_at` is untrustworthy?** A
  persisted corpus fingerprint in the DB is the candidate; file mtime is the cheap
  fallback. The control must not depend on the field the RCA just discredited.
  confidence: 2
  disposition: answered
  rationale: Design fixed on a persisted `corpus_manifest` table (per-category counts, max mtime, corpus hash) written at reindex; doctor recomputes and diffs. `built_at` is excluded by constraint 1. Not yet built — hence confidence 2.

- **IW-5: How do we detect "is being used" as distinct from "is present"?**
  Zero-consumer substrates read healthy (L-352, G-064 — five months hidden). Usage
  needs its own counter; presence checks cannot supply it.
  confidence: 2
  disposition: answered
  rationale: Append-only `recall-telemetry.jsonl` (ts, query hash, n_hits, top_score, latency, outcome); zero rows in 7 days is the G-064 zero-consumer signal. Doubles as the miss-log feeding antifragile reindex priority. Designed, not built.

- **IW-6: How do we make degradation loud without creating alarm fatigue?** A
  consumer with no index is *expected*-degraded, not broken. If every task start in
  every consumer warns, someone re-adds `2>/dev/null` and we regress. The control
  needs an expected-degraded state distinct from a fault.
  confidence: 2
  disposition: answered
  rationale: Tri-state adopted as design constraint 4 — `OK` / `EXPECTED-DEGRADED` (fresh consumer, no local Ollama) / `FAULT` (index exists but stale; provider up but erroring). Only FAULT is loud. Thresholds unset until slice 4.

- **IW-7: What is the positive control?** Every instrument in T-3004 failed by
  never going red. A canary — a token written at reindex and required to be
  retrievable — converts unfalsifiable prose output into a binary check. Needs to
  be watched failing before it counts as a control.
  confidence: 2
  disposition: answered
  rationale: Adopted as the keystone (slice 2): reindex writes `FWCANARY-<epoch>`; health requires semantic retrieval AND epoch match, exercising embed→store→retrieve end-to-end. Must be observed red in a test before it counts (constraint 3). Designed, not built.

- **IW-8: Where does isolation actually belong?** Surfaced mid-investigation and
  not anticipated at filing: T-3004 answered "the store", which is already
  isolated. The provider was never examined.
  confidence: 3
  disposition: answered
  rationale: Relocated to the provider. Ollama is `0.0.0.0`, unauthenticated, `MAX_LOADED_MODELS=1`, `KEEP_ALIVE=30m`, with live clients on `.170`/`.171`/`.129` renewing the chat lease indefinitely. The store needs no isolation; the provider has none. Reopens what T-3004 closed.

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

**Recommendation:** GO — on the 7-slice sequence, slice 1 landing and verified alone before anything is built on it.

**Rationale:**

The critique found five defects in the T-3004 RCA, three of which change the conclusion. The decisive one: T-3004's headline fix would have shipped a repair with no observable effect. Rebuilding the index while every embedding request returns 503 changes nothing a user can feel, and the completion gate would have passed it green — the same false-green class the fix exists to end. Semantic recall is not degraded to 15%; it is at **0%**, because the embedding provider rejects every request. The cause is not ours alone: Ollama is an unauthenticated fleet-shared singleton with one model slot, and three other hosts keep the chat model's lease renewed. So slice 1 is availability of the embed path, and it must be verified working before slices 2-7 assume retrieval functions at all. GO is on the sequence, not on the list as a batch.

**Evidence:**

- Briefing path measured: rc=1 in 1s, `503 maximum pending requests exceeded`, 3/3 probes — a hard failure fully swallowed by `2>/dev/null || true` in `focus.sh:152`
- `memory-recall.py` imports `yaml`/`re` over `learnings.yaml` — the recall that visibly works is keyword matching, not the vector store; T-3004 credited its output to the broken path
- `/api/ps`: `gemma4:latest` holds the single slot; lease observed extending 07:49:44 → 07:53:12 mid-investigation
- `OLLAMA_HOST=0.0.0.0`, `KEEP_ALIVE=30m`, `MAX_LOADED_MODELS=1`; clients `.170`×4, `.171`×3, `.129`×1 — contention originates off-host
- SQL probes: 0 hits for worktree / fw integrate / arc_id / BVP / headline_mechanic, and 0 for the superseded label — partly retracting T-3004's "actively misleading" claim to omission-not-contradiction
- T-395 introduced `STALE_SECONDS` and the reuse branch defeating it in one change — root cause is capability-loss-without-detection, not a stray line

**Amendment the operator should see:** T-3004 closed the isolation question as a solved non-issue. That holds for the store and fails for the system. The provider has no isolation at all, and it is the component currently down. Isolation is reopened at the provider layer (slice 1 option iv), not the store.

Full critique, control architecture, and sequencing: `docs/reports/T-3005-vector-substrate-controls.md`

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

**Rationale**: The critique found five defects in the T-3004 RCA, three of which change the conclusion. The decisive one: T-3004's headline fix would have shipped a repair with no observable effect. Rebuilding the index while every embedding request returns 503 changes nothing a user can feel, and the completion gate would have passed it green — the same false-green class the fix exists to end. Semantic recall is not degraded to 15%; it is at **0%**, because the embedding provider rejects every request. The cause is not ours alone: Ollama is an unauthenticated fleet-shared singleton with one model slot, and three other hosts keep the chat model's lease renewed. So slice 1 is availability of the embed path, and it must be verified working before slices 2-7 assume retrieval functions at all. GO is on the sequence, not on the list as a batch.

**Date**: 2026-08-15T05:42:46Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-15T05:34:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-08-15T05:42:46Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The critique found five defects in the T-3004 RCA, three of which change the conclusion. The decisive one: T-3004's headline fix would have shipped a repair with no observable effect. Rebuilding the index while every embedding request returns 503 changes nothing a user can feel, and the completion gate would have passed it green — the same false-green class the fix exists to end. Semantic recall is not degraded to 15%; it is at **0%**, because the embedding provider rejects every request. The cause is not ours alone: Ollama is an unauthenticated fleet-shared singleton with one model slot, and three other hosts keep the chat model's lease renewed. So slice 1 is availability of the embed path, and it must be verified working before slices 2-7 assume retrieval functions at all. GO is on the sequence, not on the list as a batch.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e8dcc71b
- **Timestamp:** 2026-08-15T05:42:48Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 4

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-3
     - evidence: `IW-3 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-4
     - evidence: `IW-4 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  3. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-6
     - evidence: `IW-6 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  4. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-7
     - evidence: `IW-7 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-5d21d138
- **Timestamp:** 2026-08-15T05:42:48Z
- **Overall:** CONFIRMED
- **Claims:** 3

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/T-3005-vector-substrate-controls.md` | file | ✓ pass |
| `T-3004` | task | ✓ pass |
| `T-395` | task | ✓ pass |

### 2026-08-15T05:42:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
