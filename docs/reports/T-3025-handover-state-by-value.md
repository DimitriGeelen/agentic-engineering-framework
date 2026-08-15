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

## Spike 11 — building option (3) and measuring what it actually costs

IW-2 asked whether a digest-plus-reference handover preserves enough for recovery. I built
one (`scratchpad/digest.py`, exploration only — not a generator) and measured before running
any behavioural test. The measurement turned out to answer more than the byte question.

**Rule applied.** Narrative sections pass through verbatim; each of the three dumps becomes
(count, first 5 entries, the live command that regenerates the rest). N=5 deliberately — a
generous N would answer an easier question.

**Result on `S-2026-0816-0019`: 273,761 B → 18,762 B (6.9%, a 14.6× reduction).** All 14
non-dump sections byte-identical to the original, verified by per-section md5. After the
transform the largest remaining section is `## Gotchas` — judgement rather than dump, which
is the shape you would want.

### 11a. A digest is not a generic transformation

The entry unit is **section-specific**, and getting it wrong produces a plausible wrong
number rather than an error. Two instances, both mine, in the same hour:

| Version | Section | Reported | Actual | Cause |
|---------|---------|----------|--------|-------|
| v1 | Work in Progress | **720 active tasks** | 119 | counted each task's 4 bullet *fields* as tasks |
| v2 | Awaiting Your Action | **440 items** | 220 | pattern allowed leading whitespace → counted indented sub-bullets |

Neither is detectable by inspection — 720 and 440 both look like numbers this project could
plausibly produce. Both were caught by an **independent oracle**: most dump sections state
their own count in a bold lead-in (`**153 pending observations…**`), a figure produced by the
handover generator rather than by my script, so agreement is corroboration and not tautology.
That check is now in the script and prints per section.

This is the same class as the −11.3% similarity metric in T-3022 §Spike 10 and 832's polarity
argument: **the error that survives is the one whose shape looks reasonable, so the check that
catches it has to come from a path that doesn't share the author's prior.** A digest generator
that self-reports counts without such an oracle would ship confident wrong numbers into the
one artifact a recovering session trusts.

### 11b. The Work in Progress dump is mostly a constant, repeated 119 times

Composition of the 69,970-byte section (119 entries):

| Component | Bytes | % | Distinct values |
|-----------|-------|---|-----------------|
| `### T-XXXX: "name"` headings | 10,333 | 14.8% | 119 |
| `Last action:` lines | 14,370 | 20.5% | **84** |
| `Status:` lines | 4,764 | 6.8% | **2** |
| `Next step:` + `Blockers:` | 6,188 | 8.8% | **1 each** |
| structural whitespace | ~35,000 | ~49% | — |

**All 119 entries say `Next step: See task file`. All 119 say `Blockers: None`.** Those two
fields are constant across the entire section — 6,188 bytes carrying zero bits, and they are
the two fields a recovering session would most want to read. `Status` carries one bit in
practice (82 `captured`, 37 `started-work`). Only `Last action` genuinely varies, and it is
the most recent commit subject touching each task, i.e. recoverable from git.

### 11c. The digest drops no task identity at all

I expected to find in-progress tasks that fall off the end of a top-5 truncation, and built
the behavioural probe around exactly that. There are none:

```
WIP tasks: 119        absent from digest entirely: 0
```

Every one of the 119 already appears in the handover's **YAML frontmatter** `tasks_active:`
list, which the digest preserves for free. So truncating the dump costs per-task *detail*
(84 distinct last-actions), not per-task *existence* — a materially cheaper trade than the
option analysis above assumed when it framed (3) as buying bytes with offline readability.

### 11d. Secondary: 69% of "Work in Progress" is not in progress

82 of the 119 entries have `Status: captured` — filed, not started. A section titled *Work in
Progress* is more than two-thirds backlog. This is independent of the by-value question and
would survive any of the four options; it is a selection defect, not an encoding one. Noted
rather than pursued.

### What this does and does not settle

Settled: the byte case for (3) is stronger than assumed, and the specific thing lost is
narrower than assumed. Not settled: whether a recovering session *behaves* correctly against
a digest — specifically whether it recognises the boundary and runs the named command, or
confabulates across it. That is the two-arm probe (arms A/B, `docs/reports/T-3025-iw2-arm-*`),
and confabulation is the failure mode that matters, because per 11a it is the one that looks
like success.

**Still not a recommendation.** IW-1 (cold reader or live session?) remains the operator's
question, and nothing measured here touches it.

## Spike 12 — the two-arm probe, which corrected me

