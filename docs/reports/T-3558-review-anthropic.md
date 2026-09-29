# T-3558 external review — anthropic

Reviewer: Anthropic Claude Sonnet 5 (claude -p, tools disabled; same vendor as the builder). Run 2026-09-29 in a neutral scratch directory with only `T-3558-external-review-brief.md` as input. Reproduced verbatim below.

---

# External Review — T-3558 (agent-to-agent addressing, identity, trust)

## 1. Is the routing/trust split right?

The split is conceptually correct — "where" and "who" are different failure modes and F-1/F-5 exist precisely because they were conflated (a machine-wide transport identity was doing double duty as an addressing key). But the proposal only executes half of it. Routing gets a concrete, immediate change (`inbox:<circuit-id>`, fallback ladder). Trust gets a bullet list of future TermLink work, one item of which is explicitly marked *optional* ("optionally, hub-side verification"). That asymmetry recreates the two-partial-systems risk the question warns about: once routing is fixed, `inbox:` topics will *look* solved — messages land in the right place, the F-1 collision goes away — while nothing stops another co-resident project from reading that topic or posting into it under a forged `from_circuit`. A clean address is not privacy, and the brief never states whether `inbox:` topics carry any read/write ACL beyond naming convention. If they don't, routing correctness actively increases risk, because it removes the visible symptom (garbled shared mailbox) that made F-1 obvious, while the underlying capability — anyone on the hub can read/write any topic — is untouched. Ship the split, but don't let "routing fixed" ship as if it were "trust fixed."

## 2. Where should identity live?

Per project. Session and agent identities churn too fast to be a trust anchor (a session dies, an agent is respawned) and don't map to anything accountable; AEF's own authority model puts accountability at the human/project level, not the ephemeral session. Host-level is the status quo and is the bug. Hub-level identity doesn't make sense — the hub is a shared namespace, not an actor. This also matches work AEF has already done: `.context/rail-identity.key` is a per-project key. The fix is to actually *use* it for addressing, not just signing. Model it as two layers: the **key** lives at the project rung (authenticates "which project"), and the **circuit-id** continues to carry the finer session/agent address for routing within that authenticated project. Don't conflate the two — a project can rotate which session/agent is active without needing a new key, and a key compromise should not require redesigning the address space.

## 3. Should `dm:` be demoted, or re-keyed?

