# Sidecar — target architecture (D-645)

**Status:** ratified direction, 2026-09-25 · **Decision:** D-645 · **Design of record:** T-3397

This is the architecture we are building **toward**. It is not what runs today.

The design was settled in T-3397 and then not built: what shipped is hub-broadcast
pub/sub polled by a 5-minute cron — *the exact thing T-3397:81 says the sidecar is not*.
Operator ruling 2026-09-25: **build toward the design, do not ratify the divergence.**

> Companion documents: `sidecar-roundtrip-and-telemetry.md` traces the loop **as built**
> and designs the telemetry. `docs/reports/T-3461-sidecar-architecture-review.md` has the
> live measurements. This file is the target and the gap.

---

## 1. The principle, from T-3397:81

> *"is **not** a hub-broadcast subscriber. It exposes an **API a sending agent calls
> directly**: write a message file, which atomically sets a companion flag file
> (dirty-bit). This is **push, not pull** — the message is durably on disk the instant the
> call returns, before any delivery-timing decision is made."*

Everything below follows from that sentence. The sidecar is a **per-agent receiving
process with an address**, not a client polling a broadcast.

And T-3397:127 — the reply is not a second mechanism:

> *"**Symmetric API**: every agent runs a sidecar; reply is not a separate mechanism, it's
> the same 'call the peer's API' operation with sender and target swapped."*

So there is **one** verb. A round trip is that verb, twice.

---

## 2. The round trip, as designed

```
 SENDER agent            SENDER sidecar        RECEIVER sidecar         RECEIVER agent
 ────────────            ──────────────        ────────────────         ──────────────
   1 send ──────────────────►
                          2 API call ──────────────►
                                                 3 store msg (+blob)
                                                 4 set flag (dirty-bit)
                          ◄────────────────────── 5 CONFIRM-1 "received"
                          6 mark received
                                                 7 tick: flag? busy?
                                                         └─ ready ─► 8 inject ──►
                          ◄────────────────────── 9 CONFIRM-2 "handed over"    │
                          10 mark handed-over                                   │
                                                                     11 agent works
                                                 ◄────────────────── 12 reply
                              (same verb, sender/target swapped — back to step 2)
```

### Step by step

| # | step | owner | notes |
|---|---|---|---|
| 1 | `fw sidecar send --to <circuit> [--blob <path>]` | sender agent | |
| 2 | **API call to the receiver's sidecar** | sender sidecar | push. Durable the instant it returns. |
| 3 | **store message locally**; blob via TermLink file transfer, stored beside it, referenced by content hash | receiver sidecar | see §3 |
| 4 | **set flag file** (dirty-bit) | receiver sidecar | atomic: message fully written *before* the flag exists |
| 5 | **CONFIRM-1 — "received"** → sender's sidecar API | receiver sidecar | first of two |
| 6 | mark the ack row `RECEIVED` | sender sidecar | |
| 7 | **tick: is the flag set, and is the agent ready?** | receiver sidecar | cadence + readiness, §4 |
| 8 | **inject into the agent's prompt** (or tell it where to look) | receiver sidecar | push |
| 9 | **CONFIRM-2 — "handed over"** → sender's sidecar API | receiver sidecar | second of two |
| 10 | mark the ack row `HANDED_OVER` | sender sidecar | |
| 11 | agent does the work | receiver agent | |
| 12 | reply = step 1 with roles swapped | receiver agent | symmetric API |

**Why two confirmations and not one.** They answer different questions and fail
differently. CONFIRM-1 failing means the network or the receiving sidecar is down —
retry. CONFIRM-2 failing means the sidecar has the message but the agent never got it —
*escalate*, because retrying delivery will not help. Today's single `INJECTED_NOW`
conflates both with a third thing (the hub accepted it), which is why the ledger reads
healthy while a third of traffic is escalating.

---

## 3. Binary blobs — TermLink file transfer (D-645)

