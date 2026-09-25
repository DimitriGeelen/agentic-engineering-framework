# T-3485 — BVP value-axis equality defect: repro + fix evidence

Scope: `lib/bvp.sh` `quadrant()` only, per narrow downstream-operator
authorization. See T-3485 task file for full Context/Decisions/RCA/Recommendation.

## Reproduction (pre-fix)

Fixture: 25 tasks, 13 scoring all-zero (`D1=D2=D3=D4=0`), 12 spread
`D1 in {1..5}` (D2-D4=0), identical 3-component cost (`blast_radius=tier=effort=2`)
on every task — isolates the value axis from the cost axis.

```
$ fw bvp --quadrant hv-lc      # against pre-fix lib/bvp.sh
TASK          BVP   NORM   COST   QUAD  NAME
--------------------------------------------------------------------------------
T-8004         45   0.38    2.0  hv-lc  T-8004 test
...
T-9000          0   0.00    2.0  hv-lc  T-9000 test
...  (all 25 rows, including all 13 zero-value rows, in hv-lc)

zero-value tasks landing in hv-lc: 13/13
```

Median value = 0.00 (13/25 tied at the corpus floor → `>=` promotes all 13).
Median cost = 2.0 (constant across all 25 rows → every row reads `lc`
regardless of value — see "Finding: cost-axis" below, not fixed here).

## Post-fix

Same fixture, same command, against the patched `quadrant()`:

```
NOTE: 13/25 task(s) have a value score tied at a degenerate median (median
sits at the corpus floor, bvp_norm=0.00) — quadrant withheld ('v-thin')
rather than guessed. See T-3485.

TASK          BVP   NORM   COST   QUAD  NAME
--------------------------------------------------------------------------------
T-8004         45   0.38    2.0  hv-lc  T-8004 test
...  (the 12 genuinely-scored tasks only)

zero-value tasks landing in hv-lc: 0/13
```

The 13 zero-value tasks are withheld (`v-thin`, not shown under
`--quadrant hv-lc` since it isn't one of the 4 standard buckets); the 12
genuinely-scored tasks are unaffected.

## Two-sided control

- **Exclusion:** `tests/unit/test_bvp_quadrant_value_axis.py::test_degenerate_median_zero_value_tasks_withheld_not_hv`
- **Admission:** `::test_genuinely_high_value_task_still_classified_hv_in_degenerate_corpus`
  (T-8004/T-8009, D1=5, the max score in the same degenerate corpus, still land `hv-lc`)
- **Naive-fix control:** `::test_naive_flip_to_strict_greater_would_fail_admission` —
  proves `>=`→`>` would wrongly exclude a genuine (non-degenerate) at-median
  tie (D1 scores 1,2,2,4 — median 2, the two 2-scorers legitimately belong
  in `hv` under inclusive comparison; a naive strict `>` would exclude them,
  which this repair's degenerate-only guard does not).
- **Healthy-corpus control:** `::test_healthy_well_spread_corpus_unaffected` —
  D1 scores 1..5, distinct costs 1..5; quadrant assignments byte-identical
  to pre-fix `>=` semantics (verified against a live run of the fixture).

## Finding: cost-axis has the identical equality shape (reported, not fixed)

`lc = cost <= cost_median` in the same `quadrant()` function. This
reproduction's own fixture demonstrates the failure mode incidentally: all
25 tasks share `cost=2.0`, so every task reads `lc` regardless of its actual
cost. Out of this task's authorized scope (explicit instruction: "Report, do
not fix: the cost axis").

## Finding: `lib/resolver.py` carries an independent duplicate of this exact defect

`lib/resolver.py:_annotate_bvp_rank()` (~line 1370) reimplements
`("hv" if m["bvp_norm"] >= bvp_median else "lv") + "-" + (...)` — its own
docstring says "mirroring bvp.sh cmd_rank." This is the function that
actually drives `fw resolver dispatch` task auto-selection
(`_QUADRANT_RANK`, HV-LC ranked first) — the real autonomous-selection
surface, distinct from the `fw bvp rank` display this task patches. Not
touched here: never named in this task's authorization, and `lib/resolver.py`
is a separate module with its own maintainers/callers. Flagged for a
follow-up decision by the operator.