Re-key it, don't demote it. Demotion creates a permanent two-tier rule — "`dm:` only when keys genuinely differ across machines" — whose applicability silently flips depending on deployment topology: the same logical conversation between the same two projects uses a different prefix depending on whether they happen to land on one host or two. That's a portability violation (AEF's own directive), and it's exactly the kind of prose-level distinction that already caused F-2, where a peer read ruling text and diverged from the code. Two mechanisms for one conceptual act (agent-to-agent message) is more surface area for the next `D-660`-style drift, not less. Re-keying `dm:<project-fp>:<project-fp>` to the trust rung chosen in Q2 lets you keep TermLink's existing mail semantics (wake, receipts, `--await-ack`) as the one mechanism, with `inbox:<circuit-id>` reserved for the fallback-ladder case (recipient key/circuit not yet known) rather than as a permanently parallel scheme.

## 4. Security

**F-1 concretely:** (a) cross-project read of a shared mailbox — already observed, 7 messages/3 projects commingled by construction, not by attack; (b) trivial spoofing — nothing but a hand-typed string tells you who really posted; (c) no confidentiality — any co-resident process with hub access can subscribe to another project's traffic.

**F-5 concretely:** `from_circuit` is user-controlled metadata with no verification, so any project (or compromised agent) can claim to be any other circuit — impersonation for social-engineering an approval, forging a status readout, or polluting the audit trail AEF's own Tier-0 gate logic may eventually read.

**Replay** isn't discussed in the brief at all — worth flagging as an open question: is the signed payload scoped to a specific target circuit-id + timestamp/nonce, or could a legitimately-signed message be recorded and re-posted into a different thread or later time to different effect?

**What the proposal closes:** the *accidental* form of F-1 (collision from multiple projects sharing one literal topic name) — genuinely useful, stops the commingling.

**What it leaves open:** the *deliberate* form of F-1 (unauthorized read of a topic whose name you can guess or discover — `inbox:<circuit-id>` is not a secret, it's a routing convention), all of F-5 (spoofing is only closed if hub-side verification ships and is mandatory — as written it's optional), and replay (not addressed at all).

## 5. Consumption (F-3) — the proposal does nothing here

Correct diagnosis, and the proposal doesn't touch it. Renaming and authenticating the address changes nothing about whether an agent checks the address. The smallest mechanism that would actually move the needle, without any new cryptography:

- **Mandatory unread check at session start/resume.** AEF already has cold-start resume via its memory system — hook the inbox check into that same resume path so an agent cannot proceed past resume without seeing "N unread on `inbox:<your-circuit>`." This directly closes the 24h AEF-internal case and the 73h/49-message peer case, both of which were "delivery happened, nobody looked."
- **Use `--await-ack` and delivery receipts (already built into TermLink) as a hard requirement, not an option**, with a timeout that escalates — post to an alarm/supervisory topic automatically rather than requiring a human to notice and build an alarm after the fact, which is what actually happened in F-3.
- **One canonical topic class to watch.** Part of why the peer's notification rail missed a week of traffic is that AEF moved schemes without every consumer moving with it. Fixing routing (Q1/Q3) *helps* this only if it's the last scheme change — pair it with a requirement that watching logic live in one shared, imported definition rather than being reimplemented per peer from prose.

None of this needs the trust layer to land first — it can and should ship independently and immediately, since it's the measured failure, not the hypothesized one.

## 6. What's missing for this to work in practice

- **Enforcement, not convention.** `inbox:<circuit-id>` is a naming pattern; nothing in the brief says the hub enforces who may read or write it. A style guide is what failed in F-2 (peer read the ruling text, not the code) — the fix needs to be a shared, imported schema/reference implementation both AEF and peers consume, not a second prose ruling.
- **Make hub-side signer verification mandatory, not optional.** "Optionally" guarantees uneven adoption across peers, i.e., the same inconsistency that produced F-2.
- **Key lifecycle is undefined.** No mention of rotation, revocation, or what happens to past-signed messages when `rail-identity.key` is regenerated. Trust claims are meaningless without this.
- **Migration path.** The existing 7-message shared `dm:` topic and any peer hard-coded to old prefixes need an explicit deprecation/dual-write window — not mentioned.
- **Cross-host identity collisions.** The circuit's leftmost rung is `host`, but nothing says how two independently-operated hosts agree on non-colliding host names, which matters since TermLink is explicitly cross-host.
- **A regression test for F-3 itself.** Given AEF's own rule that verification commands must pass before a task closes, this proposal should ship with a synthetic canary (a message with an SLA) so a future silent-consumption gap is caught automatically instead of manually, as happened here.

```
VERDICT: amber
GUIDANCE:
  1. Make hub-side signature verification against `from_circuit` a hard
     requirement of this change, not an optional follow-on — otherwise F-5
     stays fully open while the addressing change ships and looks "done."
  2. Re-key `dm:` to the project-level identity instead of demoting it to a
     narrow "different machines only" case; a topology-dependent choice of
     prefix for the same logical conversation is fragile and repeats the
     ambiguity that caused F-2.
  3. Specify key lifecycle (issuance, rotation, revocation) for the
     project-level identity before any hub-side verification is built —
     otherwise "verify the signer" has no defined failure behavior.
  4. Ship a consumption fix in this same change, independent of the
     addressing/trust work: mandatory unread-check on session
     resume, mandatory (not optional) use of `--await-ack` with a
     timeout-triggered escalation. This is the failure that was actually
     measured (F-3); the addressing work does not touch it.
  5. Publish the address/prefix rules as one shared, machine-checked
     definition both AEF and peers import, not as ruling prose — that is
     what a peer misread last time (F-2).
TOP RISK: the proposal fixes the topic-name collision (F-1's visible
symptom) but leaves messages unauthenticated and unenforced (F-5) and does
nothing for the consumption gap (F-3), which the brief itself identifies as
the real, measured failure — so a clean-looking address scheme could ship
while the two problems the operator actually cares about remain open.
```
