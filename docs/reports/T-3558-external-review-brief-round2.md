# External review brief — ROUND 2: making agents actually consume messages

**For:** the same three independent reviewer models as round 1. **From:** the Agentic
Engineering Framework (AEF), task T-3558, 2026-09-29. **Requested by:** the human
operator, who asked that the existing consumption design be brought into the
discussion and reviewed again.

This brief is self-contained. If you reviewed round 1, section 1 summarises it; if
you did not, section 1 gives you what you need.

---

## 1. Where round 1 left off

Round 1 reviewed a proposal about agent-to-agent **addressing and identity** between
AI-agent projects that communicate over TermLink, a machine-wide message hub.
Background, briefly:

- **AEF** is a governance framework for AI coding agents: nothing gets done without a
  task, the human is sovereign, the agent proposes but never decides, and there are
  no silent failures.
- **TermLink** is a machine-wide Rust binary. Agent sessions find each other through
  it, and messages travel through its **hub** of named topics. It treats `inbox:*` and
  `dm:*` topics as mail, with wake events, receipts and `--await-ack`. It has one
  cryptographic identity per machine user.
- **The circuit id** is AEF's five-level address,
  `host / hub / project / session / agent`, with a fallback ladder that drops the
  rightmost level when the exact recipient is unknown.

**All three round-1 reviewers returned amber**, and all three named the same top
risk, independently:

> the proposal fixes addressing but does nothing to make agents **notice and act on**
> messages, which is the failure that was actually measured.

The measurements behind that: a consult round trip of 73 hours; 49 unread messages
on one peer's inbox; AEF's own inbox holding 7 unread peer messages for about 24
hours, including an explicit request for a status readout. In every case **delivery
worked**: the messages were durably on the hub. **Consumption failed**: nothing made
an agent look.

Round 1 also agreed on: anchor identity at project level; mandatory (not optional)
verification; routing is not privacy; replay protection and key lifecycle are
missing; one machine-checked spec instead of prose rulings. One reviewer added that
separate key files under a single OS user are not a security boundary.

Round-1 consumption proposals, in brief: a mail-read **gate** at session start and
task boundaries; acknowledge on arrival and escalate on silence; separate
*delivered / accepted / completed* states; a synthetic canary message with a deadline.

## 2. New in round 2: this was already designed, ratified, and never built

After round 1 the operator pointed out that AEF had **already designed a consumption
mechanism** in detail. It was found in `docs/architecture/sidecar-target-architecture.md`:
design of record T-3397, ratified as decision D-645 on 2026-09-25.

### The design (D-645)

Every agent runs a **sidecar**: a long-lived receiving process with a durable address
and an API. Sending is a direct call to the receiver's sidecar (push), not a post to a
broadcast topic that the receiver must poll (pull). A reply is the same call with
sender and receiver swapped.

```
 SENDER agent        SENDER sidecar        RECEIVER sidecar          RECEIVER agent
   1 send ──────────►
                      2 API call ─────────────►
                                             3 store message (+ blob, hash-verified)
                                             4 set flag (dirty-bit), atomically after 3
                      ◄────────────────────── 5 CONFIRM-1 "received"
                      6 mark RECEIVED
                                             7 tick: flag set? agent ready?
                                                     └─ ready ─► 8 inject into prompt ──►
                      ◄────────────────────── 9 CONFIRM-2 "handed over"
                      10 mark HANDED_OVER
                                                                  11 agent works
                                             ◄────────────────── 12 reply (= step 1, swapped)
```

- **Two confirmations, because they fail differently.** No "received" means the
  network or the receiving sidecar is down, so retry. "Received" but no "handed over"
  means the sidecar has the message but the agent never got it, so escalate; retrying
  delivery will not help.
- **Store, then maybe inject.** The message is stored before any decision about
  injection, so a busy agent never loses it. Failing toward "not ready" is safe (the
  message waits); failing toward "ready" injects into an agent mid-tool-call.
- **Blobs** (binary attachments) travel to the receiver's sidecar, which has a durable
  address, never session to session. They are hash-verified *before* the flag is set,
  so an agent is never handed a message whose attachment has not arrived.
- **Transport** (ruled 2026-09-25, T-3475): HTTP, because it is the only option that
  works the same on one host and across hosts. TermLink stays underneath for
  discovery, blob transfer and as a fallback carrier.
- **Still open in the design:** the tick cadence (15s proposed, unvalidated), how an
  agent's busy/ready state is determined, prioritisation (deliberately deferred), and
  whether the hub stays as the cross-host carrier beneath the API.

### What was built

