# Sidecar — the round-trip loop, and what we should be measuring

**Status:** design · 2026-09-25 · companion to `docs/reports/T-3461-sidecar-architecture-review.md`

Two parts. **Part A** enumerates every hop of the consult loop as it exists in code
today — requestor → hub → receiver → receiver-as-sender → back — including the cron
wheels that drive it. **Part B** designs the telemetry: one record per hop, so we can
answer *how long did each step take* and *where did it fail* instead of inferring both
from a ledger that was built for a different purpose.

Everything in Part A is traced to source. Where a step is currently unmeasured, it says
so — that is the input to Part B.

---

## Part A — the loop

### Cast

| component | file | role |
|---|---|---|
| `fw sidecar send` | `bin/fw` → `lib/sidecar/outbox.py` | writes the durable message, assigns `client_msg_id` |
| outbox | `.context/sidecar/outbox/` | one JSON file per message, the durable record |
| ack ledger | `.context/sidecar/awaiting-ack.jsonl` | append-only, one row per delivery attempt |
| transport | `lib/sidecar/termlink_transport.py` | `termlink channel post` |
| hub | TermLink, `/var/lib/termlink/hub.sock` | the broker; owns topics and offsets |
| inbox reader | `lib/sidecar/inbox.py` | drains topics, owns per-topic cursors + shared seen-set |
| inbox state | `.context/sidecar/inbox-state.json` | cursors and seen-set |
| sweep | `lib/sidecar/retry.py` | the retry ladder's drive wheel |
| **cron: `sidecar-sweep-5m`** | `.context/cron-registry.yaml:24` | `fw sidecar sweep`, every 5 min at `:03,:08,…` |

### The addressing ladder (T-3433)

```
//dimitrimintdev/cacc73ea32b121dd/999-Agentic-Engineering-Framework
  host      hub                project/agent
```
Primary topic `inbox:<circuit-id>`; legacy alias `sidecar:<agent-id>` still live as a
**read** alias. Senders never write the legacy form; readers drain both.

---

### Leg 1 — requestor sends

| # | step | code | what is recorded today |
|---|---|---|---|
| 1.1 | resolve `--to` to a circuit address | `circuit.py` | nothing |
| 1.2 | write durable message + `client_msg_id` | `outbox.write_message` | the file itself (mtime) |
| 1.3 | probe hub reachable | `delivery.deliver` → `probe` | only on failure (`hub-refused:`) |
| 1.4 | post to hub topic | `termlink_transport` | only on failure (`transport-failed:`) |
| 1.5 | write ack-ledger row | `outbox.record_ack` | `state`, `attempts`, `rung`, `next_retry_at`, `deadline`, `ts` |

**State after leg 1:** `INJECTED_NOW`. The docstring at `delivery.py:89` is explicit
about what that does *not* mean:

> *"`INJECTED_*` means the hub took it, not that anyone read it."*

**Unmeasured:** how long 1.2–1.5 took. There is no duration anywhere in this leg — only
a timestamp for when the row was written.

---

### Leg 2 — the message waits in the hub

Hub-side. We can see `termlink channel info <topic>` (post count, senders) but we do not
sample it. **Fully unmeasured on our side:** the interval between injection and the
receiver draining it — which is the single most interesting number in the loop, because it
is the *reader* latency, and reader failure is the dominant failure mode (OBS-482, 832's
@20, OBS-529).

---

### Leg 3 — receiver drains

| # | step | code | recorded |
|---|---|---|---|
| 3.1 | `fw sidecar inbox` (agent at a yield point, or the dispatch preamble) | `inbox.pending()` | cursors advance in `inbox-state.json` |
| 3.2 | read `inbox:<circuit>` **and** `sidecar:<agent>`, shared seen-set | `inbox.py:137` | seen-set grows |
| 3.3 | surface to the agent as text | `bin/fw sidecar inbox` | nothing |

**Unmeasured:** when a message was *available* vs when it was *read*. The cursor moves,
but no timestamp is written with it, so "sat unread for two days" is not derivable after
the fact — it has to be reconstructed from the peer's complaint, which is exactly how
both OBS-482 and 832's @20 were discovered.

---

### Leg 4 — receiver becomes sender (the reply)