This leg was **never captured anywhere** before today: zero occurrences of "blob" or
"garage" in any sidecar document or either design task. It exists only in the operator's
memory and this ruling.

**Constraint, measured 2026-09-25:** `termlink file receive` *"only processes fresh events
arriving after the receiver starts"* unless `--replay`, and `termlink file send` targets a
**session ID**, not a durable address. A session is ephemeral; a circuit address is not.

**Therefore blobs do not travel session-to-session.** They go through the sidecar:

1. Sender's sidecar reads the blob, computes a content hash, includes hash + size +
   media-type in the message envelope.
2. Blob is transferred to the **receiver's sidecar** (a long-lived process with a durable
   address), not to a session that may not exist yet.
3. Receiver's sidecar stores it beside the message and verifies the hash **before**
   setting the flag at step 4.
4. CONFIRM-1 carries the verified hash. A hash mismatch is a delivery failure, not a
   message.

**The message is never flagged ready until its blob is present and verified.** Otherwise
an agent is injected with a message referencing a blob that has not arrived — a partial
delivery that looks complete, which is the family of bug this whole design removes.

---

## 4. The tick, readiness, and urgency

**Cadence.** T-3396 IW-2 recorded `5s tick / 30s threshold` as an explicit *unvalidated
placeholder* and deferred it; T-3397 did not settle it. **It is still unsettled.** The
implementation's 5-minute cron is a retry-ladder wheel, not this tick, and should not be
mistaken for a ruling. Proposal: **15s**, the operator's own recollection, cheap because
the tick is a local stat of a flag file. To be confirmed, not assumed.

**Readiness.** T-3397:93-95 specifies a write-time fast path that checks readiness when
the API call lands, and **store-then-maybe-inject** ordering — store first, decide about
injection second, so a busy agent never loses a message. How "ready" is determined is
open: T-3397:109 warns about the dangerous direction — *stale "ready" while actually
busy*. Failing toward "not ready" is safe (the message waits); failing toward "ready"
injects into a mid-tool-call agent.

**Urgency.** The operator explicitly deferred prioritisation. Noted as out of scope, and
the design must not foreclose it: a priority byte in the flag was the leading candidate in
arc-011 §6 and would sit naturally at step 4.

---

## 5. Designed vs built — the gap

| element | designed (T-3397) | built | gap |
|---|---|---|---|
| transport | receiver API, push | `termlink channel post` to hub topic, broadcast | **inverted** |
| delivery model | push | pull (`fw sidecar inbox` at yield points) | **inverted** |
| receiver storage | message stored locally on receipt | not stored; cursors only | missing |
| flag | receiver-side dirty-bit | **sender-side** durability bit (`outbox.py:12`), consumed on delivery | wrong side |
| receiver hook wiring | Stop/UserPromptSubmit raises the flag | `outbox.py:7` — *"separate follow-on"*, never built | missing |
| tick | 15-30s flag check | 5-min cron driving the **retry ladder** | different thing |
| readiness / busy | write-time check, store-then-maybe-inject | none | missing |
| injection | push into prompt | pull by the agent | **inverted** |
| CONFIRM-1 received | yes | none | missing |
| CONFIRM-2 handed over | yes | none | missing |
| blobs | (uncaptured until D-645) | none | missing |
| reply | same API, roles swapped | post to sender's topic | partial |

**Vocabulary warning.** The ledger's `INJECTED_NOW` means *the hub accepted it* — not
*injected into an agent's prompt*. The target architecture uses `RECEIVED` and
`HANDED_OVER` for the two real events. `INJECTED_*` should be renamed when it is replaced,
because the name is actively misleading in exactly the dimension that matters.

---

## 6. Build order

Each slice is independently useful and leaves the system working.

