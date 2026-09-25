# T-3484 — BVP value/cost signal design: the research trail

**Design output:** `docs/architecture/bvp-feedback-loop.md`
**Authorising decision:** T-3482 GO, operator, 2026-09-25T21:56:30Z (Watchtower)
**Predecessors:** T-3470 (triage that exposed the flat scorer), procAsFit round 3

This is the C-001 artifact — the reasoning, the measurements, and the dialogue
that produced the design. The design itself is the architecture doc above.

## 1. Where this came from

procAsFit round 3 ran the real bvp-estimator across the 39-task hygiene backlog
and found a **structural no-op**: the v1 heuristic collapses the entire family
into two near-identical patterns (`D1=4 D2=0 D3=2or3 D4=2`) because every task
in it is *worded* the same way — "fw X is blind to Y". Cost was worse:
`blast_radius` is structurally `None` before completion (T-3068).

So selection could not discriminate, and the round honestly reported no eligible
work rather than manufacturing some. The operator's response was to revamp BVP
rather than patch the backlog — which is the correct level to fix it at.

## 2. Measurements taken before designing anything

| question | measured | answer |
|---|---|---|
| Do we have human value labels to learn from? | tasks with confirmed `bvp_scores` | **0** — across the entire corpus |
| Do we have measured cost? | episodics with a footprint | **2,988** |
| Do we have cost predictions to compare against? | tasks with `cost_estimate` | **817** |
| Can cost be attributed per task? | `dispatches.jsonl` | `task_id` + 4 token fields on **1,107 of 2,565** rows |
| Is there an operator-correction signal already? | `feedback-stream.yaml` | **1,970** entries, 956 KB, nothing reading it for value |

**The finding that reframed the whole design: zero confirmed scores.** The
sovereignty boundary documented at `lib/bvp.sh:799` has never once been
exercised. Two consequences:

1. Removing the human from scoring **removes nothing in practice**. The ruling
   ratifies the actual state rather than changing it — which lowers the risk of
   the change considerably.
2. There is **no historical value label**. Cost is a calibration problem with
   data waiting; value is a *construction* problem where the signal must be
   created. They cannot be built the same way.

## 3. Dialogue Log (C-001 extension)

### Operator, on cost
> *"we have the cost … we can ask about the real token usage for a task or an
> arc, right? We can query that in detail."*

**Checked rather than agreed.** Partly true, and the shape of the partial
matters: `fw costs` is session-level only (177 sessions, 12.6B tokens, no task
dimension), but `dispatches.jsonl` carries `task_id` alongside full token
accounting. So **dispatched work has real per-task cost today; parent-session
work has none.**

First pass I got this wrong in both directions — asserted attribution existed
(from a bare `grep -c tokens`), then asserted it did not (the last row happens
to lack the fields). The third look established the actual distribution. Recorded
because the error was *confident measurement of the wrong thing*, twice, which is
the failure mode this whole loop is meant to catch in the scorer.

### Operator, on value
> *"you can ask how it's being used. And also quality is how much rework we have
> to do, and how much you have to be corrected by me … if a lot of correction and
> rework, the value goes down. And if it's used well, the value goes up. And you
> can also ask me whether it worked."*

Three distinct signals, and they were **not** all the same axis:

- **Usage** → value.
- **Rework + operator correction** → *not* value. It measures the **delivery**.
  A high-value feature built badly and a low-value feature built badly score
  identically, and the correct response differs (rebuild versus drop). Split
  into its own QUALITY axis (IW-3).
- **"Ask me whether it worked"** → the **revisit**, and the keystone. It is the
  only proposed signal that closes the loop on a *decision* rather than on a
  delivery.

### Operator, on the revisit
> *"After the implementation … we should measure if it's actually being used, and
> used effectively. And then you can do a review and ask me if it worked well."*

The corpus already contains the failures this catches: **arc-020** shipped
complete, tested, and sat unused for weeks because nothing asked "is anything
calling this?"; **185 GO-recorded inceptions** whose propagation nobody checked.

Design consequence: reuse `revisit_at` (T-1451) and the existing G-053 scan
rather than inventing a trigger. The mechanical half runs unattended; the
operator question is the **only** human step in the loop.

### Operator, opening the field
> *"on the value factor, I'm very much open for other ways to measure that."*

### Operator, the strongest contribution
> *"consider using other agents to measure usage and utilization … If other
> agents adopt a feature too, that might be a good indication of value."*

**This is the best signal in the design, and it is the operator's.** 832,
010-termlink and 1409-sprind vendor this framework and choose independently what
to adopt. They have **no stake in our self-assessment** — making cross-agent
adoption the only **non-circular** value evidence available. Every other signal
in the design is produced by the system being judged.

Its limit, recorded rather than smoothed: adoption lags peer upgrade cadence
(010-termlink is on v1.6.29 against our v1.7.120), so **absence is ambiguous**
between "not valuable" and "has not upgraded". The peer's pinned version is
therefore stored beside the answer so the ambiguity stays visible.

## 4. The circularity trap, named early

*"Did the task get worked"* looks like a value signal and is not. We rank by
score and work the top, so **the score caused the outcome**. A loop trained on
that converges on confirming itself — it would report improving accuracy while
learning nothing.

Only signals produced **outside** the ranking count: peer adoption, the operator
revisit verdict, usage by someone who did not file the task.

## 5. The control that replaces the removed gate

Removing confirmation without a replacement control violates D2 (*no silent
failures*) by construction. The replacement is a **degenerate-scorer alarm**:
near-zero variance across a task family means the scorer is not discriminating.

That is the automatic form of what round 3 found by hand — and note **no human
had noticed it either**, through months of the confirmation gate existing
unused. The alarm is not a downgrade from human judgement; it is the first time
this condition would be checked at all.

**S2 before S3 is the one non-negotiable ordering.** Auto-applying a scorer
already proven flat would industrialise the defect the revamp exists to remove.

## 6. Open, and deliberately not decided here

- **IW-1** cost attribution inside a parent session — named, not closed
- **IW-6** the human returns at revisit time. Not drift: it moves the human from
  *predicting* value (which the scorer does badly and the human never did at all)
  to *confirming realised* value against evidence. Stated so a later reader does
  not infer the boundary crept back.
- The **cold start** — calibration cannot run until enough realised rows exist.
  Until then the loop observes only, and should say so rather than adjust a
  rubric from three datapoints.
