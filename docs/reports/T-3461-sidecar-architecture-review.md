# T-3461 — Sidecar architecture review

**Date:** 2026-09-25 · **Status:** exploration complete, awaiting operator decision

Two questions were asked: *is there a good architectural description of Sidecar*, and
*is it working*. The answers are **no** and **partly — with one defect that undoes the
rest**.

---

## 1. Is there an architectural description? (IW-1)

**No.** `docs/architecture/` contains exactly two files, both about parallel execution,
both last touched 2026-06-11. Neither is about Sidecar.

What exists instead is three per-slice reports, each good in isolation and none describing
the whole:

| document | lines | last change | covers |
|---|---:|---|---|
| `docs/reports/T-3396-peer-consult-sidecar-inception.md` | 350 | 2026-09-21 | origin, findings, dialogue log, cross-host amendments |
| `docs/reports/T-3433-circuit-addressing.md` | 183 | 2026-09-22 | the address scheme only |
| `docs/reports/T-3434-retry-ladder.md` | 204 | 2026-09-22 | the retry ladder only |

Each answers *why this slice is shaped this way*. None answers *what is Sidecar, what are
its parts, what flows between them, what must be true for it to work, and how does it
fail*. Reconstructing that today requires reading all three plus `lib/sidecar/*.py` and
`bin/fw sidecar`.

**The concrete cost is visible in this very review.** Establishing how a message reaches
an operator took six separate probes across the ledger, the retry module, the notify
config and the web tree. That is a question a one-page data-flow description answers in a
sentence.

---

## 2. Is it working? (IW-2, IW-5)

### What the dashboard says

```
messages total:   45   pending: 0
ack ledger:       STORED 0  INJECTED_NOW 45  INJECTED_LATER 0  UNKNOWN 0
expired unswept:  0
dead letters:     0
```

`fw audit` renders this as `[PASS] Sidecar ledger: 45 consult(s), 45 delivered, 0 in
flight, 0 UNKNOWN, 0 dead-lettered, 0 expired-unswept`. Read cold, that is a healthy
channel.

### What the ledger says

Collapsing `.context/sidecar/awaiting-ack.jsonl` (302 rows) to latest-state-per-message:

| final rung | messages |
|---|---:|
| 1 | 22 |
| 4 | 1 |
| **5** | **14** |
| (none) | 8 |

**15 of 45 messages — one in three — climbed to rung 4 or 5, taking 10-12 attempts, and
14 of them terminated in `escalated:operator — operator-notice-sent`.**

By peer, for the escalated 15: `832-Workflow-designer` ×4, `010-termlink` ×4, our own
dispatch-worker topics ×3, e2e test responders ×4.

Both statements are true at once. Nothing was lost; a third of the traffic could not be
made to produce a reply by any automated means. **The two numbers measure different
things, and only the flattering one is on the dashboard.**

### The ladder itself works

This is worth saying plainly because the defect below is not the ladder's fault. Messages
re-posted, escalated through nudges, and recorded every transition with a timestamp and a
disposition. Reconstructing the history of any message was straightforward. The mechanism
does what T-3434 designed it to do.

---

## 3. The defect that undoes the rest

The ladder's final rung escalates to a human. Following that hop:

`lib/sidecar/retry.py:163 default_operator_notice()` → `fw note ... --tag sidecar` →
`.context/inbox.yaml`.

Three facts about that destination, each measured today:

1. **`.context/inbox.yaml` holds 524 observations, 319 of them `pending`.** 27 carry the
   `sidecar` tag — the escalations themselves.
2. **No Watchtower blueprint or template reads that file.** `grep -rln 'inbox.yaml' web/`
   returns nothing. The function's own docstring says so, citing T-3434's check.
3. **`fw notify status` reports `Enabled: false`.** The push channel is configured
   (`NTFY_URL` set, dispatcher found) and switched off.

So the escalation path is: message unread by peer → retry → nudge → **notice deposited in
a 319-deep queue with no renderer and no push**.

> **The last rung of an escalation ladder built to recover from "nobody read it" terminates
> in a queue nobody reads.**

This is the third instance of one class in this system within a week:

- **OBS-482** (ours) — 832's rail had no consumer at all; a clause-2 answer sat unread for weeks.
- **832's @20** (theirs, self-reported today) — their inbox *had* a consumer that never
  looked; our replies sat two days while a nudge ladder climbed to rung 4 over ten attempts.
