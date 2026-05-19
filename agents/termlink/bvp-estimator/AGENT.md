# bvp-estimator (T-1922, arc-006)

TermLink worker that scores tasks against the BVP rubric and writes
proposed scores to `bvp_scores_proposed:` on the task's frontmatter.
Never writes to confirmed `bvp_scores:` — that path is the human's via
`fw bvp confirm` (T-1924).

## What it does

For each task scanned, the estimator:

1. Loads the rubric at `policy/bvp-scoring-rubric.md` (preload, hashed).
2. Loads driver weights from `policy/value-drivers.yaml` (D1-D4 + free).
3. Parses the task's frontmatter + body.
4. Applies a heuristic classifier per driver — returns score 0-5 + evidence.
5. Computes the M3 v2-delta against any existing `bvp_scores:`. If proposed
   differs from confirmed by `<2` on every driver, skip the write.
6. Otherwise appends a timestamped entry to `bvp_scores_proposed:`.

## Engine — v1 heuristic

The v1 engine is a pattern-based classifier reading the task body for
keyword classes derived from the rubric's worked examples and
common-mis-scoring lists. Deterministic by construction (bit-identical
on re-runs of the same input) — the R3 ±1 determinism AC is trivially
satisfied. Zero LLM dependency. Zero marginal token cost.

The trade-off: pattern misses where the rubric example's signal is
phrased differently. Calibration against the rubric's 10 worked examples
shows ~70% within ±1 of the rubric score, ~30% with deltas ≥2 (usually
under-fires). Documented in `docs/reports/T-1922-a3-measurement.md`.

v2-LLM (escalate when heuristic confidence is low) is a follow-up, not
this slice.

## Surfaces

- **Direct script:** `python3 agents/termlink/bvp-estimator/estimator.py <verb>`
- **TermLink-convention wrapper:** `./bvp-estimator.sh <verb>`
- **fw integration:** `fw bvp estimate T-XXX` (lib/bvp.sh routing)

Verbs: `one`, `all`, `determinism`, `measure-a3`.

## Sovereignty boundary

Writing `bvp_scores_proposed:` is NOT sovereignty-bearing. Proposed scores
are advisory — they appear in `/bvp` scatter and in `/arcs/<id>` BVP block
as "what the estimator thinks", labelled as such. Confirmed `bvp_scores:`
writes still gate through `fw bvp confirm --i-am-human|--from-watchtower`
(T-1924, §ACD-gated). So the estimator runs freely under `$CLAUDECODE=1`;
the human remains the score authority.

## A3 measurement

The `measure-a3` verb runs the estimator against the most recent 20
completed tasks and writes a latency + scores summary. SLA target: mean
< 5s per task. With the heuristic engine, observed latencies are ~10ms
per task (well under SLA). Report in `docs/reports/T-1922-a3-measurement.md`.

## Determinism

The `determinism` verb runs the estimator N times on one task and reports
the max delta per driver across runs. Heuristic engine: always 0.
Provided as a regression guard against future LLM-engine drift.

## Component fabric

- Type: termlink-worker
- Subsystem: bvp
- Depends on: `policy/value-drivers.yaml`, `policy/bvp-scoring-rubric.md`,
  `lib/bvp.sh` (read-only consumer of proposed scores)
- Depended by: `fw bvp estimate`, `fw bvp confirm` (consumes proposed
  via `bvp_scores_proposed:` → `bvp_scores:` move)