| # | slice | why here |
|---|---|---|
| **0** | **Fix OBS-529** — `answered_conversations()` reads the same topics `pending()` does | One line. Stops manufacturing false escalations *today*, on the current architecture, whatever we build next. |
| **1** | Receiver sidecar process with an API + durable address; store message; set receiver-side flag | The keystone. Everything else hangs off a process that exists. |
| **2** | CONFIRM-1 (`RECEIVED`) + sender ack-row state | First real receipt. Makes "the hub took it" and "the peer has it" different numbers. |
| **3** | Tick + readiness gate + injection (push) | Replaces pull. Needs the cadence ruling from §4. |
| **4** | CONFIRM-2 (`HANDED_OVER`) | Separates "sidecar has it" from "agent saw it" — the distinction whose absence hid OBS-482 and 832's @20. |
| **5** | Blobs via TermLink file transfer, hash-verified before flag | Per §3. |
| **6** | Telemetry per hop (see companion doc), now mapped to real hops | Deliberately after: instrumenting hops that do not exist yet is why the current metrics measure one hop of seven. |
| **7** | Retire the legacy `sidecar:<agent>` address | Cross-project, needs 832 + 010-termlink. |

**Slice 0 is not part of the target architecture** and is still first: it is live, it is
one line, and it is generating false alarms while we build.

---

## 7. Design-conformance requirement register (T-3691)

Each specification requirement R1-R15 (from T-3682 audit) has a tracked owner task.
Arc-011 cannot read healthy while a register row is unowned. Build order is enforced
via the close gate: a slice cannot close while its scope fence defers a register
requirement without naming the owner task for it.