- **This** — our operator escalation lands in an unrendered file.

832 put it better than I would: *"An escalation ladder that reaches rung 4 and is still
not read is not a delivery failure, it is a READER failure, and a nudge that nobody
consumes is indistinguishable from no nudge at all."*

---

## 4. Two smaller findings

### IW-3 — identity fingerprint unresolvable while the hub is up

`fw sidecar whoami` reports `identity fp: - (termlink unreachable)`, yet `termlink hub
status` reports `Hub: running (PID 3071124)` on `/var/lib/termlink/hub.sock`, and messages
are flowing (last delivery 2026-09-25T08:48). So "termlink unreachable" is a **specific
identity-lookup failure wearing a general connectivity message**. The DM rail (T-3405) is
keyed on that fingerprint. Not diagnosed further here; the misleading wording is itself
worth fixing, because it invites exactly the wrong conclusion.

### IW-4 — both addressing schemes are live simultaneously

T-3433 moved addressing from `sidecar:<agent>` to `inbox:<circuit-id>`. The cursor list
shows **both, with independent offsets**:

```
sidecar:999-Agentic-Engineering-Framework@21
inbox:cacc73ea32b121dd/999-Agentic-Engineering-Framework@6
```

21 messages consumed on the legacy address, 6 on the new one. `fw sidecar status` lists
both under `inbox topics:`, so the *reader* covers both — the transition is safe as
implemented. But a peer holding only one address reaches only that queue, and the two
have no shared offset. 832's traffic arrives on the legacy topic while our own workers
post to circuit topics. This is a live dual-write with no stated retirement date.

Also visible: ~40 `sidecar:t34xx-*` topics sitting at `@0` — per-dispatch worker inboxes
created and never read, because the worker exits before anything arrives.

---

## 5. Disposition

| | question | disposition | evidence |
|---|---|---|---|
| IW-1 | coherent design description? | **answered: no** | `docs/architecture/` has 2 files, neither about sidecar; design spread across 3 per-slice reports + code |
| IW-2 | is it delivering? | **answered: yes, but the metric is wrong** | 45/45 injected; 15/45 needed escalation; dashboard shows only the former |
| IW-3 | DM rail down? | **deferred** | hub is up, messages flow, but identity fp unresolvable — needs its own diagnosis |
| IW-4 | legacy address retired? | **answered: no, both live** | `sidecar:…@21` and `inbox:…@6`, independent offsets |
| IW-5 | retry ladder in practice? | **answered: works, terminus does not** | 14 messages to rung 5 over 12 attempts, all landing in an unrendered 319-deep queue |

---

## 6. Recommendation

**GO**, on two bounded pieces of work, in this order.

**First — fix the terminus.** The escalation rung is one line of code pointing at a
destination with no reader. Options, cheapest first: enable `fw notify` (the server is
already configured); render `.context/inbox.yaml` in Watchtower; or route sidecar
escalations to a surface that already has a reader (`/approvals`). Any of the three makes
the existing ladder real. Doing none of them means the other 95% of the mechanism is
load-bearing on a dead end.

**Second — write the missing architecture document.** One page: components, the message
lifecycle from `send` to `ack`, the addressing ladder, the retry schedule, and the failure
modes with their detectors. The three slice reports become its references rather than its
substitute. This review is most of the raw material.

**Not recommended:** further Sidecar feature work before the terminus is fixed. Adding
capability to a system whose escalation path is a no-op increases the volume of unread
escalations.

**Deliberately not decided here:** whether to retire the legacy `sidecar:<agent>` address
(IW-4) — that is a cross-project coordination call affecting 832 and 010-termlink, not
ours alone. And the IW-3 identity-fingerprint failure needs diagnosis before anyone can
say whether it is a bug or a configuration gap.

---

## 7. A note on this review's own instrumentation

This task carries `voi_score: 0.5` — the template default — and the estimator scored all
nine BVP drivers as `2 (no-signal)`. 832 independently measured the same class today and
reported it in their @19: 42 of their 45 inceptions carry the same default, and
`voi_score` is the *entire* composite for an inception. So this review's own priority
score is an abstention rendered as a number. It did not affect the work, but it is a
worked example of their finding arriving in our corpus while we read their message about it.
