# The universal message retry ladder

**Task:** T-3434 · **Decision:** D-600 (operator ruling, 2026-09-22) · **Arc:** arc-011
**Resolves:** OBS-447 · **Residual:** OBS-472

One retry schedule, shared by every framework message kind. The sidecar is the
first consumer; the library (`lib/retry_ladder.py`) knows nothing about it.

---

## 1. The schedule

Sixteen attempts across eight rungs, doubling out from a minute to a month:

| Rung | Interval | Attempts | Posted → verb | Un-posted → verb |
|-----:|---------:|---------:|---------------|------------------|
| 0 | 1 min  | 1–2   | repost | repost |
| 1 | 5 min  | 3–4   | repost | repost |
| 2 | 15 min | 5–6   | **escalate:nudge** | repost |
| 3 | 1 h    | 7–8   | escalate:nudge | repost |
| 4 | 4 h    | 9–10  | escalate:nudge | repost |
| 5 | 1 d    | 11–12 | **escalate:operator** | repost |
| 6 | 1 w    | 13–14 | escalate:operator | repost |
| 7 | 30 d   | 15–16 | escalate:operator | repost |
| — | — | 17th | **deadletter** | deadletter |

Total span **6,604,920 s ≈ 76 days**. Re-derive rather than trust this table —
`python3 -c "import sys; sys.path.insert(0,'.'); from lib import retry_ladder; print(retry_ladder.describe())"`
prints it from `LADDER` itself.

Attempt 1 is made in-process by the producer. Every later attempt is made by
whatever periodic sweep drives the ladder — for the sidecar, the existing
`sidecar-sweep-5m` cron. The first two rungs are finer-grained than the sweep
that drives them; a rung that comes due between sweeps simply fires on the
next one, which costs at most five minutes on a ladder measured in months.

## 2. The two failure classes

D-600's central distinction. A message can fail in two ways that look
identical in a naive ledger and need opposite responses.

**Class A — it never reached the hub.** The transport raised, or the hub
capability probe refused the target. The ack ledger holds `STORED` with an
`error`. The recipient has *nothing*, so the verb is **repost** on every rung
until the ladder is exhausted. There is nothing to escalate about: no one has
been ignoring anything.

**Class B — the hub holds it and nobody read it.** The ledger holds
`INJECTED_NOW` / `INJECTED_LATER` and no reply has arrived on the
conversation. Re-posting the same body into the same unread topic adds noise
without adding reach, so from the **15-minute rung** the verb becomes
**escalate:nudge** — one short pointer message to the recipient's
project-level inbox topic, carrying its own message id, saying *something of
yours is unread and here is where*. From the **1-day rung** it becomes
**escalate:operator**: a `fw note` observation naming the peer, the
conversation and the attempt count.

Below the 15-minute rung both classes repost, because within the first few
minutes there is nothing to escalate yet — the recipient may simply not have
looked.

**Why `INJECTED_*` is still an open ladder position.** It is a *terminal ack
state* and that stays true: the three-state machine (`STORED` →
`INJECTED_NOW | INJECTED_LATER | UNKNOWN`) is untouched by this task. What
changed is that the ladder tracks something the ack state was never asked to:
the hub taking a message is not the recipient reading it. Ladder position
lives in three new *data* fields on the row — `attempts`, `rung`,
`next_retry_at` — not in a fourth state.

`rung` looks backward (the rung this attempt was made on); `next_retry_at`
looks forward. Keeping the two on different clocks is what lets a forensics
reader answer *where was it, and when is it next* from one row.

## 3. Why the receiver MUST dedupe

This is the part that is not optional, and the reason it is not is a
measurement rather than a preference.

TermLink's dedupe on `--client-msg-id` is **hub-side, keyed
`(sender_id, client_msg_id)`, and TTL-bounded** — default 5 minutes. Measured
live in T-3405 against termlink 0.11.1766 on topic `sidecar:selftest-T-3405`:
the original landed at offset 0; two re-posts ~2 minutes later were absorbed
(the topic count stayed at 1); a re-post at **+15m39s appended as offset 2 — a
duplicate**.

TermLink's design assumes a sender gives up inside that TTL. **This ladder
deliberately does not.** From rung 2 onward every re-post is past the window,
so the hub will accept it as new and only the receiving side can collapse it.
We diverge from their assumption knowingly, and told them.

The consequence is a hard rule:

> **Every consumer of this ladder must dedupe on the message id at the
> receiving end.** A producer that adopts the ladder without a receiver-side
> seen-set has not adopted the ladder, it has adopted a duplicate generator.

State of the three receive paths as of T-3434:

| Path | Dedupe | Keyed on | Note |
|------|--------|----------|------|
| `lib/sidecar/inbox.py:pending()` | yes (T-3406) | `metadata.client_msg_id` | bounded seen-set, `SEEN_CAP=500` |
| `fw pickup process` | yes (pre-existing) | SHA256 of normalised content, 7-day cooldown | **not** keyed on a message id; see below |
| `fw bus receive` | **added here** | envelope `client_msg_id` | `fw dispatch send` now mints the id; `BUS_SEEN_CAP=500` |