Identical to leg 1, with one addition that carries the whole loop: the reply must carry
`metadata.conversation_id` equal to the original. That field is the **only** link between
the two halves. There is no reply-to offset, no thread id, no correlation beyond it.

---

### Leg 5 — the original sender notices the reply, and the row closes

This is where the loop closes, and **this is where it is currently broken.**

| # | step | code |
|---|---|---|
| 5.1 | cron fires `fw sidecar sweep` every 5 min | `cron-registry.yaml:24` |
| 5.2 | load every open ack row | `retry.latest_rows()` + `is_open` |
| 5.3 | compute ladder position | `retry.ladder_position` |
| 5.4 | **peek inbox for answered conversations** | `retry.answered_conversations()` |
| 5.5 | if answered → close the row | `_close(… ANSWERED …)` |
| 5.6 | else work the due rung | `repost` / `nudge` / `operator` |

> **DEFECT (OBS-529).** Step 5.4 peeks **only** `inbox.inbox_topic(me)` — the circuit
> topic. Step 3.2 reads circuit **and** legacy. So a reply that arrives on the legacy rail
> is invisible to the answered-check, the row never closes, and the ladder runs to
> completion on a conversation that *was answered*.
>
> Measured 2026-09-25: circuit topic 6 envelopes / **0** foreign conversations; legacy
> topic 21 envelopes / **8** foreign conversations, including all three that escalated to
> rung 5. `answered_conversations()` returns the empty set.

---

### Leg 6 — the retry ladder (T-3434)

Rungs: `2×1m, 2×5m, 2×15m, 2×1h, 2×4h, 2×1d, 2×1w, 2×1mo` — 16 attempts over ~76 days.

| rung band | verb | effect |
|---|---|---|
| early | `REPOST` | re-post to the hub |
| ~15 min+ | `NUDGE` | post a pointer into the recipient's inbox |
| ~1 day+ | `OPERATOR` | `fw note --tag sidecar` |
| after 16 | dead-letter | |

> **DEFECT (T-3461 §3).** The `OPERATOR` rung writes to `.context/inbox.yaml`: **319
> pending entries, no Watchtower renderer, `fw notify` disabled.** The escalation of last
> resort is silent.

**Composed, the two defects are worse than either alone:** 5.4 manufactures escalations
for answered conversations, and leg 6 delivers those false alarms nowhere. The system
generates noise it cannot hear.

---

### The loop, end to end

```
 requestor                    hub                      receiver
 ─────────                    ───                      ────────
 1.2 write outbox
 1.3 probe ───────────────────►
 1.4 post  ───────────────────► topic
 1.5 ledger: INJECTED_NOW
                               │  ← leg 2: UNMEASURED dwell
                               │
                               ▼
                          3.1 fw sidecar inbox  (yield point / preamble)
                          3.2 drain circuit + legacy, advance cursors
                          3.3 surface to agent
                                   │
                          4.x reply, same conversation_id
                                   │
      ┌────────────────────────────┘
      ▼
 5.1 cron sidecar-sweep-5m (every 5 min)
 5.4 answered_conversations()   ◄── BLIND TO LEGACY (OBS-529)
 5.5 close  ──or──  5.6 repost → nudge → operator notice
                                          └─► .context/inbox.yaml (no reader)
```

---

## Part B — telemetry design

### The principle

Today the ack ledger records **state transitions the sender caused**. It cannot answer
*how long* any step took, and it cannot see anything the receiver did. Every number we
have is about our own outbox.

> The three defects found this week — OBS-482, 832's @20, OBS-529 — are all *reader-side
> or loop-closure* failures, and **none of them were detectable from the sender-side
> ledger.** All three were found by a human noticing, or by a peer complaining.

So the design goal is not more sender detail. It is **one record per hop, from both
ends, joinable on `client_msg_id` and `conversation_id`.**

### The record

Append-only JSONL, `.context/sidecar/telemetry.jsonl`, one line per hop:

