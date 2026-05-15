---
proposal_id: PROP-T-1804
source_repo: 999-Agentic-Engineering-Framework
source_task: T-1804
target_repo: termlink (DimitriGeelen/termlink)
status: draft
created: 2026-05-13
---

# Proposal: cross-agent conversation substrate — joint AEF + TermLink design

## Context (read this first)

The Agentic Engineering Framework (AEF) is rebuilding its dispatch model so the parent Claude Code session ("Agent") composes a Delegation envelope from a Workflow and dispatches a Worker (Task tool sub-agent, or `claude -p` via TermLink, or `pi` RPC). See `CONTEXT.md` in 999-Agentic-Engineering-Framework for the full domain language.

A recent grilling session (T-1687) surfaced the question: **what should a Worker do when it hits mid-dispatch ambiguity whose severity × likelihood crosses a non-recoverable threshold?**

Three options were considered:

- **(a)** Guess + post-hoc outcome evaluator catches bad assumption → re-dispatch.
- **(b1)** Worker emits `pause_requested` terminal_event, exits cleanly, operator answers via Watchtower review queue → Agent re-dispatches.
- **(b3)** Worker consults a peer agent (reviewer / specialist / orchestrator) for a second opinion before escalating to operator. **Cheaper than (b1) in operator-latency terms.**

v1 will ship (a) + (b1). (b3) requires substrate that doesn't fully exist today: persistent multi-party conversation between agents with bounded round-trip latency, wakeup-of-non-running-agent, and audit trail. This proposal is about that substrate.

## The seam (proposed split)

| Layer | Owns |
|-------|------|
| **TermLink** | Transport: channels, events, topics, inbox, delivery confirmation, cross-machine relay, session discovery, PTY inject. Stays general-purpose. |
| **AEF** | Semantics: when to consult, task-context anchoring (T-XXX), envelope shape for a consult request, conversation audit trail (`.context/conversations/`), Watchtower surface, spawn-on-event bridge for non-running agents. |

The principle: **TermLink delivers messages; AEF decides what messages mean and where they land in the task/workflow/audit graph.** Same pattern as `fw termlink dispatch` (AEF wrapper over TermLink spawn) and `fw bus post --remote` (AEF audit ledger riding on TermLink remote).

## The one gap that needs a joint decision

**Wakeup of a non-running agent.** Today:

- TermLink **can** deliver to a non-running session — message goes to inbox, waits.
- TermLink **cannot** wake an agent on message arrival — no spawn-on-event primitive.
- AEF **can** spawn agents (`claude-fw`, `fw termlink dispatch`).
- AEF **cannot** efficiently subscribe to TermLink message events without polling.
- Operator's current workaround = cron polling = "costly regular loop" — the failure mode this proposal is trying to retire.

Three options for closing the gap:

### Option (i) — TermLink-side wakeup hook

TermLink gains a configurable per-session or per-channel hook: when a message lands for an addressee and no live consumer exists, fire `$WAKEUP_CMD`. AEF supplies the wakeup command (`claude-fw --remote-wakeup` or similar).

- **Pro:** Generic primitive — other consumers benefit.
- **Con:** TermLink learns spawn semantics it didn't have before — bleeds consumer specifics into a domain-neutral transport.

### Option (ii) — AEF-side daemon

AEF runs a long-lived TermLink subscriber (one process per host) that subscribes to a `peer-consult` topic. On message arrival, spawns the responder via `claude-fw -p`. No TermLink changes needed.

- **Pro:** TermLink stays untouched.
- **Con:** New always-running process per host — framework has avoided daemons; smell.

### Option (iii) — Hybrid: TermLink emits event, AEF subscribes (recommended)

TermLink emits a system event (`message-arrived-no-consumer` or similar) when a message lands for an addressee with no live consumer. AEF runs a small subscriber (could itself be a TermLink-registered session) that listens on the event and spawns the responder. TermLink stays generic — no spawn semantics. AEF owns spawn policy.

- **Pro:** Clean seam. TermLink adds one event class (small, generic, useful for other consumers); AEF adds one subscriber bridge (specific, no surprise).
- **Con:** Slightly more moving parts than (i). Requires both repos to ship in coordination.

**AEF-side recommendation: option (iii).** Asking TermLink: do you concur?

## What we're asking TermLink for

1. **A new event class** (option iii): `queued-but-undeliverable` (or equivalent name) emitted by the hub when a message is enqueued for an addressee with no live consumer. Payload: addressee identifier, message metadata (NOT the message body — body stays in inbox).
2. **A way for an AEF subscriber to subscribe to this event** — existing `termlink event subscribe` / `event poll` should suffice if the new class joins the existing event taxonomy.
3. **Confirmation that the inbox persists the message** until the spawned responder picks it up (consistent with current inbox semantics).
4. **Cross-machine semantics** — does the event propagate across `termlink remote` boundaries, or is wakeup machine-local? AEF would prefer machine-local (the responder spawns on the addressee's host) but defers to TermLink's design.

## What AEF will ship in return

- An `fw consult` semantic layer (CLI + workflow integration)
- A subscriber bridge (small, single-responsibility, could be a TermLink-registered session itself)
- An audit channel under `.context/conversations/<conv-id>.yaml`
- Watchtower surface for in-flight consults
- Workflow-side knobs (`allow_consult: true`, `consult_threshold`) parallel to the existing pause-policy knobs

## Decision points needed from TermLink

1. Do you accept the seam as proposed (transport-only on your side, semantics on AEF's)?
2. Do you prefer (i), (ii), or (iii)?
3. If (iii): is the new event class acceptable scope for the next TermLink minor version, or does this need to wait for a larger comms-substrate release?
4. Cross-machine wakeup — machine-local or relayed?

## Coordination protocol

This proposal is sent from AEF (T-1804) via TermLink dispatch (cross-repo proposal channel). Reply via the same channel referencing PROP-T-1804. Acknowledgment with answers to the four decision points unblocks the AEF-side build tasks.

No code lands on either side until both repos agree on the seam in writing. AEF will record the joint decision in ADR-0004; TermLink may record it in its own ADR or equivalent.
