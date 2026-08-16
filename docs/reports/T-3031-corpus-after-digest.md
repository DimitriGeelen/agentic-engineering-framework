# T-3031 — the indexed corpus after the handover digest

**Measured:** 2026-08-16, on `t2539-staging` at `5f7140bff`.
**Method:** `python3 tools/measure_corpus_classes.py --growth-days 30`.
**Inclusion set:** `web.search_utils.collect_files()` — the same function the
indexer walks, not a glob written for this report. A measurement whose scope
drifts from the indexer's is a measurement of something else.

## The headline

**The digest fixed the flow and left the stock untouched. Handovers are still
67.6% of the corpus.**

T-3028 shipped this morning and works exactly as measured: the first
post-digest handover is **18,066 B** against a pre-digest same-day peak of
**276,069 B**. But it only shapes handovers as they are *generated*. The 1,719
handover files already on disk — 96,335,564 B of them — are unchanged, and they
are what the indexer reads.

So the 68% baseline that chose T-3028 has barely moved, and it has not moved
for a reason worth stating plainly: **reducing the rate at which a class grows
does nothing to the class that already exists.** The two are separate pieces of
work, and only the first was done.

## SIZE — 142,480,248 B across 9,271 files

| class | bytes | files | share |
|---|---:|---:|---:|
| handovers | 96,318,977 | 1,721 | **67.6%** |
| tasks-completed | 22,694,918 | 2,659 | 15.9% |
| episodics | 8,806,981 | 2,662 | 6.2% |
| reports | 6,461,293 | 673 | 4.5% |
| tasks-active | 5,571,809 | 359 | 3.9% |
| context-other | 989,625 | 24 | 0.7% |
| `.fabric/components` | 608,324 | 1,064 | 0.4% |
| docs-other | 377,329 | 54 | 0.3% |
| top-level-specs | 373,224 | 19 | 0.3% |
| policy | 191,137 | 19 | 0.1% |
| agent-docs | 62,725 | 14 | 0.0% |
| tasks-other | 23,906 | 3 | 0.0% |

Handover distribution: mean **56,041 B**, median **41,030 B**. The five largest
files in the class are all from the last 24 hours and all pre-digest
(265,888 → 276,069 B) — the runaway this morning's work stopped.

## GROWTH — 872,512 lines added, last 30 days

| class | added | removed | share |
|---|---:|---:|---:|
| handovers | 480,350 | 1,556 | **55.1%** |
| context-other | 146,722 | 108,905 | 16.8% |
| tasks-active | 122,232 | 3,399 | 14.0% |
| episodics | 36,743 | 1,144 | 4.2% |
| tasks-completed | 29,393 | 1,351 | 3.4% |
| `.fabric/components` | 27,845 | 1,006 | 3.2% |
| reports | 13,114 | 287 | 1.5% |
| tasks-other | 9,059 | 1,908 | 1.0% |
| generated-component-docs | 5,475 | 214 | 0.6% |
| policy | 730 | 94 | 0.1% |
| others | <1,000 each | | <0.1% |

Growth is measured as lines **added**, not net change, deliberately: a class
that adds 10k lines and deletes 9k still generates 10k lines of embedding work
every cycle, and net would hide that. `context-other` is the visible case —
146,722 added against 108,905 removed, i.e. churn rather than accumulation.

The growth figure is the 30-day window and therefore still describes the
pre-digest regime; the digest has had one day inside it. It should be re-run in
a week to see the flow fix land.

Note `generated-component-docs` appears in growth (5,475 lines) and at zero in
size: `docs/generated/` is committed but sits in `GENERATED_OR_RESTATED` and is
not indexed. That is the T-3024 class rule working, and it is why growth and
size must be read as two different questions rather than one.

## Restating the baseline honestly

The pre-digest figure was **68% of the corpus, 79% of its growth** (measured
2026-08-15 during T-3025, same inclusion set). Today: **67.6% and 55.1%**.

