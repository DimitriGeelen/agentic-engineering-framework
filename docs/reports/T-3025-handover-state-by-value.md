# T-3025: the handover embeds state by value — should it reference instead?

**Status:** inception, captured. No decision. Nothing built.
**Parent:** T-3022 (GO 2026-08-15), candidate F.
**Measurement source:** `docs/reports/T-3022-recall-latency-scaling.md` §Spike 10. That
artifact is the evidence base; this one exists to hold the *design question*, which is
separate from the measurement and is not mine to answer.

## The measurement, in one paragraph

A representative handover is 265,888 bytes, of which **97.3% is state dumps** — Observation
Inbox 137,505 B, Work in Progress 69,568 B, Awaiting Your Action 48,355 B. Those sections are
**byte-identical between consecutive handovers** (0 differing lines), and 99.7% / 100%
identical across a three-hour gap containing real work. Archive-wide, 8 of 9 sampled
consecutive pairs are ≥96.3% identical, sustained March → August; the single outlier (47.2%)
is a genuine event — that section halved. At corpus scale the dumps are **82% of all 90.6 MB**
of handovers. Total bytes ≈ *handovers × state-size*, with **both terms growing**: count
32 → 1,717, mean size 4.5 KB → 54.2 KB.

## The question this task exists to answer

**What is a handover for?**

Referencing state instead of embedding it removes ~74 MB and ~79% of total corpus growth at
source, and makes handovers readable — 342 bytes of "Where We Are" currently sit inside a
quarter-megabyte. That is the whole case for F, and it is strong.

The case against is one property, and it is not negligible: **an embedded handover can be read
without a live system.** A referencing handover cannot. The scenarios where that matters —
post-compaction recovery, a broken index, a cold start on another machine, forensic reading of
a session that ended badly — are disproportionately the scenarios handovers exist for. Trading
away offline readability to save bytes is a bad trade *if* those scenarios are the point.

So the design space is not binary:

1. **Embed everything** (today) — maximal offline value, unbounded duplication.
2. **Reference everything** — minimal bytes, zero offline value.
3. **Embed a bounded digest, reference the rest** — e.g. counts and the top N items with a
   link, instead of all 150 observations. Keeps a cold reader oriented without copying a
   growing backlog.
4. **Embed deltas** — what changed since the previous handover, which is exactly the ~3% that
   is not duplicated, plus a reference for the rest.

(3) and (4) are the interesting ones and neither has been costed. **This is not a
recommendation** — it is the shape of the question, so that whoever decides is choosing
between real options rather than yes/no on the first one proposed.

## Why nothing reported this for months

Every individual handover is correct. The state it embeds is real, current, and was worth
writing down once. There is no defective file to find and no event to notice — **the defect
exists only as a property of the sequence**, and nothing in the framework measures sequences.
This is why it survived alongside a redundancy measurement (T-3022 spike 6) that had already
reported 97% consecutive overlap: a percentage that confirms the plan you already have does
not prompt anyone to ask what causes it.

## Secondary finding — possibly the more serious one

In that same 265,888-byte file:

| Section | Bytes |
|---------|-------|
| `## Decisions Made This Session` | 38 |
| `## Things Tried That Failed` | 35 |
| `## Open Questions / Blockers` | 36 |
| `## Gotchas / Warnings for Next Session` | 66 |

**175 bytes, all empty** — in a session that made decisions, tried things that failed, and left
open questions, several of them recorded in the parent artifact. The mechanical dumps grow
without bound while the sections carrying antifragile content go unfilled.

This is **G-018 (handover quality decay) with a measurement attached**. It is logically
independent of the by-value/by-reference question: fixing F would not fill these sections, and
filling them would not shrink the corpus. It probably deserves its own task, and is flagged
here only so it is not lost inside the byte-count story — the byte story is louder and would
otherwise absorb it.

## Open questions

- **IW-1: What is the handover's primary consumer — a cold reader, or a live session?**
  confidence: 1
  disposition: deferred
  rationale: determines whether offline readability is a requirement or a nice-to-have, and
  therefore whether (2) is admissible at all. Operator judgment; no measurement settles it.

- **IW-2: Do options (3) digest-plus-reference and (4) delta-only preserve enough for
  post-compaction recovery?**
  confidence: 0
  disposition: deferred
  rationale: testable — replay a real compaction recovery against a synthetic digest/delta
  handover and see whether the session reconstitutes. Not yet run.

- **IW-3: Is the empty-learning-sections defect worth separating into its own task?**
  confidence: 2
  disposition: deferred
  rationale: it is independent of F by construction (neither fix implies the other), which
  argues yes under "one task = one deliverable"; deferred to avoid pre-empting the operator.

## Registered

OBS-272 (the finding). OBS-273 (an unrelated gate catch-22 hit while filing this task).
