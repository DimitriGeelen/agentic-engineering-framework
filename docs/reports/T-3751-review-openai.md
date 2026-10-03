VERDICT: ADOPT-WITH-CHANGES — Separate logical recipients from runtime instances, but do not treat matching labels as proof that a replacement can safely continue work.

1. **Q1 — Keep logical identity and runtime identity where meaningful; reject two mandatory labels at every level.**

   The useful distinction is **logical recipient versus current activation**, not universally “function versus instance.” Several proposed function labels identify locations or entities, not functions (§4.1).

   | Level | Recommendation |
   |---|---|
   | Host | Keep FQDN as a locator. Remove IP from identity; it belongs in resolution. If host incarnation matters, use an authenticated node identity and boot generation. An IP can survive reboot or represent several machines. |
   | Hub | Keep a logical hub identifier and a separate process incarnation. Specify whether today’s “hub id” survives restart before assigning it either meaning. |
   | Project | Keep committed `pid-…`. Add a durable **workspace/deployment id** distinguishing clones, plus a runtime generation if a project service runs. A checkout is still passive; its supervisor is callable. |
   | Session | Keep the session instance id. Make its name optional metadata, not a mandatory function. Human conversation names do not establish interchangeable sessions. |
   | Agent | Keep a project-scoped logical recipient name and a fresh activation id. Separate that recipient name from its role: two independently addressed agents can both perform `research`. |

   A workspace id must survive process restart but must not be copied unchanged into another checkout. Otherwise the proposed project-instance field merely moves the ambiguity (§2, §7.3).

   Vendor/model belongs in deployment metadata and compatibility policy, not identity. Missing essentials are an owner/security scope, an approved role specification, and a recovery contract. “Same role” alone does not imply equivalent tools, permissions, task state, or capabilities.

2. **Q2 — Put canonical identity and explicit delivery constraints on the wire; keep transport locations and friendly names separate.**

   Use a versioned envelope containing:

   - Logical destination: authority scope, `pid`, logical agent name.
   - Workspace scope: explicit workspace id, or an explicitly configured project service that owns workspace selection.
   - Optional exact endpoint: session id and agent activation id.
   - Delivery policy: `exact-instance` or `allow-replacement`, with session affinity expressed separately.
   - Message identity, authenticated sender, reply destination, deadline, and `in_reply_to` when applicable.

   The resolved transport endpoint contains host locator, hub identity/incarnation, receiver address, and runtime bindings. The sender need not embed every ancestor in an immutable identity string.

   Role, capability requirements, recovery references, and vendor/model restrictions are metadata that can constrain matching. Folder basename, readable project name, session title, and IP presentation are display concerns (§2, §4.1).

   Crucially, an explicit workspace constraint must never disappear during fallback. Two clones sharing `pid` are not interchangeable merely because they contain the same repository.

   For IW-2, map legacy topics to canonical destinations only where unambiguous. Preserve original message ids, consume both namespaces through shared deduplication, and retain migration checkpoints until old backlog is accounted for. Reject ambiguous basename mappings. Older clients must receive their actual supported receipt semantics; translation cannot invent delivery evidence (§5–§6).

