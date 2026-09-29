# T-3558 external review — openai

Reviewer: OpenAI (codex CLI, ChatGPT login, default model, read-only sandbox). Run 2026-09-29 in a neutral scratch directory with only `T-3558-external-review-brief.md` as input. Reproduced verbatim below.

---

1. **The routing/trust split is right, but the two must meet at message acceptance.**

An address identifies a destination; a credential proves authority to make a claim. Keeping these concepts separate supports key rotation, session replacement and routing without redefining identity.

The proposal needs one enforceable contract connecting them: a recipient accepts a claimed sender only when a verified credential authorizes that circuit, and processes the message only when its destination and requested action are permitted. Multiple named keys alone do not provide this contract.

Keep `from_circuit` as an untrusted claim until verification succeeds. Expose the claimed circuit, verified principal and authorization result separately. A valid signature establishes neither permission to issue commands nor human approval for Tier 0 actions.

2. **Use a project key as the default authority, with explicit delegation to sessions and agents where needed.**

The rungs serve different purposes:

- **Host:** infrastructure identity and transport authentication.
- **Hub:** namespace administration and discovery authority.
- **Project:** stable ownership and accountability across agent restarts; the appropriate default signing authority.
- **Session or agent:** short-lived delegated identity when recipients need to distinguish or authorize individual actors.

A project signature can authenticate “this project asserts that agent X sent this.” It cannot independently prove that agent X, rather than another holder of the project key, originated the message. Where that distinction matters, issue scoped, expiring session or agent credentials.

TermLink should provide credential handling, signing and verification primitives. AEF should define circuit ownership, delegation and action authorization. The binding between keys and circuits needs an explicit trust source; discovering a key through a claimed circuit must not automatically establish ownership.

`whoami` should report identity from an explicitly provisioned execution context, such as a launcher-provided credential reference and session registration. Guessing from the working directory or choosing among 173 sessions is unsuitable for authentication. Ambiguity must produce a visible error, while project-level mailbox monitoring continues independently.

Crucially, **different key files under the same unrestricted OS user are not a security boundary**. If projects can read each other’s keys or control each other’s processes, separate identities improve attribution for cooperative software but do not stop malicious impersonation. Strong isolation requires an enforcement boundary such as separate OS principals or a credential broker with effective caller isolation.

3. **Demote `dm:` from AEF’s canonical addressing now; do not make its redesign a prerequisite.**

`inbox:<circuit-id>` already supplies the required transport semantics and matches the ratified model. Re-keying DMs would add migration work without resolving circuit discovery, fallback, consumption or authorization.

However, “different machine keys” is insufficient to make DMs suitable for project communication. Several projects on each of two hosts can still share one host-pair DM topic. Retain DMs for communication explicitly addressed to those transport principals, without presenting them as project-private.

If TermLink later supports named identities, project-addressed DMs may become useful. They should share the same identity verification and mail-processing implementation as inboxes, rather than create a competing AEF address scheme.

4. **The proposal improves attribution and routing separation; it does not yet establish privacy or complete sender authentication.**

The concrete threats and remaining gaps are:

| Threat | Effect of the proposal |
|---|---|
| Accidental cross-project message mixing | Distinct circuit inboxes reduce it, provided circuit names are unique and consistently resolved. |
| Unauthorized cross-project reading | Unresolved. Separate topic names are not read access controls. Enforce mailbox ACLs or use encryption appropriate to the threat model. |
| Forged `from_circuit` | Closed only if verification is mandatory at the trust boundary and the signer-to-circuit binding is authoritative. Optional hub verification alone is insufficient. |
| Signing with another project’s stolen key | Unresolved when co-resident projects can access each other’s credentials. |
| Replay or duplicate execution | Unresolved. Signatures authenticate replayed messages too. |
| Forwarding a signed message to a different recipient | Unresolved unless the signature covers the intended destination and recipients enforce it. |
| Malicious requests from an authenticated peer | Unresolved by identity. AEF must enforce action permissions, task requirements and human approvals. |

Define a signed envelope covering at least protocol version, message ID, sender claim, intended destination, payload, correlation information and applicable validity constraints. Recipients need durable duplicate detection and idempotent action handling; timestamps alone do not prevent replay.

The brief demonstrates a shared DM namespace, not the full read-access policy. A privacy breach depends on who can read it. That uncertainty should be resolved explicitly before claiming confidentiality.

Fallback introduces another threat: sending an agent-private payload to a broader project or host mailbox. Treat fallback as discovery or explicitly authorized delivery, not automatic widening of readership.

5. **Nothing in the proposal, as written, fixes consumption.**

Mail semantics already existed during the failures. The missing component is an accountable consumer with recovery and escalation.

The smallest workable mechanism is a supervised mailbox consumer for each project:

1. It subscribes to the project’s exact mailbox set, including registered session and agent inboxes. It reconciles durable unread state at startup and periodically, so missed wake events cannot hide messages.
2. It durably records an incoming message and schedules or resumes the appropriate agent. If the target session is gone, a project dispatcher owns recovery.
3. It distinguishes **delivered**, **accepted for handling**, and **completed or declined**. A transport receipt must never be presented as evidence that an agent has read or acted on a request.
4. Requests carry a response deadline or use an agreed default. An unanswered request triggers bounded retries and then escalation to a named owner, ultimately the human when appropriate.

Persist processing state before acknowledging acceptance. Recover unfinished work after crashes and prevent duplicate side effects. Wake-up should schedule governed processing; message arrival must not itself authorize command execution.

Measure time to acceptance and response, oldest unhandled request, and consumer health. Demonstrate a complete round trip with an idle recipient, then repeat with a missed wake event and a consumer restart. That is a better success criterion than successful posting.

6. **Several operational contracts are missing.**

- **Canonical addressing:** Define component syntax, escaping, namespace authority and uniqueness. The example uses two components described as hub/project, while the model begins with host/hub. Specify how omitted levels are represented and resolved; the current description permits incompatible interpretations.
- **Discovery and lifecycle:** Define how senders find current circuits, how registrations expire, and what happens after session termination or identifier reuse.
- **Fallback ownership:** Every broader inbox needs a responsible dispatcher. Specify whether fallback is triggered by a missing address, a rejected delivery or a response timeout. A slow recipient must not cause duplicate work at several levels.
- **Trust bootstrap and key lifecycle:** Define initial circuit ownership, human-approved trust establishment, rotation, revocation and delegation expiry. Hub verification must either produce a result the recipient can trust or be supplemented by recipient verification.
- **Compatibility and rollout:** Publish one versioned protocol specification, amend D-660, inventory peer subscriptions and verify each peer’s cutover with an acknowledged exchange. Preserve handling of unread legacy messages during migration.
- **Failure visibility and resource limits:** Unknown identity, invalid signatures, absent consumers and expired requests need explicit statuses. Bound queues, retries and wake rates so a peer cannot exhaust resources or create notification loops.

The immediate priority should be a working consumption loop over circuit inboxes, alongside a precise statement of the security boundary. TermLink’s multi-identity work can then implement an agreed trust contract.

VERDICT: amber
GUIDANCE: Standardize circuit inbox addressing and safe fallback; deploy a supervised consumer with durable recovery, handling acknowledgements and deadline escalation; require authoritative signer-to-circuit verification before trusting sender claims; define mailbox access controls, credential isolation, replay protection and key lifecycle; validate migration through acknowledged peer round trips.
TOP RISK: The proposal leaves consumption without an accountable owner, so correctly addressed and authenticated messages can still sit unread for days.