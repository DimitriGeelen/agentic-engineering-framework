---
id: T-1921
name: "BVP T-NEW-6: scoring rubric document (policy/bvp-scoring-rubric.md) — per-driver
  criteria + worked examples"
description: >
  Write the rubric the TermLink estimator follows (T-1922 consumes this). Per-driver
  scoring criteria, worked examples from .tasks/completed/, calibration cases. R2
  (rubric bias) mitigated by [REVIEW] Human AC; R9 (rubric reversibility risk) acknowledged.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bvp, build, slice-6, rubric, docs]
components: [policy/bvp-scoring-rubric.md]
related_tasks: [T-1915, T-1916, T-1922]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: '2026-08-16T22:24:49Z'
date_finished: 2026-05-19T17:37:49Z
bvp_scores_proposed:
  - ts: '2026-05-19T17:55:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 3
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=3 
      (body:prompt-meaningful); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      estimator-fidelity: 0
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 3
      F1: 0
      F2: 0
    rationale: estimator-fidelity=0 (no-signal); D1=2 (body:learning-ref); D2=0 
      (no-signal); D3=0 (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=3 (body:prompt-meaningful); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1921: BVP T-NEW-6 — `policy/bvp-scoring-rubric.md`

## Context

The rubric is "the reusable state the worker preloads" (D4 — F4-deep classifier framing). Worked examples are versioned content; treat with same care as code (R9 reversibility risk).

**Source:** Handoff §7 T-NEW-6; artefact §6 row 5; §2 R2/R9; §4 F4-deep classifier framing.

**The [REVIEW] Human AC on this slice is load-bearing** — do NOT classify as [REVIEWER] per R2 mitigation (taste call is human, not static scan).

## Acceptance Criteria

### Agent
- [x] `policy/bvp-scoring-rubric.md` exists at repo root (`policy/` directory, not repo root — convention with T-1917 + T-1920 puts BVP policy artefacts under `policy/`)
- [x] Document has sections for each protected driver (D1 Antifragility, D2 Reliability, D3 Usability, D4 Portability) — each with a "what does score N mean?" rubric for N in 0..5
- [x] Document has a "free drivers — general criteria" section for drivers added via `fw bvp driver --add`
- [x] At least 3 worked examples per protected driver, drawn from real completed tasks in `.tasks/completed/` — citing task IDs (T-1730, T-1671, T-1550 / T-1771, T-1550, T-1850 / T-609, T-1257, T-679 / T-1633, T-1542, T-1144) and naming the structural effect
- [x] Document includes a determinism statement: same task body scored twice in separate sessions at low temperature must produce scores within ±1 on every driver

### Human
- [x] [REVIEW] Worked examples reflect AEF's actual values, not hallucinated framings (R2 mitigation, load-bearing — do NOT downgrade to [REVIEWER])
  **Steps:**
  1. Open `policy/bvp-scoring-rubric.md`; read each worked example end-to-end
  2. For each example, verify the framing matches how *you* would have scored the task
  3. Pay particular attention to whether any driver is systematically over- or under-scored across examples
  **Expected:** No examples produce systematic bias in either direction
  **If not:** Revise the rubric before T-1922 starts (the estimator inherits the rubric's biases)

## Verification

test -f policy/bvp-scoring-rubric.md
[ "$(wc -l < policy/bvp-scoring-rubric.md)" -ge 200 ]
# Drivers are h2 sections (## D1..D4) in the rubric — count via capture-first (L-387).
sections=$(grep -c "^## D[1-4]" policy/bvp-scoring-rubric.md); [ "$sections" = "4" ]

## Evolution

### 2026-05-19 — Heading depth: h2 not h3 for driver sections
- **What changed:** Verification command checked `^### D[1-4]` (h3) but the rubric uses h2 (`## D1`, `## D2`, …) for top-level driver sections — h3 would have buried them under an unnamed h2 parent. Updated the Verification command to match the rubric structure.
- **Plan impact:** None — Markdown convention preference. Documented for future verification authors.
- **Triggered:** None.

### 2026-05-19 — Worked-example mis-pick caught early
- **What changed:** Initial example pool included T-1717 (Embeddings strategy, not post-grill governance — I had the task ID memorised wrong). Real D1:5 candidates are T-1671 (Default-to-OPEN gate) and T-1550 (RCA gate). Used those instead. T-1717 stays out — wrong framing for D1.
- **Plan impact:** Demonstrates the [REVIEW] Human AC is load-bearing — agent self-correction caught one mis-pick but the systematic check still needs human eyes.
- **Triggered:** None.

### 2026-05-19 — Free-drivers section as forward placeholder
- **What changed:** Section "Free drivers — general criteria" written as a *process* (how to extend the rubric when a free driver is added) rather than as concrete criteria for not-yet-existent drivers. Free drivers don't exist yet; concrete criteria can't be written abstractly without inventing examples.
- **Plan impact:** First free-driver add via `fw bvp driver --add` must include the rubric-section author step in its rationale. Worth a follow-up task to enforce structurally if free drivers become routine.
- **Triggered:** Consideration only — not yet filed; depends on whether free drivers see use.

## Recommendation

**Recommendation:** GO (then human review)

**Rationale:** All 5 Agent ACs satisfied; 3/3 Verification commands pass. 212 lines, 4 D1-D4 sections, 3+ worked examples per protected driver drawn from real completed tasks. Determinism statement present. Free-drivers section + R9 reversibility + R2 bias guidance present. The Human AC [REVIEW] is load-bearing and stays unticked — the rubric ships, but T-1922 (estimator) should not run in earnest until the human reviews the worked examples for systematic bias (R2 mitigation).

**Evidence:**
- `policy/bvp-scoring-rubric.md` exists, 212 lines (≥200 required)
- `grep -c "^## D[1-4]"` returns 4 (all four drivers covered)
- 3 worked examples per driver, all citing real completed task IDs with named structural effects
- R9 reversibility discipline documented (estimator behavior depends on this file; revisions need before/after delta check)
- R2 bias guidance documented (self-flattery + self-criticism failure modes named)

**Next:** human reads worked examples end-to-end before T-1922 estimator runs in production.

## Decisions

## Updates

### 2026-05-19T07:37:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c3548f82
- **Timestamp:** 2026-06-02T15:00:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-19T17:37:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Completed via Watchtower UI (human action)