3. **Q3 — Resolve under an explicit replacement policy; climb to supervisors for recovery, never to broader recipients.**

   Proposed algorithm (§2 D1/D4/D5, §4.2):

   1. **Validate.** Check protocol version, authenticated sender, destination, authorization, size, deadline, and replacement policy. Reject with a specific reason before provisioning.
   2. **Deduplicate and persist.** Store the envelope under `(sender identity, client_msg_id)` before acknowledging durable acceptance. Repeated submissions return existing state. Report `ACCEPTED` with the actual custodian and destination.
   3. **Resolve the exact endpoint.** If it exists and matches the binding, attempt receiver delivery. Receiver persistence yields `RECEIVED`, naming the activation; transport success alone does not.
   4. **Classify failure.** A timeout or missing registry entry is `UNREACHABLE/UNKNOWN`, not proof of death. Queue within the deadline and probe the authoritative supervisor. Do not spawn an unfenced duplicate.
   5. **Apply the replacement constraint.** For `exact-instance`, proven death ends in `BOUNCED: INSTANCE_GONE`. Otherwise request recovery from the nearest authorized supervisor: agent owner, session owner, workspace owner, then hub/host supervisor where configured. These ancestors retain the original destination; they do not become recipients.
   6. **Select an eligible successor.** Prefer a compatible activation in the requested session, then an authorized session in the same workspace. Cross-workspace or cross-host recovery requires an explicit relocation policy and accessible recovery state. Never cross `pid` or authority scope.
   7. **Provision if necessary.** Acquire the recovery claim and budget reservation; verify recovery prerequisites; start one successor. Report `PROVISIONING`, then `REBOUND` with old/new circuit ids, reason, and recovery checkpoint. Neither means delivered.
   8. **Deliver and observe.** Persist at the successor receiver; inject only into the selected session under its readiness rules. Emit `HANDED_OVER` only from evidence binding this message to this activation’s transcript. Emit `REPLIED` only for an authenticated reply referencing the original message id.
   9. **Stop deterministically.** Stop on refusal, ambiguity, absent recovery state, exhausted budget/restart allowance, unsupported semantics, or deadline. If delivery definitely never occurred, bounce. If an acknowledgment may have been lost, report `OUTCOME_UNKNOWN` and retain reconciliation state; do not claim non-delivery.

   Record bounded retries and recovery attempts under the original message id so supervisor escalation cannot restart the budget. A lost reply must not trigger blind re-execution.

4. **Q4 — An inbound message may trigger only a previously authorized, bounded recovery policy.**

   D5 supports executing an established recovery policy; it does not adequately define one (§2, §5, §7.2).

   The receiving project’s human owner approves a role deployment specification: launch recipe, permitted senders, tools, model choices, workspace scope, recovery sources, spending account, and limits. The receiver’s configured account pays unless a separate billing agreement exists. A sender cannot select credentials, arbitrary launch commands, or a more expensive model.

   Require:

   - Per-sender admission limits and per-project aggregate spending, concurrency, and restart limits.
   - Atomic budget reservation and one outstanding recovery operation per logical recipient.
   - Expiring messages, bounded queues, restart backoff, and a circuit breaker for repeated failures.
   - A verified checkpoint containing task, repository revision, relevant local changes, pending effects, and recovery status.
   - A functioning receiver and wake consumer before advertising the successor as ready.

   A conversation thread alone is insufficient recovery state. A successor can understand the discussion while lacking an uncommitted patch or knowledge that an external action already succeeded.

   Treat message contents as untrusted work input. They cannot redefine recovery policy, expand permissions, or supply executable recovery instructions. Existing destructive-action approvals do not automatically transfer to a replacement. Outside the approved policy, retain the message and request human action with an explicit status.

5. **Q5 — Guarantee one authorized owner where required; do not promise exactly-once execution.**

   Distinguish two cases (§2 D7, §7.3):

   - Two different logical agents with role `research` are legitimate. A role-only request requires an explicit pool policy or returns ambiguity.
   - Two activations claiming one logical recipient require an authoritative ownership claim and monotonically increasing fencing token.

   Lease expiry alone is insufficient: a partitioned old agent can keep working after its replacement starts. Protected writes must reject stale fencing tokens. Where an external system cannot enforce fencing, use idempotency keys or require reconciliation before repeating uncertain effects.

   Per-project local locking does not protect replicas on different hosts. Without a reachable ownership authority or equivalent coordination, stop recovery rather than appoint two owners.

   Share a durable message ledger across HTTP delivery, hub fallback, migration aliases, and successor activations. Duplicate delivery should return existing progress or the stored reply. Retain deduplication records through the permitted retry lifetime.

   A crash after an external action but before recording success remains ambiguous. Exactly-once side effects require cooperation from that external system; address syntax cannot provide it.

