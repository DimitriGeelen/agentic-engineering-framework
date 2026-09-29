# T-3558 external review ROUND 2 — openai

Reviewer: OpenAI (codex CLI, ChatGPT login, default model, read-only sandbox). Run 2026-09-29 in a neutral scratch directory with only `T-3558-external-review-brief-round2.md` as input. Reproduced verbatim below.

---

D-645 addresses the measured failure much more directly than the addressing proposal. But its central promise—getting a message into an agent’s working context—still depends on an unspecified runtime integration. That is a prerequisite to validate, not an implementation detail to defer.

**1. Is D-645 the right consumption design?**

Yes in direction; not yet as a complete build specification.

It correctly separates durable receipt from prompt delivery, keeps messages while an agent is busy, and distinguishes transport failure from failure to reach the agent. Attachment verification before eligibility for injection is also sound. Round 1’s gates and canaries did not specify this receiving infrastructure or its recovery behavior.

However, HTTP push to a sidecar does not itself solve consumption. The decisive component is the adapter between the sidecar and the agent runtime. The brief does not establish that it can:

- Insert content at a safe execution boundary.
- Start or resume an agent turn when the agent is idle.
- Confirm that a particular message entered a particular model invocation.
- Recover correctly when either process crashes during that handoff.

A prompt queue can become another unread inbox. A successful queue write must not count as `HANDED_OVER`.

The storage contract also needs precision: persist the message, attachment references, and pending-delivery record in one recoverable transaction. A dirty-bit should be a rebuildable optimization, never the sole evidence that work remains.

**2. Push versus gate**

They are complementary. Push provides timeliness during long tasks and idle periods; a gate provides reconciliation at lifecycle boundaries and catches broken push integration.

The gate should check **unresolved obligations**, not require an empty inbox. Specifically:

- Messages eligible for delivery but not yet presented.
- Presented requests without a recorded disposition.
- Accepted requests whose next action or response deadline has expired.
- Sidecar or runtime-adapter failures that undermine the delivery guarantees.

It should require triage into an authorized task, decline, deferral with a deadline, or escalation. It must not require completing every peer request before unrelated work continues.

An “inbox must be empty” gate creates a denial-of-service mechanism and can deadlock agents waiting on each other. Use a bounded queue snapshot, permit recorded human overrides, and allow task outcomes to be recorded even when communications are degraded.

**3. Security of injection**

“Data, never instructions” cannot be guaranteed by framing alone. An authenticated peer can still send malicious instructions, and a model can still misinterpret quoted content. The enforceable boundary must sit outside the model.

Inject messages as structured, explicitly untrusted peer content in a dedicated low-trust context surface. Never interpolate them into system or developer instructions. Display verified provenance separately from the peer-controlled body. A claim such as “the operator approved this” remains an untrusted claim.

The runtime must enforce that a peer request can create a **proposal**, not confer authority. Actions must reference a valid AEF task and satisfy the applicable human-approval policy through independently verified records. A model-generated assertion that approval exists must not suffice.

API access should be restricted to enrolled sidecars acting for authorized project identities. Require:

- Authenticated transport and authorization for the specific recipient and operation.
- A verified envelope binding sender, recipient, message ID, content and attachment hashes, expiry, and protocol version.
- Replay protection, credential rotation and revocation.
- Size, rate, queue, attachment, and context-budget limits.
- Separate privileges for sending messages, issuing receipts, and administering the receiver.

Receipts must be attributable to the receiver; a sender cannot assert its own successful handoff. Fallback transport must preserve the same verification requirements.

Project credentials stored under one shared OS user are attribution mechanisms, not isolation against a hostile process running as that user. If that threat is in scope, separate service identities or another enforceable isolation boundary are required.

**4. Lifecycle states**

The proposal mixes transport progress, agent decisions, and monitoring outcomes into one linear chain. Model them separately, with an append-only event history and derived status.

| Layer | Recommended events or states |
|---|---|
| Sender delivery | `QUEUED`, delivery attempts, `RECEIVED` |
| Runtime presentation | `PRESENTED`, tied to a message ID and model invocation |
| Request disposition | `ACCEPTED`, `DEFERRED`, `DECLINED` |
| Response | `RESPONSE_QUEUED`, linked response receipt and presentation |
| Monitoring | Deadline breaches and `ESCALATED` events |

`SENT` is only evidence of an attempted transmission. `HANDED_OVER` is defensible if narrowly defined, but `PRESENTED` makes its limited meaning clearer. Neither proves attention or understanding.

`ACCEPTED` should reference an authorized task and a response deadline. Acceptance of a request does not establish permission to execute every requested action.

`REPLIED` is ambiguous: composed, queued, delivered, or presented to the requester? Record those facts through the linked response message’s lifecycle. A response is also not necessarily completion; it might be a clarification question.