The size number is unchanged within noise, exactly as the stock/flow split
predicts. The growth number dropped 79% → 55%, but that drop is **not**
attributable to the digest — the digest is one day old inside a 30-day window.
It is more likely a change in the mix (a heavy month of task and context churn).
Claiming the digest for it would be the kind of attribution this report exists
to avoid.

## Next candidate: a handover retention window

**Candidate:** index only the most recent N handovers, rather than all 1,719.

**Measured size:** 96,335,564 B, 67.6% of the corpus.

**Estimated reduction**, by window:

| keep last N | handover bytes indexed | corpus after | corpus cut |
|---:|---:|---:|---:|
| 0 (off) | 0 | 46,144,684 | **67.6%** |
| 30 | 6,611,789 | 52,756,473 | 63.0% |
| 60 | 13,669,038 | 59,813,722 | 58.0% |
| 90 | 17,738,425 | 63,883,109 | **55.2%** |
| 180 | 27,210,891 | 73,355,575 | 48.5% |
| 365 | 45,664,570 | 91,809,254 | 35.6% |

**Reversible (subtraction) or migration?** **Subtraction, and the cheapest kind.**
Nothing is rewritten or deleted — the files stay on disk, the change is which
subset `collect_files()` returns, and reverting is one config value plus a
reindex. This is the same property that made T-3025 choose the digest over the
larger 10× option, and it holds more strongly here: the digest at least rewrote
what future handovers say, whereas a retention window touches no file at all.

**Why the value is real and not just arithmetic.** A handover is a session
snapshot whose durable content is restated by construction — task files,
episodics, decisions and learnings all outlive it, and the framework's own
recovery path reads `LATEST.md`, not the archive. A six-month-old handover's
unique recall value is close to zero while its embedding cost is identical to a
current one's.

**Why it is not free.** This is a recall claim, and it should be verified rather
than asserted: `fw recall` usage data (`lib/recall-usage.sh`) can say how often
retrieved chunks actually come from handovers older than N days. If the answer
is "often", the window is wrong and the honest move is a retro-digest of the
stock instead — which *is* a migration and should be priced as one.

**Groundwork already present:** `web/search_utils.py:130 _index_handovers()`
resolves an `INDEX_HANDOVERS` config key, but it is binary — all or nothing. A
retention window is that switch made continuous, so the shape is established
and the change is small.

## Candidates considered and rejected

- **`tasks-completed` (15.9%, 22.7 MB).** Rejected: it is the second-largest
  class but it is the *archive the framework is built to consult* — episodic
  recall of prior work is a primary use, so it has genuine per-file recall
  value. Also nearly static (3.4% of growth). Reduction work on a static class
  is paid once and never again.
- **`episodics` (6.2%) / `reports` (4.5%).** Rejected on size: even eliminating
  both entirely buys 10.7%, against 67.6% available in one class. Not worth
  spending the reversibility budget on.
- **`.fabric/components` (0.4% size, 3.2% growth).** Rejected: growing faster
  than its size suggests, but 608 KB is a rounding error against 96 MB. Worth
  re-checking once handovers are dealt with, not before.
- **`context-other` (0.7% size, 16.8% growth).** Rejected for now, flagged: the
  second-largest growth class and almost invisible in size, which is the churn
  signature. It is not corpus *accumulation*, so it costs reindex work rather
  than index size. That makes it an incremental-reindex question (T-3014's
  territory), not a corpus-size one.
- **Binary quantization (Candidate A).** Out of scope and still unauthorised. It
  is also the wrong order of operations: quantizing an index that is 67.6%
  low-value handovers optimises the storage of content that should not be in it.
  Reduce first, then quantize what remains.

## Reproducing this

```
cd /opt/999-Agentic-Engineering-Framework && python3 tools/measure_corpus_classes.py --growth-days 30
```

`--json` emits the same data machine-readably. The class map is the ordered
`_CLASSES` tuple in `tools/measure_corpus_classes.py`; first match wins, so a
new directory has to be placed deliberately rather than falling into
`unclassified` unnoticed.