6. **Q6 — Better identity prevents some misrouting; it does not repair the observed delivery pipeline.**

   Per-session/per-activation binding helps prevent the ready-flag and wrong-session attribution failures (§3.4–§3.5), provided transport authentication and receipt validation actually enforce those bindings.

   The remaining incidents require operational changes:

   - Receiver absence and orphans require supervision, expiring registrations, and end-to-end health probes (§3.1, §3.8).
   - Hub pickup requires the same receipt ledger and reply correlation as HTTP delivery (§3.1–§3.2).
   - A receipting sidecar without a wake consumer remains ineffective (§3.3).
   - Unread topics, transport acceptance, and excessive latency need monitored consumption and timing evidence (§3.6–§3.9).

   The new failure class is **“replacement started” reported as “recipient recovered.”** A new `research` process can have the right name and wrong branch, missing credentials, or stale context.

   Report recovery readiness separately from process liveness. Measure acceptance-to-handoff and handoff-to-reply separately. The one-tick expectation applies to an idle, ready agent; it is not a reply-time guarantee (§1.3).

7. **Q7 — Copy supervised lifecycle and logical addressing; do not copy their names without their runtime guarantees.**

   **Erlang/OTP:** Copy explicit child specifications, restart policies, and restart-intensity limits. A supervisor knows what it owns and how to start it; arbitrary incoming names are not deployment specifications. [OTP supervisor documentation](https://www.erlang.org/docs/25/man/supervisor.html).

   **Orleans:** Copy the distinction between stable grain identity and runtime activation. Its type-plus-key identity also illustrates why “role” and “which logical recipient” are separate. Its delivery documentation explicitly distinguishes retry behavior from exactly-once guarantees. The lesson is to implement activation management and message semantics, not merely borrow virtual-actor terminology. [Grain identity](https://learn.microsoft.com/en-us/dotnet/orleans/grains/grain-identity), [Messaging delivery guarantees](https://learn.microsoft.com/en-us/dotnet/orleans/implementation/messaging-delivery-guarantees).

   **SIP/DNS service discovery:** Copy separation of logical destination from transport resolution and ordered alternate-server selection. Avoid treating an alternate server as proof that application context or authority transferred. Server discovery solves reachability; AEF still needs its own recovery contract. [RFC 3263](https://www.rfc-editor.org/info/rfc3263/).

   These are architectural analogies, not evidence that an LLM session can be reconstructed safely from its name.

8. **Q8 — Adopt with changes, because identity equivalence is weaker than recovery equivalence.**

   Require five changes before implementation:

   - Replace universal function/instance pairs with logical identity, workspace identity, and runtime incarnation where applicable.
   - Make exact-instance versus replaceable delivery explicit.
   - Define an owner-approved recovery contract, budget, and bounded stop rule.
   - Implement fenced ownership, shared deduplication, and message-bound receipts across every transport.
   - Agree versioned semantics and migration behavior with TermLink before either side keys wake-up on the new address (§5–§6).

   Prioritize receiver supervision, fallback receipts, and reply correlation immediately. Those fix demonstrated failures independently of the larger identity redesign.

TOP 3 RISKS:

1. **Split-brain recovery:** A network partition hides the original agent. A replacement starts; both modify the same branch or repeat an external action. Local single-writer claims do not protect the remote replica.
2. **Wrong-workspace continuation:** Two checkouts share `pid` and agent name. A message concerning an uncommitted security fix reaches a clean checkout, which replies confidently from different state.
3. **Message-driven spending:** An authorized but malfunctioning peer sends fresh message ids continuously. Each message triggers a new paid activation after a failed recovery, exhausting funds without an aggregate budget and restart breaker.

WHERE I DISAGREE WITH THE AGENT'S READING (§4.3, §7):

- §4.2 is not merely D1+D5 applied: making sessions optional changes an instance-targeted request unless replacement is explicitly permitted.
- The project need not “stop being passive.” A workspace and its supervising service should remain distinct.
- “Never across projects” is necessary but insufficient: same-project clones can differ in state, permissions, and purpose.
- Function labels do not define working equivalence; an approved role specification and recovery contract do.
- The exactly-once concern is broader than competing recipients: crashes between effects and acknowledgments remain ambiguous with one recipient.
- Naming the accepting level is insufficient. Receipts must identify the message, actual activation, evidence, and uncertainty.