| element | designed | built |
|---|---|---|
| transport | receiver API, push | post to a hub topic, broadcast; **inverted** |
| delivery | push | the agent pulls at chosen points; **inverted** |
| receiver storage | stored locally on receipt | not stored, cursors only |
| flag | receiver-side dirty-bit | sender-side bit, consumed on delivery; **wrong side** |
| tick | 15–30s flag check | a 5-minute cron driving a retry ladder; a different thing |
| readiness | checked before injecting | none |
| injection | pushed into the prompt | none; the agent must go and look |
| CONFIRM-1 "received" | yes | **none** |
| CONFIRM-2 "handed over" | yes | **none** |
| blobs | hash-verified, via the sidecar | none |

The only delivery state in the code is `INJECTED_NOW`, which means *the hub accepted
the post*, not that anything reached an agent. The design document itself warns the
name is "actively misleading in exactly the dimension that matters": the ledger reads
healthy while messages sit unconsumed.

### Why it was never built

The build order has eight slices. Slice 0 (a one-line fix) shipped. The transport for
slice 1 was ruled GO. **Slice 1 itself, the receiver process on which every later
slice depends, never received a build task.** An audit exists precisely to catch "GO
recorded, nothing built", and it did not fire: it counts an inception as built when
*any* later task mentions it, and two did (one on related addressing work, one on an
unrelated estimator). So a design that was complete, ratified and prioritised sat
unbuilt for four days, while the framework reported that nothing was owed.

The operator's summary: *"This will be documented and designed and I think even
implemented, but for some reason that's still not working."* Documented and designed:
yes. Implemented: no.

## 3. The message lifecycle, as the operator described it

In the operator's words: the receiver flags a message as received; stores it locally
including binary blobs; checks whether it can be injected into the prompt; a regular
"prompt drop" does that injection; the receiver sends an acknowledgement back through
the same sidecar API; then signals that the message was injected, *"consumed, for
lack of a better word"*; and later that a response is ready and coming back.

**Proposed states** (AEF's proposal; please challenge the names as well as the
states):

| state | meaning | who sets it | on failure |
|---|---|---|---|
| `SENT` | the sender's sidecar made the API call | sender | retry |
| `RECEIVED` | stored and flagged at the receiver (CONFIRM-1) | receiver sidecar | retry delivery |
| `HANDED_OVER` | injected into the agent's prompt (CONFIRM-2) | receiver sidecar | **escalate**: retrying delivery will not help |
| `ACCEPTED` | the agent has taken it on and will answer | receiver agent | escalate on deadline |
| `REPLIED` | the response is composed and sent back as a new message | receiver agent | — |
| `DECLINED` / `ESCALATED` | a terminal outcome other than a reply | receiver agent / deadline | recorded, never silent |

`HANDED_OVER` is proposed over "consumed". "Consumed" suggests the work is done, while
the event is only that the agent now has it; `ACCEPTED` and `REPLIED` carry the rest.
Every terminal non-success is recorded on AEF's refusal ledger, which the operator
approved separately, so failures become visible data rather than silence.

## 4. Questions for round 2

Please answer each in turn, then give an overall verdict.

1. **Is D-645 the right consumption design,** given round 1's findings? What does it get
   right that round 1's own proposals missed, and what does it still miss?
2. **Push versus gate.** D-645 pushes messages into the prompt on a tick. Round 1
   proposed a pull-side gate: no task opens or closes while mail sits unread. Are these
   complementary (push for timeliness, gate as backstop) or redundant? What should the
   gate check if push works?
3. **The security of injection.** A sidecar HTTP API that injects peer messages into an
   agent's prompt is a channel through which a remote party writes into an AI agent's
   context. How must injected content be framed, authenticated and bounded so that it
   is data, never instructions, and so that a request for action goes through AEF's
   task and human-approval path rather than around it? Who may call the API?
4. **The lifecycle states.** Are `SENT → RECEIVED → HANDED_OVER → ACCEPTED → REPLIED |
   DECLINED | ESCALATED` the right states, with the right names? What is missing:
   deadlines, idempotency, retry ownership, what "ready" means?
5. **The open design questions** (tick cadence, readiness predicate, hub under the API).
   What would you decide, and why?
6. **Why designs do not get built.** This design was complete, ratified and prioritised,
   and still stalled after its first slice, while an audit reported it as followed up.
   What structural change would stop a ratified design from stalling silently?
   Consider that AEF already has a refusal ledger and an agent reviewer in progress.
7. **Minimum viable first build.** What is the smallest vertical slice that would prove
   the loop works end to end (one agent sends; another agent actually sees it, acts, and
   replies; the sender sees each state) on this real system, and how would you test it
   so the test itself cannot pass falsely?

## 5. Required answer format

End with a verdict block in exactly this shape:

```
VERDICT: green | amber | red | unknown
  green   = build D-645 as designed, plus any listed refinements
  amber   = sound direction, but it needs the changes listed below first
  red     = do not build D-645 as designed
  unknown = cannot judge from this brief (say what is missing)
GUIDANCE: required for anything other than green. Concrete and actionable.
FIRST SLICE: the one thing to build first, and the test that proves it works.
TOP RISK: the single most important thing that could still make this fail.
```
