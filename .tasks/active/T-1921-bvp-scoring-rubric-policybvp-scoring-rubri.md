---
id: T-1921
name: "BVP T-NEW-6: scoring rubric document (policy/bvp-scoring-rubric.md) — per-driver criteria + worked examples"
description: >
  Write the rubric the TermLink estimator follows (T-1922 consumes this). Per-driver scoring criteria, worked examples from .tasks/completed/, calibration cases. R2 (rubric bias) mitigated by [REVIEW] Human AC; R9 (rubric reversibility risk) acknowledged.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-6, rubric, docs]
components: [policy/bvp-scoring-rubric.md]
related_tasks: [T-1915, T-1916, T-1922]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:00:00Z
date_finished: null
---

# T-1921: BVP T-NEW-6 — `policy/bvp-scoring-rubric.md`

## Context

The rubric is "the reusable state the worker preloads" (D4 — F4-deep classifier framing). Worked examples are versioned content; treat with same care as code (R9 reversibility risk).

**Source:** Handoff §7 T-NEW-6; artefact §6 row 5; §2 R2/R9; §4 F4-deep classifier framing.

**The [REVIEW] Human AC on this slice is load-bearing** — do NOT classify as [REVIEWER] per R2 mitigation (taste call is human, not static scan).

## Acceptance Criteria

### Agent
- [ ] `policy/bvp-scoring-rubric.md` exists at repo root
- [ ] Document has sections for each protected driver (D1 Antifragility, D2 Reliability, D3 Usability, D4 Portability) — each with a "what does score N mean?" rubric for N in 0..5
- [ ] Document has a "free drivers — general criteria" section for drivers added via `fw bvp driver --add`
- [ ] At least 3 worked examples per protected driver, drawn from real completed tasks in `.tasks/completed/` — citing task IDs and quoting representative AC/context language
- [ ] Document includes a determinism statement: same task body scored twice in separate sessions at low temperature must produce scores within ±1 on every driver

### Human
- [ ] [REVIEW] Worked examples reflect AEF's actual values, not hallucinated framings (R2 mitigation, load-bearing — do NOT downgrade to [REVIEWER])
  **Steps:**
  1. Open `policy/bvp-scoring-rubric.md`; read each worked example end-to-end
  2. For each example, verify the framing matches how *you* would have scored the task
  3. Pay particular attention to whether any driver is systematically over- or under-scored across examples
  **Expected:** No examples produce systematic bias in either direction
  **If not:** Revise the rubric before T-1922 starts (the estimator inherits the rubric's biases)

## Verification

test -f policy/bvp-scoring-rubric.md
[ "$(wc -l < policy/bvp-scoring-rubric.md)" -ge 200 ]
grep -c "^### D[1-4]" policy/bvp-scoring-rubric.md | grep -q "^4$"

## Decisions

## Updates
