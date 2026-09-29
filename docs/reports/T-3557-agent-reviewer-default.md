# T-3557 — Human review is for risk; everything else goes to an agent reviewer

Research artefact (C-001). Inception opened 2026-09-29 from a walkthrough of
open decisions, when the operator's answer to "item A" (OBS-572) reframed the
delegation model it sat inside.

## Dialogue Log

### Segment 1 — how the question arose

The agent had proposed OBS-572: fix `_ACT_IN_THE_WORLD_RE` so the D-626 delegation
classifier stops treating six criteria as delegable when their steps need the
operator's own hardware or a live session. Examples given, both real:

- **T-1774** — *"End-to-end CLI smoke (after … pi installed)"*; Expected "exit code
  0". The install detector requires `install` + space + word; here it is followed
  by `)`, so it misses, and the classifier calls it mechanical.
- **T-464** — *"Test `/capture` skill in a live session"*. No install or login
  vocabulary at all, so nothing fires.

The agent's stated risk: a delegated reviewer would tick "exit code 0" on a smoke
test that never ran.

### Segment 2 — the operator's answer (verbatim, voice transcript)

> Yes, that's true, because we want to kick out the rubber stamping, it's just a lot
> of friction, so in the end doesn't really have value, and just click, click,
> click, and just pass up. The thinking by this is that we want human in the loop
> for things that have high risk, right? That's all tier 0 or really big UX. But UX
> you can also test yourself, so it's the end, maybe are you fine, but I'll give you
> that feedback anyway. You just tell me it's good and I give you the feedback, so
> it's basically risk. Tier 0, yeah. That is where we need to service to the human,
> right?
>
> What do you mean is the expected result of mechanical check? The expected result
> is a pass, because this and this is the external agent that has revealed it. And
> it says it's good. I've looked at this and this and that's why it's good. Or it
> says it's not good and this is what's needed to bring it to good. Or it says,
> nuclear escalate to human. If it cannot resolve that. No, it's not mechanical. It
> remains very much an evaluation. It's not binary. Mostly it's not binary.
> Sometimes it is, but mostly it's not binary. Interpretation is needed, right?
> That's why we want agent reviewer. And don't put it in a script essay. Agent, you
> do it. And if we can run scripts to assess parts, for instance, are certain fields
> in the database or whatever, is the code corrected? Then that's fine. We can use
> our scripts, but it's not only that. It's not binary. Almost never is.
>
> Test capture scale in the live session. I have no idea what this is about. We had
> a capture because we want to capture conversation with an agent that's not
> locked. So it didn't get lost. But not sure where, how it pops here now.
>
> So. Confused will never get recorded. Yeah, that is the negative recording, right?
> We were talking about that we also want to capture things that don't succeed. And
> act on that.

### What the agent took from it

1. **Course correction — "mechanical" was the wrong frame.** The agent had described
   the reviewer's job as confirming a mechanical Expected clause. The operator
   rejects that: review is *evaluation*, rarely binary. Scripts may inform it; they
   do not constitute it.
2. **The default inverts.** Human for risk (Tier 0, irreversible, sovereign); agent
   reviewer for the rest, including UX — with operator feedback *after* an agent
   green, not a blocking gate before it.
3. **Three outcomes, not two** — good-with-reasons, not-good-with-what's-needed,
   escalate-when-unresolvable. This is `lib/judge_verdict.py` (T-3525): green,
   amber/red with mandatory guidance, unknown.
4. **OBS-572 is superseded, not fixed.** An interpreting reviewer reading T-1774 sees
   it needs a Raspberry Pi it cannot operate and returns *unknown → escalate*. The
   regex patch would have repaired the layer this removes.
5. **"Negative recording" ties to T-3555.** Every non-green verdict and every
   escalation is itself a thing that did not succeed, and belongs on the refusal
   ledger the operator approved minutes earlier.

### On T-464

`/capture` is the skill that saves a conversation to `docs/reports/` so it is not
lost when a session ends (C-001/C-002, origin T-194). T-464 is an old PR task
(PR #6) whose only open criterion is a `[RUBBER-STAMP]` "try `/capture` in a live
session". It surfaced here only because the regex misclassified it. It is exactly
the click-through the operator wants gone — and under this model it would be judged
by the reviewer, not queued for the operator.

## Findings

### F-1 — The verdict contract exists; the judging agent does not

| component | exists? | what it is |
|---|---|---|
| verdict vocabulary | yes | `lib/judge_verdict.py` — green/amber/red/unknown, guidance mandatory on non-green |
| judging doctrine | yes | D-662 — separate parties, can refuse, criteria + goal hierarchy |
| isolated execution | yes | `lib/termlink_worker.py` (`--dispatch`) |
| **an agent that interprets** | **no** | every judge (`fw reviewer`, BVP judge, arc-driver judge) runs static code; `--dispatch` runs the same static code in a worker |

### F-2 — The operator's desk, today

353 open Human criteria across 329 tasks (`fw reviewer surface`, 2026-09-29, after
T-3554):

| class | n |
|---|---|
| render-surface | 197 |
| unclassified | 62 |
| act-in-the-world | 22 |
| sovereignty-field | 22 |
| taste | 21 |
| inception-decision | 18 |
| tier0-or-bypass | **11** |

Under the operator's rule, the floor of what must stay human is the 11 tier-0
criteria, and the ceiling is roughly 11 + 22 + 22 + 18 = 73, depending on IW-1 and
IW-2. So between 280 and 342 of 353 criteria — **79% to 97%** of today's human
review load — would move to the agent reviewer.