Two `claude -p` workers, identical prompts differing only in which document they received
(arm A: the 275,199 B original; arm B: the 18,762 B digest). Both were forbidden to read any
other file or run any command, told to answer `NOT IN DOCUMENT` plus the command they would
run when the answer was absent, and asked to self-report what they could not determine.
Zero parent context cost. Outputs: `T-3025-iw2-arm-a-full.md`, `T-3025-iw2-arm-b-digest.md`.

### The result I designed for: no confabulation

On the question whose answer the digest deliberately drops (T-2977's last recorded action),
**both arms declined to invent one.** Arm B named the elision precisely — *"the digest states
outright that 114 WIP entries were not embedded … any per-task detail for T-2977 was
deliberately elided"* — and produced the right command. Arm A found the answer genuinely
absent from the full document too, because the generator had written the placeholder
`See git log`. **17 of 119 `Last action` values (14.3%) are that placeholder**, which shrinks
the WIP dump's unique content further than §11b already had.

### The result I did not design for, and which reverses §11c

**The two arms disagree on Q5, and the digest arm is confidently wrong.**

| | Arm A (full) | Arm B (digest) | Ground truth |
|---|---|---|---|
| Is T-2977 in progress? | **No** — `captured`, horizon `later` | **Yes** — "it appears in `tasks_active`" | **No** (`.tasks/active/T-2977…md`: `status: captured`, `horizon: later`) |
| Stated confidence | high | high | — |

Arm B's reasoning was sound given its evidence. The fault is upstream of the digest:
**the handover's frontmatter field `tasks_active:` contains tasks that are not active.**
T-2977 is in that list while being `captured`/`later`. Across the section, 82 of 119 are
`captured` and only 37 are `started-work` (§11d) — so the field mis-describes 69% of its
own contents.

This inverts my §11c conclusion. I wrote that the digest "drops no task identity at all"
because every WIP task survives in `tasks_active:`, and concluded the trade was cheaper than
assumed. That was wrong in emphasis: **the surviving carrier asserts a status that is false
for most entries, and the dropped dump was the thing that corrected it.** The `Status:` line
I dismissed as "one bit in practice, 6.8% of the section" is precisely the bit that stops a
recovering agent from treating 82 parked tasks as live work.

The measurement was right and the inference from it was wrong — I had counted the bits and
not asked what depended on them. A single arm would not have caught this; arm A's answer is
what made arm B's confident answer legible as an error.

### What this changes

Option (3) digest-plus-reference is **not viable as built**. It is viable if either:
- the digest carries per-task status (cheap — `Status` is 4,764 B for all 119, 6.8% of a
  section that is 25% of the file), or
- `tasks_active:` is corrected to mean what it says, in which case the digest inherits the fix.

The second is better and is not really about handovers at all — a field named `tasks_active`
that lists parked tasks is wrong in the full handover too. It is merely *survivable* there,
because the dump immediately below contradicts it. Filed as OBS-276.

### Independently surfaced by arm B: the handover measures the wrong push quantity

Unprompted, arm B flagged as "the one gap that actually mattered" that
`**Branch:** t2539-staging +131 / −0 vs origin/master` does not say whether the branch is
*pushed*. Arm A flagged the same absence. Ahead-of-master and unpushed are different states,
and the rule the handover exists to serve is *"do not end a session with unpushed commits"* —
so the handover reports a different quantity from the one its own discipline turns on. This
session lost hours to exactly that state. Filed as OBS-275; independent of by-value/by-reference
and would survive all four options.

### Standing of IW-2

**Answered, with a condition.** A recovering session does reconstitute from a digest for
everything narrative — arm B answered Q2, Q3 and Q6 with high confidence and correct quotes,
including the session's self-correcting `pgrep`/audit story. It does **not** reconstitute
enumerated live state, and arm B's own closing observation is the sharpest statement of the
residual risk:

> The residual risk is that a section which *looks* answered by five samples reads as
> complete — Q4 is the case in point: I got the numbers right and still cannot act on them.

So: counts-plus-samples is honest about bytes and dishonest about sufficiency. If (3) is
pursued, enumerations should carry a count and a command and **no samples at all**, or the
complete actionable subset (all 12 urgent observations, not 5 arbitrary ones). Five samples
is the worst of both — it costs bytes and buys an illusion.

IW-1 remains untouched and remains the operator's.

## Registered

OBS-272 (the finding). OBS-273 (an unrelated gate catch-22 hit while filing this task).
OBS-275 (handover reports vs-master, not push state — surfaced by both probe arms).
OBS-276 (`tasks_active:` frontmatter lists non-active tasks — the §12 reversal).
