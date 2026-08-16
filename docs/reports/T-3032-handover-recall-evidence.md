# T-3032 — do old handovers actually get retrieved?

**Verdict: UNSAFE at N=90. The retention window T-3031 proposed would remove
retrievals that are currently the top-ranked answer to real questions.**

**Measured:** 2026-08-16, `t2539-staging`. Index built 41 minutes before the
probe (`index_freshness()` → `age_seconds: 2482`), so today's work is indexed —
confirmed by age-0 hits in the results below. A stale index would have biased
every number toward old content and invalidated the conclusion; it was checked
rather than assumed.

## What this measures, and what it does not

This is a **replayed-query probe**, not usage data. It answers *"if this query
were asked, what would come back?"* — not *"what did anyone actually retrieve
and use?"* A chunk surfacing in the top-k is not evidence anyone needed it.

Read the result as an **upper bound on what a retention window would cost**.
That direction keeps the conclusion conservative: an upper bound showing old
handovers rarely surfacing would make the window safe. It shows the opposite,
and no amount of usage data would rescue it.

The distinction matters because the two claims are easy to conflate and the
weaker one is more persuasive-sounding.

## Step 1 — the telemetry cannot answer this (AC #1, #2)

`.context/working/recall-telemetry.jsonl`, 95 records, 2026-08-15T14:27 →
2026-08-16T09:59 (19 hours). Field census across all 95:

| field | present in |
|---|---|
| `ts`, `surface`, `query_hash`, `n_hits`, `top_score`, `latency_ms`, `outcome` | 95/95 |
| `embed_status`, `query` | 1/95 |

**No field names a document, path, or source.** `query_hash` is a hash; the
query text itself survives in 1 record of 95. Outcomes: 94 `hit`, 1
`unavailable`. Surfaces: 64 `rag`, 31 `semantic`.

So the instrument records *that* recall happened and whether it was fast and
non-empty. It cannot say what was retrieved, and therefore cannot say how old
what-was-retrieved is. This is not a gap in the data volume — 19 hours is thin,
but even 19 months of it would not answer the question, because the field does
not exist.

That is the finding for AC #1 and #2: **no usable data**, and the reason is
structural rather than a sampling problem.

## Step 2 — the direct probe (AC #3)

`python3 tools/probe_handover_recall.py --limit 20`, 12 queries written down in
the script so the probe is repeatable. The queries deliberately span two kinds:
durable-knowledge questions (which task files, learnings and decisions should
answer) and session-history questions (the handover's home turf). If handovers
failed to win even the second kind, the window would be safe by a wide margin.

| query | handover hits | note |
|---|---|---|
| why does the framework refuse a commit on master | 0/21 | |
| how do I bypass the focus drift gate | 0/17 | |
| difference between REVIEW and REVIEWER ACs | 0/44 | |
| how does the verification gate handle pipefail | 0/45 | |
| what causes self-vendor drift on push | 0/4 | |
| what did the session decide about the handover digest | **59/60** | top 8 hits are 112–124 days old |
| what was blocking the push at the end of the last session | **38/42** | **top-1 is 173 days old** |
| which tasks were left partial-complete | 2/30 | both 178 days old |
| what happened with the cron registry drift | 0/15 | |
| what did we learn about TermLink identity rotation | 0/20 | |
| how do I recover a consumer vendored before T-2232 | 11/32 | ages 0–154 d |
| what is the retention policy for dispatch blobs | 0/34 | |

**Totals:** 364 hits, 110 from handovers (30.2%). Top-1 was a handover for 1 of
12 queries.

**Handover hits by age of the handover:**

| age | hits | share of handover hits |
|---|---:|---:|
| 0–7 d | 39 | 35.5% |
| 8–30 d | 30 | 27.3% |
| 31–90 d | 6 | 5.5% |
| **91–180 d** | **35** | **31.8%** |

Age is taken from the `S-YYYY-MMDD` session stamp in the filename rather than
mtime, because mtime moves whenever anything rewrites the file (a vendor sync, a
checkout) and would make an old handover look fresh.

## Why this is UNSAFE at N=90 (AC #4)

Three independent readings, all pointing the same way:

1. **31.8% of handover retrievals are older than 90 days.** A 90-day window
   removes roughly a third of what handovers currently contribute.
2. **It removes top-ranked answers, not just tail results.** For *"what was
   blocking the push at the end of the last session"*, the rank-0 hit is a
   **173-day-old** handover. For *"what did the session decide about the handover
   digest"*, the top 8 hits are 112–124 days old. These are not marginal
   supplements — they are the answer.
3. **The age distribution is bimodal, not decaying.** 35.5% in the last week and
   31.8% at 91–180 days, with a trough of 5.5% at 31–90 days. Retrieval value
   does not fall off smoothly with age, so there is no natural cut point that a
   window could sit at. Any N in the trough (30–90) buys little; any N past it
   starts destroying the second mode.

**What the evidence does support:** the durable-knowledge half of T-3031's claim
is *correct*. Seven of twelve queries returned zero handover hits — for
questions about gates, ACs, pipefail behaviour and drift, the durable content
genuinely does live in task files and learnings, exactly as argued. What is
wrong is the generalisation from that to "old handovers have near-zero value".
They have near-zero value **for durable-knowledge queries** and are the primary
source **for session-history queries**, and the corpus serves both.

## Consequences for the next task

A retention window is not dead, but its price is now known: it trades away
**session-history recall specifically**, and the oldest observed useful hit was
178 days. Two evidence-backed options remain, and they should be priced against
each other rather than assumed:

- **N=365.** Preserves every retrieval observed here (max age 178 d) and still
  cuts the corpus **35.6%** (T-3031's table). Subtraction, reversible, no
  measured recall loss. The conservative choice.
- **Retro-digest the stock.** Apply T-3028's digest to the 1,719 existing files.
  This is the better-shaped answer to what the probe actually found: the content
  being retrieved is the *narrative*, and the bytes are dominated by the three
  state dumps T-3028 already proved redundant. It would cut size while
  preserving precisely what the probe shows being used. **But it is a migration,
  not subtraction** — it rewrites files — and the reduction ratio on historical
  files is *unmeasured*: today's 15.3× was measured on a 271 KB pre-digest file,
  while the historical mean is 56 KB, so older handovers had smaller dumps and
  will not shrink as far. That ratio must be measured before the option is
  priced, not extrapolated.

Recommending between them is the next task's job. This one's finding is that
**N=90 is off the table**, and that the argument which produced it was right
about half the corpus and wrong about the half that mattered.

## Reproducing this

```
cd /opt/999-Agentic-Engineering-Framework && python3 tools/probe_handover_recall.py --limit 20
```

`--json` emits per-query detail including ranks and ages. The query list is the
`QUERIES` constant in `tools/probe_handover_recall.py` — extend it there rather
than passing queries ad hoc, so a later run is comparable to this one.

Telemetry census:

```
cd /opt/999-Agentic-Engineering-Framework && python3 -c "import json,collections;k=collections.Counter();[k.update(json.loads(l).keys()) for l in open('.context/working/recall-telemetry.jsonl') if l.strip()];print(dict(k))"
```
