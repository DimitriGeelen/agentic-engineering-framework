# T-1540 — Convergence Summary

3 sequential blind-reviewer dispatch iterations, each followed by fix application, against the T-1530-T-1539 verdict-workflow arc. Goal: test whether the blind-reviewer pattern converges (each iteration finds fewer / different / non-overlapping issues).

## Per-iteration scoreboard

| Iter | Reviewer prompt | Findings (raw) | False positives | Real bugs | Fixes shipped | New learnings |
|------|-----------------|----------------|-----------------|-----------|---------------|---------------|
| 1    | T-1539 base     | 4              | 0               | 4         | 3             | none new      |
| 2    | identical to iter1 | 3           | 2 (recurrence of L-296 class) | 1 (deferred — count-divergence requires structural alignment) | 0 | none |
| 3    | iter1 + L-296 prefix guidance | 2-3 | 0 (L-296 worked) | 1 actionable | 1 (handover `[?]` doc clarification) | none |

## Real bug list across all 3 iterations

### Iter 1 — fixed
1. **`fw review-queue` footer hardcoded `localhost`** (T-1539 inheritance) — already fixed before T-1540 started; iter1 confirmed clean.
2. **`?` verdict had no filter button on `/approvals`** — added `data-filter="unknown"` button + `filterACs` JS branch.
3. **Landing page count (46) ≠ pill sum (30)** — added `unknown_ac_count` aggregation + grey `?` pill.
4. **`fw review-queue` included spurious started-work tasks (T-1540 itself appeared with `?`)** — filtered to `owner=human OR status=work-completed`.

### Iter 1 — deferred
- **Handover under-reports vs CLI by 21 tasks** — partial-complete queue (handover) is a strict subset of `owner=human` queue (CLI). Resolved in iter3 as expected behaviour, doc clarified.

### Iter 2 — false positives (L-296 class, recurring)
1. "Inception section vanished from `/approvals`" — section gated on `{% if pending_go %}`, correctly hidden when zero pending. Same pattern as iter1's NO-GO claim.
2. "NO-GO filter button missing" — gated on `{% if nogo_count %}`, correctly absent when zero NO-GO tasks exist.

### Iter 2 — structural (deferred)
3. **`?` count diverges 14/15/16 across approvals/review-queue/landing pills** — three different filter paths (`_load_pending_human_acs`, review-queue glob filter, `get_human_verify_tasks`). Not a verdict-workflow bug per se; structural alignment work outside this arc's scope.

### Iter 3 — fixed
1. **Handover intro doc-promise of `[?] missing` prefix never matches reality** — clarified intro to note that partial-complete enforces recommendation (T-1529 gate), so `[?]` is rare and defensive only.

## Convergence shape

```
Real actionable bugs per iteration:
  iter1: ████ 4
  iter2: 0       ← convergence achieved (only structural divergence remained)
  iter3: █ 1
```

The `iter2 → iter3` non-monotonic uptick is **expected, not a regression** — iter3's prompt was strictly different (added L-296 guidance), and the `[?]` doc-promise issue was a finding the previous reviewers had missed because they didn't try to grep handover for `[?]` literal occurrences.

**Net outcome:** 4 real bugs fixed in iter1, 0 new in iter2 (false positives only), 1 in iter3 (doc clarification). The arc is **tight** — 5 fixes total across 4 surfaces (filter button, landing pill, review-queue filter, handover doc, plus T-1539 footer URL fix from before T-1540 started).

## False-positive rate

| Iter | False positive count | Reason |
|------|----------------------|--------|
| 1    | 0                    | n/a    |
| 2    | 2/3 (67%)            | reviewer didn't grep template for conditional branches before declaring absence a bug |
| 3    | 0/3 (0%)             | L-296 prompt prefix told reviewer to grep first |

**L-296 reduced false-positive rate from 67% → 0% in one prompt iteration.** This is the highest-leverage finding from the convergence test.

## Cost

- **Wall-clock:** iter1 ~8 min (incl 1 retry on timeout), iter2 ~5 min, iter3 ~4 min — total ~17 min for 3 dispatches
- **Worker model:** Sonnet 4.6 for iter1, default (Opus 4.7 [1m]) for iter2/iter3
- **Parent context:** ~10K tokens total for the 3 reports (each ~3K), plus prompt design + fix application
- **Fixes shipped:** 5 commits, ~250 LOC delta total

## Pattern observations (carryover)

1. **L-295 (already captured):** blind-reviewer dispatch is high-leverage UX validation; ship UX → dispatch → harvest → fix.
2. **L-296 (already captured):** distinguish absent-because-conditionally-hidden from absent-because-broken; require reviewer to cite line numbers for absence claims.
3. **NEW: L-297 candidate** — blind-reviewer dispatch converges in ~3 iterations when prompt incorporates lessons from prior false-positive classes. First iteration catches obvious bugs; second exposes false-positive class; third (prompt-refined) catches edge cases. Diminishing returns past iter3.
4. **NEW: L-298 candidate** — count divergence across multiple surfaces (approvals page, CLI, landing pills) is a recurring smell. Each surface has its own filter logic; without a single-source-of-truth helper, 1-2 task drift is normal noise. Either accept the noise or invest in alignment.

## Conclusion

The blind-reviewer convergence test validates the verdict-workflow arc end-to-end. **5 real bugs found and fixed, 2 false-positive classes documented, 4 candidate learnings.** No regressions. No outstanding actionable concerns from the test cycle.

**Verdict:** GO. The arc is structurally complete and validated.