`ESCALATED` should normally be an event, not a terminal state. An overdue request may subsequently succeed. Record cancellation and expiry explicitly where applicable, and distinguish infrastructure failures from agent refusals.

Required protocol rules include:

- A stable message ID across retries; reject reuse with different content.
- Sender ownership of delivery retries until durable receipt.
- Receiver ownership of presentation retries after receipt.
- Durable receipt replay when acknowledgements are lost.
- Separate receipt, presentation, disposition, and response deadlines.
- Task-level deduplication so duplicate presentation cannot duplicate consequential actions.

Exactly-once presentation across a crash boundary may be unavailable. Specify at-least-once recovery and idempotent action handling instead of implying a guarantee the runtime cannot provide.

**5. Open design questions**

**Cadence:** Use event-driven wakeup on receipt and runtime readiness transitions, with a periodic reconciliation sweep. Fifteen seconds is a reasonable initial sweep interval, not a validated responsiveness target. Measure receipt-to-presentation latency and oldest pending-message age. A retry cron is a separate concern.

**Readiness:** Obtain it from the runtime adapter, not terminal-output heuristics or a sidecar guess. Delivery should require a live session, a supported context boundary, available context capacity, and exclusive acquisition of the handoff opportunity. Checking readiness and then injecting later creates a race.

Idle or absent agents need an explicit policy: authorized activation, or durable waiting with escalation. “Not ready” preserves messages but does not guarantee progress.

**Hub beneath the API:** Use direct HTTP for the first proof and retain TermLink for discovery as needed. Defer automatic fallback until the consumption loop works. If the hub becomes a carrier, its acceptance is only a transport event; `RECEIVED` still requires the destination sidecar’s durable receipt. All carriers must share message identity, deduplication, and authentication semantics.

Before broader deployment, add bounded scheduling and fairness. Deferring all prioritization leaves a message flood able to starve ordinary work or urgent control messages.

**6. Why designs do not get built**

The audit’s definition of progress is wrong. A textual reference is neither an implementation dependency nor evidence of completion.

Ratification should atomically create an implementation obligation containing an accountable owner, the next executable slice, a due date, dependencies, and explicit acceptance criteria. It need not authorize building automatically; if authorization remains necessary, that pending decision must be visible.

Use an explicit progression such as:

`RATIFIED → SCHEDULED → IN_PROGRESS → VERIFIED`

Permit `BLOCKED`, `DEFERRED`, and `SUPERSEDED` only with a reason and accountable disposition. Any shipped slice leaves the remaining obligation open. Task relationships must distinguish “implements” from “mentions,” and `VERIFIED` must require evidence against acceptance criteria.

Re-run the corrected audit against existing ratified decisions; fixing future behavior leaves the current hidden backlog intact.

The refusal ledger can record explicit declines. It cannot detect work that was never created. An agent reviewer can inspect evidence, but the obligation inventory and overdue detection should be deterministic and externally visible. Their alarms must not depend solely on the same message-consumption path they monitor.

**7. Minimum viable first build**

Build one authenticated, durable path between two real agent runtimes, including the receiver-to-runtime adapter. A receiver daemon alone is a horizontal component, not proof of consumption.

Within an explicitly approved test task:

1. Agent A sends a request with a fresh unpredictable nonce and a small attachment.
2. B’s sidecar verifies and durably stores it, then returns `RECEIVED`.
3. The runtime adapter safely presents it to B and records the model invocation.
4. B records acceptance against the test task, performs a harmless nonce-dependent action, and replies through its sidecar.
5. A receives the reply in its own context and acknowledges the result.

Use an independent observer that checks durable records, runtime invocation evidence, the action result, and A’s response. The harness must not manufacture B’s acceptance or reply. Prevent an alternate route by keeping the nonce out of B’s initial prompt and any shared file it could independently read. Hub success and log strings must never satisfy the acceptance test.

Required fault tests should demonstrate that:

- Disabling the runtime adapter prevents a successful result and triggers escalation.
- Busy execution delays presentation until a safe boundary.
- Lost acknowledgements and process restarts preserve messages without duplicate actions.
- A crash around presentation recovers according to the declared duplicate-delivery contract.
- Unauthorized senders and corrupt attachments cannot reach the prompt.
- A peer’s forged approval claim cannot authorize an action.

The decisive negative control is disabling injection: **if that test still passes, the test measures the wrong thing.**

```text
VERDICT: amber
GUIDANCE: Specify and validate the runtime handoff contract, enforce authorization outside the model, separate delivery from request outcomes, and replace mention-based audits with evidence-backed implementation obligations.
FIRST SLICE: Build one durable sidecar-to-runtime-to-reply loop between two real agents. Prove it with an unpredictable nonce, an independently observed action, sender-visible receipts, crash recovery, and a disabled-injection negative control that must fail.
TOP RISK: Counting a successful enqueue as agent consumption, recreating the current silent failure behind more convincing receipts.
```