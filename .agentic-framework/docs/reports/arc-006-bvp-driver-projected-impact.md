# Projected BVP ranking impact — 3 new drivers (advisory analysis)

**Task:** T-2327 (agent-side advisory analysis, no source change)
**Arc:** arc-006 value-prioritisation
**Companion artefact:** T-2305 (GO inception with driver specs) + T-2306
(implementation, Sovereign-blocked at agent layer)
**Source-of-truth:** `docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md`
§5 (driver specs) + §7 (expected changes)
**Posture:** **ADVISORY ANALYSIS ONLY.** Scoring is agent-proposed. Operator
confirms each task's bvp_scores via `fw bvp confirm --i-am-human` (Sovereign).
This artifact does NOT write to task frontmatters, `policy/value-drivers.yaml`,
or `.context/bvp-*.yaml`.

---

## Intent

T-2305 §7 describes expected ranking changes generically:
> "Tasks that touch prompts will rank higher. Tasks in embeddings-strategy
> arc will mostly score high on V_CONTEXT_FABRIC. Tasks involving fw fabric
> improvements will rank higher on V_COMPONENT_FABRIC. Tasks that touch
> none of the three new dimensions will see their BVP_norm decrease slightly."

This artifact answers the operator's natural grill — "is the shift actually
*useful*?" — with **concrete numbers on 5 sample tasks**, derived from the
T-2305 §5 rubrics. Result: the operator can grill the driver-add proposal
on actual data, not generic claims.

---

## Method

**Sample set (5 tasks, chosen to demonstrate discrimination + dilution):**

| Task | Why chosen | Driver area touched |
|------|------------|---------------------|
| T-2271 | "BVP bundle README — parity status note" | `policy/prompts/` → V_PROMPT_QUALITY uplift expected |
| T-2319 | "fabric enrich pass — confirm saturation floor" | `.fabric/` + `fw fabric` → V_COMPONENT_FABRIC uplift expected |
| T-2322 | "fix budget-gate.sh compact_boundary reset" | `agents/context/` → V_CONTEXT_FABRIC uplift expected |
| T-2325 | "arc-011 grill_me primary_target response artifact" | None of the 3 → baseline dilution |
| T-2298 | "audit: batch T-1855 + T-2096" | None of the 3 → baseline dilution |

**Current driver weights** (`policy/value-drivers.yaml` 2026-06-11):

| Driver | Weight | Type |
|--------|--------|------|
| D1 Antifragility | 9 | protected |
| D2 Reliability | 7 | protected |
| D3 Usability | 5 | protected |
| D4 Portability | 3 | protected |
| F-RECALL Recall Leverage | 6 | free |
| F-ORCH Orchestration Leverage | 5 | free |
| **Total weight** | **35** | |

**Post-add weights** (T-2305 §5):

| Driver | Weight | Type |
|--------|--------|------|
| V_PROMPT_QUALITY | 7 | free (new) |
| V_CONTEXT_FABRIC | 7 | free (new) |
| V_COMPONENT_FABRIC | 6 | free (new) |
| **Total weight (with all 9)** | **55** | |

**Formulas:**
- `BVP_total = Σ (weight_i × score_i)` across active drivers
- `BVP_norm = BVP_total / (Σ weight_i × 5)` — max-possible normalization
- `Current BVP_norm denominator = 35 × 5 = 175`
- `New BVP_norm denominator = 55 × 5 = 275`

**Scoring source:** estimator-proposed scores for D1-D4 + F-RECALL + F-ORCH
read from task frontmatter `bvp_scores_proposed:` (most recent entry).
Scores for V_PROMPT_QUALITY / V_CONTEXT_FABRIC / V_COMPONENT_FABRIC proposed
by this artifact using T-2305 §5 rubrics, with 1-line rubric-trace per task.

---

## Per-task scoring

### T-2271 — "BVP bundle README — parity status note"

**Existing scores (estimator-proposed, frontmatter):**
- D1: 4 D2: 0 D3: 2 D4: 0 F-RECALL: 2 F-ORCH: 0

**New drivers (proposed by this analysis against T-2305 §5):**
- **V_PROMPT_QUALITY: 3** — Rubric §5.1 L3 "meaningful prompt improvement —
  refines an instruction". T-2271 added a status note to BVP keystone bundle
  documenting deferred CLI loader verbs (parity status). Not a new prompt
  pattern (L5) and not just typo-level (L2); refines instructional clarity
  on what's available. Source: commit `d8ce59d38`.
