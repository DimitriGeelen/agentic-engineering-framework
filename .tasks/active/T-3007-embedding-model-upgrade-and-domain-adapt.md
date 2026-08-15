---
id: T-3007
name: "embedding model upgrade and domain adaptation from AEF's own corpus"
description: >
  Inception: embedding model upgrade and domain adaptation from AEF's own corpus

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-15T05:55:24Z
last_update: 2026-08-15T05:57:25Z
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
  - ts: '2026-08-15T05:57:25Z'
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

# T-3007: embedding model upgrade and domain adaptation from AEF's own corpus

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

- **IW-1: Is the current model's context ceiling really 512 tokens, and are our
  chunks being truncated?**
  confidence: 1
  disposition: deferred
  rationale: Attributed claim, checkable, not yet checked. Chunker is 1500 chars (~375 tok) plus a prepended title, so longer chunks sit near the ceiling. If true the index is lossy as well as stale — a third defect on top of T-3004's two. Step A.

- **IW-2: Should the model switch be a standalone migration, or ride the reindex
  T-3005 already owes?**
  confidence: 3
  disposition: answered
  rationale: Ride it. `embeddings.py:211` binds the vec0 schema to `EMBEDDING_DIM` (`:76`), so any dimension change is migration + full re-embed. Two reindexes vs one — and separating them invalidates slice 2's calibrated thresholds mid-arc.

- **IW-3: Is there enough data to adapt the model on our own corpus?**
  confidence: 3
  disposition: answered
  rationale: Not as pairs. 21k chunks is not 21k (query, document) pairs, and `qa_feedback.db` holds 1 row. Synthetic generation is the only near-term path to the data floor, not one option among several.

- **IW-4: Is domain adaptation actually unblocked, as the research argues?**
  confidence: 3
  disposition: answered
  rationale: No — the blocker moved rather than cleared. Synthesis needs an LLM pass over 21k chunks, generation is starved on the shared host (T-3006), and the CPU sidecar cannot serve a 14B model at that volume. Blocked on the GPU-slot decision, not on data.

- **IW-5: Adapter before or after the model switch?**
  confidence: 3
  disposition: answered
  rationale: After. An adapter trained against the current base is discarded when the base changes; the source's ordering spends that work twice.

- **IW-6: Which model, on what evidence?**
  confidence: 1
  disposition: deferred
  rationale: Qwen3-Embedding-0.6B is the attributed favourite, but every benchmark figure in the source is unverified. If the choice turns on the Qwen3-vs-BGE-M3 margin it should be measured on our own corpus with a small retrieval eval set, not taken from MTEB.

- **IW-7: Should the reranker change too?**
  confidence: 2
  disposition: deferred
  rationale: Not yet. The current reranker's contribution to result quality is unmeasured, and swapping an unmeasured component makes any later regression unattributable. Revisit once the T-3005 controls can show a score distribution.

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
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

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

Research supplied by the operator (external agent) argues for Qwen3-Embedding-0.6B over the current nomic-embed-text-v2-moe (+8-9 MTEB, 512->32K context, Apache-2.0, ~0.5GB more VRAM) and for domain adaptation via synthetic query generation plus a query-side adapter. Local claims verified in-tree: EMBEDDING_DIM=768 is hardcoded AND binds the vec0 schema, chunker targets 1500 chars (~375 tok) against the current model's 512-tok ceiling, and qa_feedback has no context_chunk_ids column. GO because the switch is close to free if it rides the reindex that T-3005 slices 3/5 already require, and expensive as a standalone migration later — the sequencing is the decision. Benchmark figures are attributed, not independently verified.

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-15T05:57:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
