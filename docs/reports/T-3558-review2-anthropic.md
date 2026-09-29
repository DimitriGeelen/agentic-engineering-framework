# T-3558 external review ROUND 2 — anthropic

Reviewer: Anthropic Claude Sonnet 5 (claude -p, tools disabled; same vendor as the builder). Run 2026-09-29 in a neutral scratch directory with only `T-3558-external-review-brief-round2.md` as input. Reproduced verbatim below.

---

# Round 2 Review — Consumption Design (D-645)

## 1. Is D-645 the right consumption design?

Yes, in shape. It is the first proposal in either round that treats "delivered to the hub" and "reached the agent" as genuinely different events with genuinely different failure modes, and it encodes that distinction structurally (CONFIRM-1 vs CONFIRM-2) rather than leaving it to a status field someone might forget to check. Round 1's own proposals — a gate, an ack/escalate rule, delivered/accepted/completed states, a canary — were all *reactive*: they assume the agent eventually looks and try to force or verify the look. D-645 is the first design that tries to *cause* the look, by pushing content into the prompt. Store-before-decide-to-inject is the right ordering (a busy agent can't lose a message to a bad timing decision), and hash-verifying blobs before setting the flag closes an obvious race that none of round 1's proposals even had a component to worry about, since round 1 never discussed attachments.

What it still misses, even on its own terms:

- **No self-verifying heartbeat.** Round 1's canary — a synthetic message with a deadline — was a way to prove the *pipeline itself* is alive, independent of any real traffic. D-645 has ticks and confirmations for real messages, but nothing that periodically proves the receiver process, the tick, and the injection path are all still functioning when no one happens to be sending. That's precisely the gap that let slice 1 sit unbuilt for four days without anything complaining — a design flaw and the governance flaw in section 6 are the same shape.
- **No idempotency or dedup story** (see Q4).
- **Readiness is left undefined**, which is not a minor gap — it's the hinge the whole safety argument turns on (see Q4, Q5).
- It inherits round 1's unresolved identity/verification problems and makes them *higher-stakes*, because now a remote party's bytes land inside an agent's live context automatically, not just in a topic the agent chooses to open (see Q3).

## 2. Push versus gate

Complementary, not redundant — but only if the gate is scoped to check something push can't guarantee about itself. If the gate just re-reads the inbox, it duplicates push and adds no coverage. What it should check instead: **whether every message addressed to this agent has reached at least `ACCEPTED` (or a terminal state) within its SLA**, using the lifecycle state store, not the mailbox contents. That reframes the gate from "did you read your mail" to "did the push pipeline actually work for everything addressed to you" — which is exactly the check that would have caught a dead tick, a crashed sidecar, or a message stuck at `HANDED_OVER` because the agent never got around to it. Push buys timeliness; the gate is the only thing in this design that survives push failing silently, so it should be defined as push's audit, not push's backup delivery mechanism.

## 3. Security of injection

This is the sharpest new risk in round 2, and the brief is right to isolate it. A sidecar API that writes into an agent's prompt on a timer, with no human in the loop at the moment of injection, is by construction a remote-write channel into a live agent context. Requirements:

- **Framing**: injected content must arrive inside an explicit, non-spoofable envelope — the same trust tier as an external tool result, not as a system or user instruction — carrying sender circuit id, verification status, message id, and timestamp as structured metadata outside the free-text body. The agent's standing instructions must state, unconditionally, that content in this envelope is *data to evaluate*, and that any request for action found inside it must be turned into a normal AEF task proposal — subject to the same "propose, never decide" and human-approval path as if a human had typed it — rather than executed directly from the injection. The sidecar must have no capability to invoke tools on the agent's behalf; it can only place text in context.
- **Authentication**: only a sidecar holding a valid credential for a known, previously-verified circuit id may call another sidecar's receive endpoint; the sender field in the message must be bound to the authenticated caller so it can't be self-asserted. Given round 1's finding that separate key files under one OS user are not a security boundary, same-host calls need the same token/mTLS check as cross-host ones — no localhost exemption.
- **Bounding**: per-sender rate and size limits, and a first-contact case — an unverified or newly-seen sender's message should land at `RECEIVED` and stop there, not auto-progress to `HANDED_OVER`, until a trust decision is made (this is round 1's TOFU/replay gap resurfacing directly at the injection boundary, not a separate problem).
- **Who may call it**: sidecars only, one per agent, address-bound to a circuit id — never an arbitrary local process, and never a generic "inject into session X" primitive that something other than the paired sender sidecar could reach.

## 4. The lifecycle states

`SENT → RECEIVED → HANDED_OVER → ACCEPTED → REPLIED | DECLINED | ESCALATED` is close to right and the `HANDED_OVER`-over-"consumed" naming call is correct — "consumed" implies completion, and the whole point of round 1's findings is that "looks handled" and "is handled" must never share a name again. Gaps:

- **Deadlines exist only implicitly.** The design discusses timers for `RECEIVED`→`HANDED_OVER`, but the more dangerous stall is `HANDED_OVER`→`ACCEPTED`: the message is in the agent's context and it still doesn't act (interrupted mid-task, context evicted, etc.). That is functionally identical to the measured failures (7 unread for 24h) one layer downstream, and needs its own SLA and escalation, not just the delivery-side one.
- **No idempotency.** Message IDs must be unique, and retries (triggered by a missing CONFIRM-1) must be safely replayable — otherwise a lost ack on an otherwise-successful delivery produces a duplicate store and a duplicate injection. This needs a dedup key at the receiver, stated explicitly, not assumed.
- **Retry ownership is unstated.** "Retry" on `RECEIVED` failure — who retries, how many times, what backoff, and who decides to stop and move to `ESCALATED`? The design correctly says retrying delivery won't fix a `HANDED_OVER` stall, but doesn't say who *does* act on that escalation — it needs to land somewhere with teeth (the refusal ledger, per Q6), not just change a status field.
- **Missing a `REJECTED`/quarantine state**, distinct from `DECLINED`, for messages that fail auth or verification and must never reach `HANDED_OVER` at all — this is the state-machine expression of the Q3 security requirement.