Pickup was left alone deliberately rather than given a second, parallel
dedupe: it already collapses an identical re-post, and two dedupe mechanisms
on one path is how they drift. But its 7-day cooldown is **shorter than the
ladder's 1-week and 1-month rungs**, so a re-post at day 8+ would be processed
twice. That is not a live defect — the ladder's only producer today is the
sidecar, and pickup is not yet a consumer — but it must close before pickup
adopts the ladder. Filed as **OBS-472**, not fixed here, because widening the
cooldown is a governance change: the 7-day window exists so that a concern
re-raised later reads as a *new* signal rather than an echo.

The sidecar's own envelope carries `client_msg_id` in `metadata` (and in
`cv_key`) precisely so the receiver has something to key on — the CLI flag
alone is out-of-band and is never echoed into the envelope (T-3405).

## 4. Dead-letters

After the sixteenth attempt the ladder gives up: state `UNKNOWN`, error
`ladder-exhausted`. A second, rarer give-up is `ladder-unretryable` — the
durable message file went missing, so there is nothing to re-post and nothing
to point at.

Both are surfaced as their own audit class rather than folded into `UNKNOWN`,
because the remedies differ. An `UNKNOWN` the ladder is still working needs
patience. A dead-letter needs a human to decide whether a message nobody could
be reached with in ~76 days still matters — and "that peer was unreachable for
two and a half months" is itself the finding.

`fw_sidecar_ledger_facts` appends `DEAD_LETTERS` as a sixth tab-separated
field (five-field readers keep working); `check_sidecar_ledger` in
`agents/audit/audit.sh` WARNs on it by name.

**One retarget was load-bearing.** `expired_unswept` used to mean *STORED with
its 30-second transport deadline in the past*. Under the ladder a STORED row
is legitimately **held** for a rung's worth of time with that deadline long
gone, so the old test would have WARNed *"the sweep cron is not running"* on
every in-flight message — a permanent red with no defect behind it.
`expired_unswept` now means *`next_retry_at` is in the past*: a rung came due
and no sweep worked it, which is the thing the counter was always trying to
say. Pre-T-3434 rows with no ladder fields still fall back to the deadline
test.

## 5. What the sweep will not do

- **It will not adopt a delivery made before the ladder existed.** 34 such
  rows were live when this shipped; re-opening every consult the project ever
  delivered would fire a month of nudges at peers about finished
  conversations. A pre-ladder row still `STORED` *does* join at rung 0 — it
  never reached anyone, which is exactly the case the ladder is for.
  A row can also be **released** — `error` prefixed `released:` — which is the
  ladder letting go of something that was never its to work. It is deliberately
  distinct from `answered` (the peer replied) and from `ladder-*` (the ladder
  tried and gave up), so it is never counted as a dead-letter. It was needed
  immediately: 22 pre-ladder deliveries were adopted in the ten-minute window
  between the sweep landing and the guard above landing, and without a release
  marker each would have walked to an operator `fw note` within a day —
  22 observations about conversations that finished weeks ago.
- **It will not advance the inbox cursor.** Reply detection is a peek from
  cursor 0. `fw sidecar inbox` owns that cursor, and a sweep that consumed an
  agent's unread consults to decide whether to retry would be worse than the
  problem.
- **It will not ask the hub whether a message was delivered.** The
  out-of-band guarantee from T-3417 carries through unchanged: every number
  comes from our own durable files. One hub read per sweep, and it reads our
  own inbox for *replies* — not the hub's opinion of our sends.
- **It will not raise on a transport failure.** A failed re-post is simply
  the next attempt, and the ladder already knows what to do with it.

## 6. What `urgent` will change (pointer only)

`urgent` is accepted as a parameter by `next_attempt`, `rung_for` and
`verb_for`, and **raises `NotImplementedError`** with a pointer to this
section. That is deliberate: D-600 rules that URGENT *compresses* the ladder,
and rules equally plainly that the compression is designed in a separate
conversation. The parameter exists so a caller can thread the flag through
today and get a loud, locatable failure instead of a silent normal-priority
send.

What is known, and nothing more: compression means the early rungs shorten and
the escalation rungs arrive sooner — a different `LADDER`, not different
verbs. What is **not** decided and is out of scope here: how many rungs an
urgent ladder has, whether it dead-letters sooner or merely escalates sooner,
whether URGENT changes *who* is escalated to (operator first rather than
recipient-inbox first), and how an urgent message interacts with a receiver
whose dedupe window it now fits inside. Do not infer any of those from the
shape of the normal ladder.

## 7. Verification

```
python3 -m pytest tests/unit/test_retry_ladder.py -q          # 49, every rung boundary
python3 -m pytest tests/unit/test_sidecar_sweep.py -q         # 17, ladder walked rung by rung
python3 -m pytest tests/unit/test_sidecar_delivery.py -q      # 10, ledger fields on every row
bats tests/unit/sidecar_audit_rail.bats                       # 10, dead-letter class
bats tests/unit/lib_bus.bats                                  # 29, bus-leg dedupe
bin/fw sidecar sweep --json                                   # live, against the real ledger
```

The 76-day ladder is exercised in milliseconds because time is injected
end to end: `retry.sweep(now=...)`, `delivery.deliver(now=...)`, and
`fw sidecar sweep --now <iso>` on the CLI the cron calls.