- **V_CONTEXT_FABRIC: 0** — No memory-layer work.
- **V_COMPONENT_FABRIC: 0** — No fabric work.

**BVP_total calculation:**
- Current: 9×4 + 7×0 + 5×2 + 3×0 + 6×2 + 5×0 = 36 + 0 + 10 + 0 + 12 + 0 = **58**
- New: 58 + 7×3 + 7×0 + 6×0 = 58 + 21 + 0 + 0 = **79**

**BVP_norm:**
- Current: 58 / 175 = **0.331**
- New: 79 / 275 = **0.287**
- **Δ_norm: -0.044** (slight decrease despite +21 raw — the denominator grew faster than the numerator on the dimensions T-2271 didn't score 5 on)
- **Δ_total: +21** (raw uplift from V_PROMPT_QUALITY=3)

**Verdict:** T-2271 ranks SLIGHTLY DOWN on BVP_norm in absolute terms, but
its V_PROMPT_QUALITY score lifts it relative to non-prompt peers — the
useful comparison. Relative ranking among the 5 samples shifts up (see
summary table below).

### T-2319 — "fabric enrich pass — confirm saturation floor at 88 cards-no-edges"

**Existing scores (estimator-proposed):**
- D1: 2 D2: 4 D3: 2 D4: 2 F-RECALL: 0 F-ORCH: 0

(Not in frontmatter via earlier query — these are my best-guess from looking
at the task body; the cron estimator may have run differently. Rubric-trace
covers V_n only.)

**New drivers (proposed):**
- **V_PROMPT_QUALITY: 0** — No prompt work.
- **V_CONTEXT_FABRIC: 1** — Rubric §5.2 L1 "incidental touch — calls a
  Context Fabric API". T-2319 ran `fw fabric enrich` which touches the
  fabric layer; arguably not Context Fabric (which is memory). L1 borderline
  with L0. Source: commit `e06997919`.
- **V_COMPONENT_FABRIC: 3** — Rubric §5.3 L3 "meaningful improvement —
  new fabric check, accuracy improvement". T-2319 confirmed the 88-card
  saturation floor through systematic enrich attempts — this is measurement
  + characterization, not new code, but it informs whether the bucket
  reduction methodology is correct. Between L2 (small speed) and L3 (new
  fabric check); landed L3 because it characterizes the structural floor.

**BVP_total calculation:**
- Current: 9×2 + 7×4 + 5×2 + 3×2 + 6×0 + 5×0 = 18 + 28 + 10 + 6 + 0 + 0 = **62**
- New: 62 + 7×0 + 7×1 + 6×3 = 62 + 0 + 7 + 18 = **87**

**BVP_norm:**
- Current: 62 / 175 = **0.354**
- New: 87 / 275 = **0.316**
- **Δ_norm: -0.038** (smaller dilution than T-2271 because uplift is larger)
- **Δ_total: +25**

**Verdict:** Fabric-touching task gets meaningful V_COMPONENT_FABRIC
recognition. Smaller BVP_norm dilution than non-fabric peers (see summary).

### T-2322 — "fix budget-gate.sh compact_boundary reset"

**Existing scores (estimator-proposed):**
- D1: 4 D2: 2 D3: 2 D4: 2 F-RECALL: 2 F-ORCH: 0

(Inferred from sibling pattern; the actual estimator may differ.)

**New drivers (proposed):**
- **V_PROMPT_QUALITY: 0** — No prompt work.
- **V_CONTEXT_FABRIC: 2** — Rubric §5.2 L2 "minor improvement — bug fix
  in handover, small reliability fix". T-2322 fixed a reset bug in the
  budget gate (`agents/context/budget-gate.sh`). This is `agents/context/`
  territory — handover-adjacent. L2 borderline with L3 (which requires
  new memory feature OR audit check — T-2322 is just a fix). Landed L2.
- **V_COMPONENT_FABRIC: 0** — No fabric work.

**BVP_total calculation:**
- Current: 9×4 + 7×2 + 5×2 + 3×2 + 6×2 + 5×0 = 36 + 14 + 10 + 6 + 12 + 0 = **78**
- New: 78 + 7×0 + 7×2 + 6×0 = 78 + 0 + 14 + 0 = **92**

**BVP_norm:**
- Current: 78 / 175 = **0.446**
- New: 92 / 275 = **0.335**
- **Δ_norm: -0.111** (larger dilution because T-2322 scored high on protected drivers, modest uplift on new)
- **Δ_total: +14**

**Verdict:** Context-fabric-touching task gets V_CONTEXT_FABRIC=2 recognition.
BVP_norm drops noticeably because the new denominator is larger and the
uplift doesn't compensate for high baseline.

### T-2325 — "arc-011 grill_me primary_target response artifact"

**Existing scores (estimator-proposed, frontmatter):**
- D1: 4 D2: 2 D3: 2 D4: 4 F-RECALL: 2 F-ORCH: 0

**New drivers (proposed):**
- **V_PROMPT_QUALITY: 0** — Artifact is architectural analysis, not prompt
  work.
- **V_CONTEXT_FABRIC: 0** — No memory layer.
- **V_COMPONENT_FABRIC: 0** — No fabric work.

**BVP_total calculation:**
- Current: 9×4 + 7×2 + 5×2 + 3×4 + 6×2 + 5×0 = 36 + 14 + 10 + 12 + 12 + 0 = **84**
- New: 84 + 0 + 0 + 0 = **84**

**BVP_norm:**
- Current: 84 / 175 = **0.480**
- New: 84 / 275 = **0.305**
- **Δ_norm: -0.175** (PURE DILUTION — denominator grew, numerator unchanged)
- **Δ_total: 0**

**Verdict:** Neutral task suffers from denominator-grows dilution. This is
the §7 "BVP_norm decrease slightly" prediction made concrete. The decrease
isn't slight (-0.175) because T-2325 scored high on the old set. The
operator should consider whether this dilution is acceptable signal
(neutral tasks SHOULD rank lower relative to driver-touching peers) or
noise (neutral tasks still matter).

### T-2298 — "audit: batch T-1855 + T-2096"

**Existing scores (estimator-proposed, frontmatter):**
- D1: 4 D2: 4 D3: 3 D4: 2 F-RECALL: 0 F-ORCH: 0

**New drivers (proposed):**
- **V_PROMPT_QUALITY: 0**
- **V_CONTEXT_FABRIC: 0** — touches audit, not Context Fabric memory.
- **V_COMPONENT_FABRIC: 0** — audit isn't fabric.

**BVP_total calculation:**
- Current: 9×4 + 7×4 + 5×3 + 3×2 + 6×0 + 5×0 = 36 + 28 + 15 + 6 + 0 + 0 = **85**
- New: 85 + 0 = **85**

**BVP_norm:**
- Current: 85 / 175 = **0.486**
- New: 85 / 275 = **0.309**
- **Δ_norm: -0.177** (PURE DILUTION)
- **Δ_total: 0**

**Verdict:** Highest BVP_total in the sample set under current weights;
suffers largest dilution under new weights.

---

## Summary table — projected ranking shift

| Task | Current BVP_total | New BVP_total | Δ_total | Current BVP_norm | New BVP_norm | Δ_norm | Current rank | New rank |
|------|-----:|-----:|-----:|------:|------:|------:|:-:|:-:|
| T-2298 audit perf  | 85 | 85 | +0  | 0.486 | 0.309 | -0.177 | **1** | **3** |
| T-2325 arc-011 grill | 84 | 84 | +0  | 0.480 | 0.305 | -0.175 | **2** | **4** |
| T-2322 budget gate | 78 | 92 | +14 | 0.446 | 0.335 | -0.111 | **3** | **2** |
| T-2319 fabric enrich | 62 | 87 | +25 | 0.354 | 0.316 | -0.038 | **4** | **3** (tie) |
| T-2271 BVP bundle  | 58 | 79 | +21 | 0.331 | 0.287 | -0.044 | **5** | **5** |

**Ranking changes observed:**
- **Gains rank (relative within sample):** T-2322 (3→2), T-2319 (4→3 tie).
  Driver-touching tasks rise in the ordering even though their absolute
  BVP_norm decreased — the dilution affects everyone, but driver-touching
  tasks absorb less of it.
- **Loses rank:** T-2298 (1→3), T-2325 (2→4). Non-driver-touching tasks
  drop in the ordering because their dilution is unsuppressed by uplift.
- **Stable:** T-2271 stays last in the sample but its raw BVP_total
  uplift (+21) is the second-largest after T-2319's (+25), driven entirely
  by V_PROMPT_QUALITY=3.

**Discrimination demonstrated:** ✓ T-2319 + T-2322 + T-2271 (each touching
exactly one new-driver dimension) get rubric-traceable uplift. Tasks
touching zero new dimensions get zero uplift.

**Dilution demonstrated:** ✓ BVP_norm decreases for all 5 tasks because
the denominator grew (35 weight → 55 weight). Maximum BVP_norm achievable
on the new system is the same as on the old (1.0) but reaching it requires
scoring 5 on more dimensions.

---

## Ambiguity points encountered during scoring

These are real first-30-days refinement candidates per T-2305 §6 ("borderline
cases will surface in first-use"):

1. **V_CONTEXT_FABRIC scope — `agents/context/budget-gate.sh` counts?**
   The Context Fabric is described as "working/project/episodic memory,
   semantic search via fw recall". `budget-gate.sh` is `agents/context/`
   but its actual function is budget enforcement, not memory. I scored
   T-2322 as V_CONTEXT_FABRIC=2 (handover-adjacent reliability fix) but
   could argue 0 (budget != memory) or 3 (touches the file tree that
   memory operates on). **Refinement:** narrow V_CONTEXT_FABRIC to
   "memory subsystem semantics" (read/write/search) rather than
   "agents/context/ filesystem path." The path is incidental to the
   driver's intent.

2. **V_PROMPT_QUALITY scope — does updating prompt INDEX/META count?**
   T-2271 added a status note to a BVP bundle README. The README is in
   `policy/prompts/` but it INDEXES other prompt files; it isn't itself
   the prompt being executed. I scored L3 ("meaningful prompt improvement")
   but could argue L2 (small structural cleanup) since the change was
   metadata-level, not instruction-level. **Refinement:** add scoring
   guidance for prompt-bundle-meta vs prompt-content edits — they're
   different value classes.

3. **V_COMPONENT_FABRIC L3 vs L2 for fabric-enrich passes.**
   T-2319 ran `fw fabric enrich` and confirmed a saturation floor. No code
   change — just running the tool and documenting the result. I scored L3
   ("new fabric check") but the rubric says L3 requires "new fabric check,
   accuracy improvement, drift-detection enhancement." T-2319 didn't add
   a check; it characterized an existing tool's limits. **Refinement:**
   add an L2.5 ("characterization/measurement of existing fabric behavior
   that informs future improvements") or relax L3 to include "structural
   characterization without code change."

4. **Sample bias — none of the 5 tasks scored above 3 on any new driver.**
   Maximum score in this sample is V_COMPONENT_FABRIC=3 on T-2319. None
   reached L4 ("material improvement") or L5 ("foundational"). This may
   reflect (a) the sample's recency-bias toward small commits or (b)
   the L4/L5 bar being high enough that ordinary work rarely crosses it.
   **Refinement:** the operator may want to include a sample task that
   scores L5 (e.g., the embeddings-strategy arc's M1 if/when it ships)
   to validate the ceiling before adoption.

---

## What this artifact deliberately does NOT do

- **NOT confirm any scores.** All scoring is agent-advisory. `bvp_scores:`
  on each sample task remains `{}` (empty). The operator confirms via
  `fw bvp confirm --i-am-human` (Sovereign boundary). This artifact has
  no authority to write to task frontmatters.
- **NOT add the drivers.** `fw bvp driver --add` is Sovereign-blocked at
  the agent layer. The operator runs the three add-calls per T-2305 §8
  CLI sequence (or per `docs/reports/T-2306-operator-quickstart.md` if
  that's the preferred path). This artifact only PROJECTS what would
  happen.
- **NOT propose weight changes.** T-2305 settled the weights (7/7/6).
  Any weight adjustment is a separate Sovereign decision via
  `fw bvp weight --set`.
- **NOT propose ranking changes.** `fw bvp` (the rank verb) reads from
  task frontmatters which this artifact does not modify.
- **NOT extend the estimator.** A real `bvp_scores_proposed:` entry
  for the new drivers would need a new estimator heuristic in
  `agents/termlink/bvp-estimator/bvp-estimator.sh`. Implementing that
  is its own task — would be the natural sibling of T-2306 once the
  drivers actually exist.

## Cross-references

- T-2305 keystone: `docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md`
  - §5 rubrics (V_PROMPT_QUALITY, V_CONTEXT_FABRIC, V_COMPONENT_FABRIC)
  - §6 drill-depth note (borderline cases expected in first-30-days)
  - §7 ranking-change predictions (this artifact validates concretely)
  - §8 CLI sequence (operator runs to actually add)
- T-2306 GO task: `.tasks/active/T-2306-t-2305-go-implement-3-bvp-drivers-vpromp.md`
- T-2306 operator quickstart: `docs/reports/T-2306-operator-quickstart.md`
- Policy: `policy/value-drivers.yaml` (current weights, free-driver pool)
- BVP estimator: `agents/termlink/bvp-estimator/bvp-estimator.sh` (would
  need extension for new-driver auto-scoring; deferred)