## 5. The open design questions

- **Tick cadence**: the number (15–30s) matters less than making the tick itself observable — treat it as a heartbeat with its own missed-tick alert, so a dead tick is loud, not silent (this is the direct fix for how slice 1 disappeared for four days). Start conservative (30–60s) and tune from measured injection latency rather than guessing.
- **Readiness predicate**: define it narrowly and safely for v1 — "agent idle at a task boundary, not mid-tool-call" — determined by the harness itself, which already knows tool-call state, rather than inferred externally. This mirrors round 1's gate concept (no task opens/closes with unread mail) applied as an injection precondition instead of a session-start check. Do not attempt true mid-generation interrupts in v1; that's where "failing toward ready" gets genuinely dangerous.
- **Hub under the API**: keep TermLink as the fallback carrier and discovery layer, as the brief leans. Building a second discovery/identity system in parallel would throw away round 1's addressing work. Decide: direct HTTP call is the primary path; on failure (partition, receiver sidecar down), fall back to a hub topic post, which reintroduces store-and-forward exactly where push cannot reach — don't make this an either/or.

## 6. Why designs don't get built

The audit's actual bug is a category error: it treats *mentioned in a later task* as equivalent to *built*. That's a text-co-occurrence check standing in for a completion check. The fix is structural, not procedural:

- Every ratified decision must decompose into slices with a machine-checkable "definition of built" — a running process, a passing test, a deployed endpoint — not a task reference. "Slice 1 built" should mean "receiver process exists and answers a health probe," never "a task mentions slice 1."
- The audit should distinguish *referenced* from *delivered*, and treat "ratified, zero build tasks exist" as a distinct, louder failure than "build task exists but stalled" — right now both look the same to it, and the worse case (no task at all) is the one that actually happened.
- Extend the refusal ledger's principle — no silent failure, everything terminal gets recorded — to ratified decisions themselves: a decision with no build task opened within N days of ratification should generate a ledger entry automatically, the same way an unanswered message should escalate. This is literally the same fix pattern proposed for message consumption (mandatory acknowledgment, escalate on silence, never let "referenced somewhere" substitute for "confirmed") applied one level up, to the framework's own decision pipeline. The agent reviewer in progress is a natural place to run this check periodically.

## 7. Minimum viable first build

Two real sessions, sidecar A and sidecar B, running the actual receiver process (slice 1 only) — no blobs, no fallback hub path, no prioritization, readiness = "idle since last tool call," tick = fixed 30s, direct HTTP only. Agent A sends a message containing a nonce generated *at test time* that requires B to perform an externally-observable action it has no other way to produce — e.g., write a sentinel file containing the nonce, or compute and reply with a derived value.

Pass criteria:
- All states from `SENT` through `REPLIED` are logged in order with timestamps on the sender side.
- B's sentinel artifact / reply, containing the nonce, actually appears.

To keep the test from passing falsely — which is the exact failure mode this whole review exists to catch:
- **B's session/task prompt must not mention that a message is coming.** If B is pre-seeded to "check for a message," a manual pull could masquerade as push working.
- **The nonce must be generated after the test starts**, so it cannot have been baked into B's context ahead of time.
- **Include a negative control**: kill the receiver process or the tick after `RECEIVED` and confirm the system reports a stuck/`ESCALATED` state rather than silently timing out with no signal, or — worse — reporting success. A test that can only report "it worked" and has no way to report "it's stuck" is not a test of this design; it's a test of the happy path only, and the happy path was never what failed.

---

```
VERDICT: amber
GUIDANCE:
  1. Define the readiness predicate explicitly before building the tick loop
     (v1: idle at a task boundary, determined by the harness — no mid-generation
     interrupts).
  2. Specify authentication and framing for the injection API before it can
     receive real traffic: mutual auth binding sender circuit id to the caller,
     envelope separating metadata from body, standing instruction that injected
     content is data and any action request routes through normal task/approval,
     first-contact senders held at RECEIVED not auto-advanced to HANDED_OVER.
  3. Add message-id based idempotency/dedup at the receiver before enabling
     sender-side retries.
  4. Add an SLA and escalation on HANDED_OVER -> ACCEPTED, not just on the
     delivery-side transitions.
  5. Add a REJECTED/quarantine terminal state for auth/verification failures,
     distinct from DECLINED.
  6. Wire ratified-decision tracking into the refusal ledger (or a parallel
     ledger) so "ratified, no build task opened within N days" is a loud,
     automatic failure, closing the exact gap that let slice 1 sit unbuilt for
     four days undetected.
  7. Build the gate as an audit of the lifecycle state store (anything not at
     least ACCEPTED past its SLA), not a duplicate inbox read, so it survives
     push failing silently.
FIRST SLICE: The receiver process (slice 1) alone, end to end between two real
  sessions, on the test described in Q7 — nonce generated at test time, no
  pre-seeded awareness in the receiving session, plus a negative control that
  kills the tick/process after RECEIVED and requires the system to surface a
  stuck state rather than silently succeeding or timing out unreported.
TOP RISK: The design gets ratified a second time and still doesn't get built,
  because the structural cause (an audit that treats "mentioned" as "built")
  hasn't been fixed yet. Everything else in this brief is a refinement; this
  one is why the last complete, ratified design produced zero working code.
```
