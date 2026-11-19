# T-3496: choosing which inception to work first

Research artefact for T-3496 (reopened 2026-11-19). Original question: `voi_score` is a
required field that is 0.5 on almost every inception — estimate it, retire it, or accept it.

## Dialogue Log

### 2026-11-19 — walkthrough of the ready inceptions, item 2 of 6

**Agent presented** the three September directions and recommended **retire** (GO, option 2):
a number that is identical on 99% of inceptions only looks like a signal; the lifecycle map
(T-5227: owner + revisit date) already orders them.

**Operator, verbatim:** "What you're missing is, if I have 100 inception's, reflect on this,
also store this somewhere, learn from this, and we want to choose between which [inception]
we do first, how do we do that? Think about that. What would be helpful for that?"

**Course correction.** The agent answered "is this number useful?" and dropped the need the
number was created for. The lifecycle map says *who* holds an inception and *when* to look
again; it does not say *which of 40 agent-held inceptions to do first*. Retiring the field
would have removed the only place the framework even tried to answer that. The question is
not estimate / retire / accept; it is: **what makes "which inception first" decidable?**

## Reflection (the lesson)

- A field that is constant is evidence the **judgement was never made**, not that the
  **need is absent**. Fix the source of the judgement before removing its slot.
- Value of information was the right concept and the wrong mechanism: it asked a person
  (or agent) to guess one number with no inputs, and the template's default answered for them.
- A usable order needs inputs that are **observed**, not guessed, and it must **show its
  reasons** so the operator can disagree with a specific reason rather than a number.
- It must **learn**: the operator's actual choices are the ground truth the order is
  calibrated against.

## What would help choose (candidate shape, to be tested by IW-1..IW-4)

Value of answering (what it is worth now):
1. **What it unblocks** — build tasks, other inceptions, peers waiting on the answer.
2. **Who is waiting and since when** — operator, a peer project, an agent; days waiting.
3. **Cost of delay** — something broken or stuck until it is answered (e.g. 1409's 20 parked
   units while T-5224 is open) versus "nice to know".
4. **Reach** — how much it touches (components, consumer projects, the install surface).

Cost to finish:
5. **Distance to a decision** — questions filed, how many disposed, exploration left.

Then: an order computed from 1-5 with the reasons printed per inception ("unblocks 3 builds,
1409 waiting 6 days, 2 of 4 questions disposed"), the agent's own judgement as one named,
reasoned adjustment, and a log of which inception the operator actually takes first, so the
weights can be compared with real choices and adjusted.

## Measurement 2026-11-19 (read-only, 67 active inceptions)

| Signal | Inceptions carrying it |
|---|---:|
| `waiting_on` set (agent 40 / operator 17 / peer 10) | 67 |
| mentioned by at least 1 other active task | 25 |
| mentioned by at least 3 other active tasks | 13 |
| real IW questions filed | 19 |
| all filed questions disposed | 5 |
| `related_tasks` declared | 11 |
| `arc_id` declared | 11 |
| `components` declared | 6 |

Reading: "who is waiting" exists everywhere (T-5227). "What it unblocks" exists mostly
**implicitly** — other tasks mention the inception (25 of 67) but only 11 declare
`related_tasks`. Distance to a decision is measurable only where questions are filed
(19 of 67). Reach (`components`) is almost never declared on inceptions. So a derived order
can start from waiting + mentions + question progress; reach and cost of delay need a way to
be recorded.

## Calibration log (operator picks vs the v0 order)

| Date | Group | v0 put first | Operator picked | Operator's reason | What it says about the weights |
|---|---|---|---|---|---|
| 2026-11-19 | waiting on the agent | T-3682 (named by 6 tasks, no questions filed) | T-4834 | "it only needs the verdict" | closeness to a decision outweighs being named by other tasks; an inception with no questions filed should not lead |

Follow-up found while acting on the pick: T-4834's one question counted as disposed because
it was *deferred to the operator*, though an agent review was still owed. v1 should treat
"deferred to the operator" as answered only when the task text owes no agent work.

v0 also put the per-project framing right: the list is per project; 055 has no role
(operator reflection 2026-11-19, "This is a per project, right? ... it has nothing to do with
fleet cockpit").

## Open

IW-1..IW-4 in the task file. Next step: a read-only prototype that prints the computed
order with reasons for today's 67 inceptions, shown to the operator beside their own
choice of "first" — the first data point for IW-4.
