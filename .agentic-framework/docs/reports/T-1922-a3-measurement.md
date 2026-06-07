# T-1922 — A3 Measurement: BVP Estimator v1 (Heuristic)

**Filed under:** T-1922 (arc-006, value-prioritisation)
**Estimator version:** `bvp-estimator-v1-heuristic`
**Rubric SHA:** `e4a00f38e801` (`policy/bvp-scoring-rubric.md`)
**Measurement date:** 2026-05-19
**A3 raw data:** `docs/reports/T-1922-a3-measurement-raw.json`

This report captures the latency, determinism, and calibration measurements
for the v1 estimator against the AC targets in T-1922:

| AC | Target | Result |
|----|--------|--------|
| Latency mean | <5 s per task | **0.0027 s** (2.7 ms) |
| Latency p95 | (not specified) | 0.0073 s |
| Token marginal | <2 k per task | **0** (heuristic — no LLM) |
| Determinism | re-run within ±1 | **0** (bit-identical) |
| Rubric preload | yes | yes (sha256, module-level cache) |
| v2-delta skip | confirmed delta <2 → skip | yes |
| Writes to confirmed | **never** | never (sovereignty boundary) |

## Engine

The v1 engine is a **pattern-based heuristic classifier** reading the task
body and tags for keyword classes derived from the rubric's worked examples
and the rubric's "common mis-scorings" lists.

Choice rationale:

- **Determinism** — same input bytes produce identical output bytes. R3 (the
  ship-blocking AC) is trivially satisfied. An LLM engine would have to fight
  for ±1 calibration even at temperature 0.
- **Latency** — ~10 ms per task vs ~2-5 s for an LLM dispatch round-trip.
  Two orders of magnitude below the 5 s SLA.
- **Cost** — zero marginal tokens per task. The rubric is read only once
  for hashing; the actual pattern dictionary is in the script.
- **Auditability** — the entire heuristic fits in one Python file readable
  by a human in 10 minutes. An LLM engine would be a black box.

The trade-off is **calibration miss-rate**: pattern matchers miss rubric
signals that are phrased atypically. Section *Calibration* below quantifies
this.

## Latency (n=20 historical tasks)

Run: `fw bvp estimate measure-a3 --n 20 --output docs/reports/T-1922-a3-measurement-raw.json`

| Stat | Value | SLA target |
|------|-------|-----------|
| Mean | 0.0027 s | < 5 s |
| p95 | 0.0073 s | — |
| Max | 0.0073 s | — |

The estimator's wall-clock cost is dominated by frontmatter YAML parsing,
not pattern matching. Re-implementing the parser in C would bring this
under 1 ms, but the current latency is already ~1800× under the SLA
budget so no further work is justified.

## Determinism

The engine is deterministic by construction — pattern matching on a fixed
body produces a fixed score. `fw bvp estimate determinism T-<id> --runs N`
verifies this against drift (e.g., if a future v2 layers an LLM and
introduces non-determinism, the same regression guard fires).

Tested on 5 representative tasks, runs=5:

| Task | Max delta across 5 runs |
|------|-------------------------|
| T-1730 | 0 |
| T-1671 | 0 |
| T-1550 | 0 |
| T-1633 | 0 |
| T-679 | 0 |

R3 PASS unconditionally for the heuristic engine.

## Calibration (rubric worked examples)

The rubric (T-1921) carries 10 explicit worked examples with rubric-author
expected scores. The estimator was run on each and compared:

| Task | Rubric expected | Estimator (D1/D2/D3/D4) | Max delta vs rubric |
|------|-----------------|--------------------------|---------------------|
| T-1730 | D1=4 | 3/4/0/0 | 1 |
| T-1671 | D1=5 | 4/0/4/0 | 1 |
| T-1550 | D1=5; D2=4 | 4/2/0/2 | 2 |
| T-1771 | D2=4 | 4/4/0/0 | 0 |
| T-1850 | D2=3 | 4/4/4/2 | 1 |
| T-1633 | D4=5 | 2/1/0/5 | 0 |
| T-1144 | D4=2 | 4/0/0/0 | 2 |
| T-609 | D3=4 | 0/0/4/0 | 0 |
| T-1257 | D3=4 | 1/0/4/2 | 0 |
| T-679 | D3=5 | 4/4/0/5 | **5** |

**Summary:** 7/10 within ±1, 9/10 within ±2, 1/10 outlier (T-679 D3).

T-679's body discusses "review surface" and "fw task review" — the rubric
calls it a "new collaboration mode" but the body never uses that phrase.
The heuristic's `score_d3_usability` Level 5 patterns are tight (deliberate
— loosening matches "Recommendation block" caused cross-driver bleed in
T-1671). The outlier is the cost of the tight patterns.

## v2-delta semantics (M3)

When a task already carries confirmed `bvp_scores:` and the estimator's
proposal differs by `<2` on every driver, the estimator **skips the write**
(no churn in `bvp_scores_proposed:`). If the proposal differs by `≥2` on
**any** driver, a timestamped delta entry is appended.

Verified with hand-test:

```bash
# Set confirmed scores on T-1730
fw bvp confirm T-1730 --override D1=4 --override D2=3 --override D3=0 --override D4=0 --i-am-human
# Re-run estimator (proposes D1=3, D2=4, D3=0, D4=0 — delta of 1 on D1, 1 on D2)
fw bvp estimate T-1730    # → no write ("v2-delta-skip")
# Edit task body to add "new mechanism" language
fw bvp estimate T-1730    # → writes (D1 jumped 3→5, delta ≥2)
```

## Sovereignty boundary

The estimator writes ONLY to `bvp_scores_proposed:` (a list of timestamped
delta entries). Confirmed `bvp_scores:` is set exclusively by
`fw bvp confirm` (T-1924), which is §ACD-gated (requires `--i-am-human`
or `--from-watchtower`). The estimator therefore runs freely under
`$CLAUDECODE=1` — its writes are advisory, not authoritative.

This separation lets the estimator run on every task transition (T-1923
sweep slice) without needing per-task human approval, while keeping the
sovereignty boundary at the *confirmation* step.

## Engine swap (v2 follow-up, NOT this slice)

A v2 engine could layer claude-haiku on top of the heuristic for tasks
where v1 confidence is low (e.g., D-scores all 0, or D-scores cluster
around 2-3 without a strong signal). The harness exposes a clean
`estimate_task(task_path, drivers) → result` API, so an LLM engine
slots in by:

1. Adding `engine: v2-llm` to `policy/value-drivers.yaml`.
2. Implementing `estimate_task_llm(task_path, drivers, rubric_text)`.
3. Routing in `estimator.py:main()` based on the policy switch.

T-1923 (sweep) will batch-run the estimator periodically. An LLM engine
would consume real tokens per dispatch; the v1 heuristic stays free.

## Open follow-ups (filed as separate tasks)

- **T-1923**: scheduled sweep + `fw resume` SLA fallback (estimator
  blocker; was waiting on this slice to land).
- **Surface proposed scores on `/bvp` scatter and `/arcs/<id>` BVP block**
  (currently confirmed-only; proposed are visible via `fw bvp T-<id>` CLI).
  Worth filing as a follow-up if the human review path is "see proposed
  in Watchtower, click confirm" rather than "run CLI confirm".
- **Calibrate T-679 D3 miss** — broaden the D3 Level 5 patterns to cover
  "review surface" + "structured recommendation flow" without bleeding
  into D1/D4. Track in `concerns.yaml` under R2 (rubric bias) if more
  examples surface.

---

*End of A3 report. Source data: `docs/reports/T-1922-a3-measurement-raw.json`.*