```json
{
  "ts":              "2026-09-25T09:41:02.113Z",
  "client_msg_id":   "…",
  "conversation_id": "832-T833-CTL029-AND-REVIEWER-CLOSURE",
  "agent":           "999-Agentic-Engineering-Framework",
  "role":            "sender" | "receiver",
  "hop":             "resolve|write|probe|post|ledger|drain|surface|reply|sweep|close|escalate",
  "topic":           "inbox:…" | "sidecar:…",
  "outcome":         "ok" | "refused" | "failed" | "skipped",
  "duration_ms":     37,
  "attempt":         1,
  "rung":            0,
  "detail":          "…"
}
```

Four fields do the work: `hop` (where), `duration_ms` (how long), `outcome` (did it
work), and the two ids (what it belongs to).

### What each hop must emit

| hop | emitted by | the question it answers |
|---|---|---|
| `resolve` | `circuit.py` | did `--to` resolve, and to which form |
| `write` | `outbox.write_message` | durable-write cost |
| `probe` | `delivery.deliver` | **hub reachability, including when it succeeds** |
| `post` | `termlink_transport` | transport latency |
| `ledger` | `outbox.record_ack` | ledger-write cost |
| **`drain`** | `inbox.pending()` | **when a message was READ, and its dwell since injection** |
| `surface` | `bin/fw sidecar inbox` | did the agent actually see it |
| `reply` | leg 4 | time-to-reply per conversation |
| `sweep` | `retry.sweep` | per-tick: rows walked, due, answered, reposted, escalated |
| `close` | `_close` | **total loop time, injection → close** |
| `escalate` | nudge / operator | and **whether the escalation was itself delivered** |

### The three derived metrics that matter

1. **Dwell** = `drain.ts − post.ts` per message. *How long does a message sit unread?*
   This is the number that would have caught all three known defects. Nothing measures it
   today.
2. **Round-trip** = `close.ts − write.ts` per conversation. *How long does a consult
   actually take?* Currently unknowable.
3. **Escalation precision** = escalations fired ÷ escalations where the conversation was
   genuinely unanswered. OBS-529 means this is currently **near zero** and nobody could
   tell.

### Cross-agent collection

Each agent writes its own `telemetry.jsonl` locally. Joining is the point — dwell needs
the sender's `post` and the receiver's `drain`. Two options:

- **(a) Ship the record over the same rail**, on a `telemetry:<circuit>` topic. Elegant,
  and fails exactly when the rail fails — which is when you most want the data.
- **(b) Each agent exposes its own file; a collector pulls.** More moving parts, but it
  survives the rail being broken. **Recommended**, because the whole motivation is
  measuring a rail we do not trust yet.

Either way the join key is already there: `client_msg_id` is global, and
`conversation_id` is the only cross-agent correlator the protocol has.

### Detectors this makes possible

| detector | fires when | replaces |
|---|---|---|
| dwell-exceeds | any message unread > N hours | a peer complaining |
| answered-but-escalating | escalation fired for a conversation with a reply anywhere | OBS-529, found by hand |
| escalation-undelivered | `escalate` outcome ok but no operator ack | T-3461 §3, found by hand |
| rail-asymmetry | a conversation present on a topic the answered-check does not read | would have caught OBS-529 on day one |

### Staging

1. **Sender hops + `sweep`/`close`** — all inside `lib/sidecar/`, no protocol change.
   Gets round-trip and escalation-precision immediately.
2. **`drain`/`surface`** — receiver side, same files. Unlocks dwell locally.
3. **Cross-agent collection** — needs peer agreement (832, 010-termlink). Propose on the
   rail, with this document as the reference.

### One rule, from this week

**No metric that counts only what our own side did.** `45 delivered` was true and
useless: it counted injections, while a third of the traffic was escalating and every
escalation was silent. A metric that cannot go red is not a metric.

---

## Fix order (recommended)

1. **OBS-529** — `answered_conversations()` reads the same topics `pending()` does. One
   line, plus a control proving a legacy-rail reply closes the row. Stops manufacturing
   false escalations *today*.
2. **The terminus** — enable `fw notify`, render `inbox.yaml`, or route to `/approvals`.
3. **Telemetry stage 1**, then 2.
4. **Then** the dual-address retirement question (needs 832 + 010-termlink).

Doing 3 before 1 and 2 would instrument a system whose known defects are already
diagnosed — measuring a fire we have already located.