```yaml
register:
  - id: R1
    text: "Push API: message file, then atomic flag file; STORED ack on return"
    source: "T-3397, Amendment 5 IW-3"
    owner_task: T-3402
    status: built
    evidence: "lib/sidecar/outbox.py (T-3402)"

  - id: R2
    text: "Write-time fast path: if the receiver is ready, inject into it now"
    source: "T-3397 §Consumption"
    owner_task: T-3693
    status: built
    evidence: "T-3693: lib/sidecar/inject.py + direct.py inject-on-store when ready; live e2e tests/integration/t3693_sidecar_e2e_test.py 3/3 (docs/reports/T-3693-e2e-*); codex round 4 PASS (docs/reports/T-3693-review-codex.md)"

  - id: R3
    text: "Cron tick, default 30 s, configurable: guaranteed-delivery fallback that injects when ready"
    source: "T-3397 §Consumption; Amendment 5 IW-2"
    owner_task: T-3684
    status: built
    evidence: "T-3684: lib/sidecar/watcher.py run_tick/run_forever, SIDECAR_TICK (lib/config.sh, default 30) — each tick drains the hub inbox topic(s) and injects when ready; live e2e tests/integration/t3684_sidecar_watcher_e2e_test.py (docs/reports/T-3684-e2e-*.json: legacy-topic consult injected by trigger=tick, HANDED_OVER <= 60 s at the default 30 s tick); review docs/reports/T-3684-review-codex.md"

  - id: R4
    text: "Ready flag: Stop hook writes ready-for-input: true; UserPromptSubmit clears it"
    source: "T-3397 §Consumption"
    owner_task: T-3693
    status: built
    evidence: "T-3693: lib/sidecar/hooks.py Stop sets ready, UserPromptSubmit clears first; wired in .claude/settings.json + lib/init.sh; live Stop-hook readiness in docs/reports/T-3693-e2e-run.log; codex round 4 PASS"

  - id: R5
    text: "Urgent bypass: urgent messages inject immediately regardless of state"
    source: "operator decision 2026-09-21, T-3397 IW-1"
    owner_task: T-3684
    status: built
    evidence: "T-3684: lib/sidecar/inject.py choose_target (urgent → a busy session, urgent_bypass recorded); live e2e test_3 — urgent injected while the session's own record was busy, non-urgent only after its Stop (docs/reports/T-3684-e2e-3-busy-urgent.json)"

  - id: R6
    text: "Bidirectional ack: sender sees stored / injected-now / injected-later"
    source: "T-3397"
    owner_task: T-3693
    status: built
    evidence: "T-3693: sender ledger SENT → RECEIVED → HANDED_OVER → REPLIED (+ UNDELIVERABLE/REJECTED/ESCALATED), monotonic (dafbca068); INJECTED_NOW renamed HUB_ACCEPTED (T-3561); live ledger in docs/reports/T-3693-e2e-positive-evidence.json; codex round 4 PASS"

  - id: R7
    text: "Liveness: .context/sidecar/liveness.yaml {identity, seq, last_probe_at, latency}; self-probe every 30 s tick"
    source: "Amendment 5 IW-2"
    owner_task: T-3685
    status: built
    evidence: "T-3685: lib/sidecar/watcher.py write_liveness/self_probe/liveness_verdict — .context/sidecar/liveness.yaml {identity, seq, last_probe_at, last_probe_ok, last_probe_latency_ms} every tick, loopback probe = /health + authenticated /ack; fw doctor + fw audit FAIL when not live (live e2e test_4, docs/reports/T-3684-e2e-4-kill.json)"

  - id: R8
    text: "Per-hub capability probe + version floor before send"
    source: "Amendment 5"
    owner_task: T-3405
    status: built
    evidence: "termlink_transport.probe_hub, VERSION_FLOOR (T-3405)"

  - id: R9
    text: "Receive-side dedupe on client_msg_id"
    source: "Amendment 5 IW-3"
    owner_task: T-3406
    status: built
    evidence: "lib/sidecar/inbox.py:216 (T-3406)"

  - id: R10
    text: "awaiting-ack.jsonl with deadline; past deadline → UNKNOWN"
    source: "Amendment 5"
    owner_task: T-3561
    status: built
    evidence: "outbox.resolve_expired, sweep (T-3418)"

  - id: R11
    text: "conversation_id mandatory, never a bare offset"
    source: "Amendment 1/IW-3"
    owner_task: T-3561
    status: built
    evidence: "message schema"

  - id: R12
    text: "Cross-host direct cross-post, credentials refused loudly"
    source: "Amendments 3/4"
    owner_task: T-3688
    status: partial
    evidence: "same-host only verified; cross-host fenced. T-3688 (S-XHOST) names 'Gap row R12'; T-3690 is legacy-address retirement (T-3694 re-point)"

  - id: R13
    text: "Sidecar-owned retry"
    source: "Amendment 4"
    owner_task: T-3561
    status: built
    evidence: "T-3434 retry ladder"

  - id: R14
    text: "Every agent runs a sidecar (symmetric)"
    source: "T-3397 IW-5"
    owner_task: T-3685
    status: built
    evidence: "T-3685: every claude-fw session (with or without --termlink) starts its receiver + supervised watcher (bin/claude-fw sidecar_start; behavioural unit test_claude_fw_really_starts_the_sidecar runs the real wrapper); fw sidecar start / receiver start for anything else; cron sidecar-ensure-1m + @reboot restart any enabled sidecar on the host; fw doctor / fw audit WARN in any project where none runs (a plain `claude` launch is not covered by a launcher — the WARN is the rail)"

  - id: R15
    text: "Always-on listener per agent session"
    source: "T-3396 title"
    owner_task: T-3685
    status: built
    evidence: "T-3685/T-3684: the always-on watcher pushes into the agent's own TermLink session (per-session readiness, T-3745); its supervisor restarts a dead or hung watcher (unit test_start_supervises_restarts_and_ensure_recovers; live test_4)"
```

## 8. What is still open

- **Tick cadence** (§4). 15s proposed, never validated.
- **Readiness predicate** — how an agent's busy state is determined, and from where.
- **Prioritisation / urgency** — deferred by the operator; must not be foreclosed.
- **Whether the API is HTTP, a unix socket, or a TermLink RPC.** T-3397 says "API" and
  does not pick. Affects cross-host, which Amendment 1 says must be one path, not a
  same-host fast path plus an exception.
- **What happens to the hub.** Does it remain as the cross-host carrier beneath the API,
  or does the API replace it? T-3397's uniform-path amendment implies the former.
