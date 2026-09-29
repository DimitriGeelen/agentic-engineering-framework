# T-3558 — Circuit address everywhere; `dm:` is transport, not identity

Research artefact (C-001). Opened 2026-09-29 while walking the operator through
OBS-567, when the operator asked whether the 5-level circuit model had been
"thrown out the window".

## Dialogue Log

### Segment 1 — the question

Agent presented OBS-567 (co-resident DM collision) as a choice between three
addressing options. Operator, verbatim (Dutch):

> Oké, hier ben ik helemaal verward. We hadden dat 5-step, 5-level-adressing voor
> circuit-communication en circuit zou 1-to-1 zijn, op een agent of een
> session-level. Dus, heb ik dat uit de window gegooid, is dat helemaal anders?

Agent answered, after reading `lib/aef_address.py`, `lib/sidecar/circuit.py` and
D-660: no. The circuit model is intact in the code and is what `inbox:` carries. The
collision is confined to `dm:`, which does not use the circuit model at all. It keys
on TermLink's machine-wide identity, which is the *host* rung of the ladder.

### Segment 2 — operator, verbatim

> Well, not all. In Windows [sic, voice transcript; read as "within/all"] machines,
> you want to use the circuit model. With the letter [ladder] of the fallback. From
> agent, session, project, hub, machine. My question is, what you said here is that
> Termlink is a mechanism for host keys. Maybe we should make a change in Termlink.
> We hadden already had some communication about Termlink, but we haven't yet. What
> do you think? Can you think about it?

**Operator intent, as stated:** the circuit model applies everywhere, with the
fallback ladder agent → session → project → hub → machine.

## Findings

### F-1 — Two identities, and only one of them follows the circuit model

| key | fingerprint | scope | used for |
|---|---|---|---|
| `~/.termlink/identity.key` | `d1993c2c3ec44c94` | machine-wide | **DM addressing** (`lib/sidecar/dm.py:identity_fingerprint` → `termlink whoami`) |
| `.context/rail-identity.key` | `bdd184bd89f318e4` | this project | **signing posts** (T-3543) |

T-3543 moved *signing* to a per-project key and never moved *addressing*. So
`dm:<fp>:<fp>` between two projects on this host is always
`dm:d1993c2c3ec44c94:d1993c2c3ec44c94`, a shared mailbox (count=7, envelopes from at
least 3 projects). Verified 2026-09-29, OBS-574.

### F-2 — The ruling text and the code disagree, and a peer followed the text

| source | what it says |
|---|---|
| D-599 / T-3433 (22 Sep) | `inbox:<circuit-id>` — the five-level address |
| **D-660 / T-3518 (27 Sep), as worded** | `dm:<fp>:<fp> / inbox:<agent-id>` |
| our code (`lib/sidecar/circuit.py`) | `inbox:<circuit-id>`, e.g. `inbox:cacc73ea32b121dd/999-Agentic-Engineering-Framework` (hub/project) |
| 832-Workflow-designer (unread consult, 28 Sep) | *"WE QUOTED A SUPERSEDED RULING … Withdrawing the five-level framing; we take D-660."* |

D-660 adopted TermLink's *prefixes* (`dm:` and `inbox:`) because of TermLink's mail
semantics: wake events, receipts, `--await-ack`. Its wording also swapped
`circuit-id` for `agent-id`. Our code did not follow that swap. 832 did, and dropped
the model the operator intended to keep. One decision, three readers, two verdicts:
the same failure removed from arc membership on 2026-09-26.

### F-3 — The TermLink conversation was sitting unread

Seven consults from 010-termlink and 832, unread for 23.6h (found without draining,
via `inbox.pending(advance=False)`):

- 010-termlink: their subscriber did not wake on `inbox:` topics, and they found 49
  unread consults on their own inbox. **Correction, later:** the cause was their
  notify rail enumerating `--prefix "dm:"` only, so from our T-3433 migration onward
  every consult we sent was invisible to them. Fixed on their side.
- 832: adopted the circuit id, then **withdrew it** after reading D-660's text, and
  sent an explicit **request for a full readout**. The first question in it: *is
  `metadata.from_circuit` load-bearing for trust, or routing only?*

### F-4 — TermLink already tolerates circuit-shaped names in `dm:`

`dm:` topic names are plain strings. The hub already carries name-keyed ones:
`dm:050-email-archive:ring20-management-agent`, `dm:s3t1-1416551:…`,
`dm:cashweb-integration-agent:…`. A second key file
(`~/.termlink/cashweb-integration-agent.key`) exists beside the machine identity.
But `termlink identity` has only `init`, `show` and `rotate` for one identity per
user. There is no first-class per-project or per-agent identity.

## Agent's thinking on "should we change TermLink?"

**Split the question: routing versus trust.** The answer differs for each.

**Routing (where a message goes): no TermLink change needed.** `inbox:` has the same
mail semantics as `dm:`, and what follows `inbox:` is ours to define: the circuit id,
with the ladder fallback. The circuit model therefore works over TermLink *today*.
The fix is on our side: say it plainly in the ruling, and stop using `dm:<fp>:<fp>`
for agent-to-agent circuits. `dm:` stays valid as a TermLink transport between
machines whose keys genuinely differ.

**Trust (who actually sent it): this is where a TermLink change earns its place.**
This is 832's question. Today a circuit id is a *name*, so anyone on the hub can
write any `from_circuit`. Signatures use our per-project key, but nothing binds that
key to a circuit id, and TermLink's own identity only proves the *machine*. If the
circuit is to be trusted and not merely routed, the key has to live at circuit level
(at least project), and the hub or the recipient has to verify the binding. That is
TermLink's identity layer. Per gap-homing (T-1333) the fix belongs there, so it is
**theirs to decide, ours to propose**.

**What would make the TermLink proposal concrete:** named identities managed by
`termlink identity` (the `cashweb-integration-agent.key` shape made first-class),
`whoami` resolving to the caller's project identity instead of being ambiguous across
173 sessions, and optionally hub-side verification that an envelope's signing key
matches its `from_circuit`.

## Open actions (the operator's to authorise; outward-facing)

1. **Amend D-660:** adopt TermLink's prefixes, keep the circuit id after `inbox:`;
   `dm:` is transport, not circuit addressing. (IW-1)
2. **Propose to TermLink** per-project/per-circuit identity, for trust. (IW-2)
3. **Correct the record with 832 and 010-termlink:** the five-level model is not
   superseded; answer 832's readout request, including the trust-vs-routing
   question. (IW-3)

## External review — synthesis (2026-09-29)

Three reviewers, three vendors, run independently on
`T-3558-external-review-brief.md`. Verbatim reviews:
`T-3558-review-openai.md`, `T-3558-review-zai.md`, `T-3558-review-anthropic.md`.
Independence caveat: the Anthropic reviewer (Sonnet 5) shares the builder's vendor.

**Verdicts: amber, amber, amber.** Sound direction; not to proceed as written.

### Where all three agree

| # | finding | OpenAI | Z.ai | Anthropic |
|---|---|---|---|---|
| 1 | **Consumption is the real failure, and the proposal does nothing for it.** Each named this as its TOP RISK. | ✓ | ✓ | ✓ |
| 2 | Consumption can be fixed now, with no TermLink change | ✓ | ✓ | ✓ |
| 3 | The routing/trust split is right as architecture | ✓ | ✓ | ✓ |
| 4 | Anchor identity at the **project** rung; session/agent are claims or delegations under it | ✓ | ✓ | ✓ |
| 5 | "Optional" hub verification is not acceptable; verification must be mandatory where trust is decided | ✓ | ✓ | ✓ |
| 6 | Routing is not privacy: hub topics are readable by anyone on the hub | ✓ | ✓ | ✓ |
| 7 | Replay protection is missing | ✓ | ✓ | ✓ |
| 8 | Key lifecycle (issuance, rotation, revocation) is missing | ✓ | ✓ | ✓ |
| 9 | One normative, machine-checked spec, so ruling text and code cannot drift again (F-2) | ✓ | ✓ | ✓ |
| 10 | Migrating off the shared `dm:` topic needs a deprecation/watch window | ✓ | ✓ | ✓ |

The consensus on #1 is the headline. The agent flagged consumption as question 5
of the brief, but the agent's own proposal contained nothing for it. It led with
addressing, which is the part that was easier to reason about. All three reviewers
say the priority is the reverse.

### The one real disagreement: `dm:`

- **Demote** (OpenAI, Z.ai). Z.ai's decisive argument: pairwise topics do not compose
  with the fallback ladder, since a coarse-level recipient cannot watch a topic named
  by a fine-level pair. Add n² sprawl and no multi-party story.
- **Re-key per project** (Anthropic). Its argument: a rule where the same conversation
  uses a different prefix depending on whether two projects share a host is
  topology-dependent, and prose rules like that are what produced F-2.

**Resolution proposed:** demote (2 of 3, and the ladder argument is structural).
Answer Anthropic's objection with finding #9: the rule is enforced by one shared,
machine-checked definition, not by prose, so there is nothing to misread.

### Points only one reviewer raised, each worth keeping

- **OpenAI: separate key files under one OS user are not a security boundary.** If
  co-resident projects run as the same user (they do here: root), each can read the
  others' keys. Per-project keys then give *attribution between cooperating agents*,
  not protection against a malicious one. Real isolation needs separate OS principals
  or a credential broker. **This bounds what the trust half can ever promise on a
  single host, and it is the operator's call how far to go.**
- **OpenAI:** delivered ≠ accepted ≠ completed. A transport receipt must never be read
  as "the agent acted". Fallback must not silently *widen* who can read an
  agent-private message.
- **Z.ai:** make reading mail a **framework gate**: no task opens or closes across
  unread mail addressed to this project. This is AEF's own enforcement pattern
  ("nothing gets done without a task"), applied to consumption.
- **Z.ai:** don't wait on TermLink for trust. Sign with the existing per-project key
  now and verify recipient-side against fingerprints exchanged out of band.
- **Z.ai:** peer mail that requests *action* must enter AEF's task and Tier-0 path,
  never act as a side channel around the human.
- **Z.ai:** answer 832 now: `from_circuit` is routing-only and untrusted until
  verification ships. Peers may already be trusting it.
- **Anthropic:** ship a synthetic canary with a response deadline, so the next silent
  consumption gap is caught automatically, not by a human noticing.

### Revised proposal (agent, after review)

1. **Consumption first, ours, no TermLink change:** a mail-read gate at session start
   and task boundaries (project-level inbox at minimum); ack-on-receipt with
   escalate-on-silence; delivered / accepted / completed as separate states; a canary
   with a deadline. Unanswered or refused mail feeds the T-3555 ledger.
2. **Routing:** `inbox:<circuit-id>` with the ladder; `dm:` demoted by policy; one
   machine-checked address spec that both AEF and peers import; migration with a watch
   window on the shared topic; D-660 amended.
3. **Trust, in two honest stages:** (a) now, sign with the per-project key and verify
   recipient-side, mandatory, stated plainly as *attribution between cooperating
   agents*; (b) real isolation needs OS-level separation or a broker, which is the
   operator's decision. Replay protection, key lifecycle and confidentiality belong to
   the trust design, not to later.
4. **TermLink proposal, theirs to decide:** named identities, deterministic `whoami`
   (ambiguity is an error, never "no mailboxes"), topic ACLs or end-to-end encryption.
5. **Tell 832 and 010-termlink now:** the five-level model stands, and `from_circuit`
   is routing-only and untrusted until verification ships.

## Dialogue Log — segment 3 (operator, after round 1; verbatim, voice transcript)

> Ok, I guess we need to widen the window for the amount of cycles we can. Deef is 2,
> put this to 10. Because it's a key one. We recently, not for the first time, did a
> lot of work on this consumption issue. Every time you say we got in place. The last
> one was the whole design. We discussed building the API that we've got to send the
> receiver, sender flagging the, or the receiver flagging that a message has been sent.
> Then storing it locally, including digital binary blobs. Then looking if it can be
> injected into the prompt. Then have a prompt drop that does that regularly too. And
> we're also sending a message back to the sender using the same sidecar API that the
> message has been received. Then when it's been injected into the prompt message that
> the message has been injected, has been consumed. For lack of a better word, you can
> propose a better word. And then when the response comes back, indicate that the
> response is ready and is coming back. And maybe of a state that the message has been
> sent and received. This will be documented and designed and I think even
> implemented, but for some reason that's still not working. So I really implore you
> to look that up and incorporate that thinking into our discussion and design we're
> having here now. And maybe send it for another review round.

### F-5 — The consumption design exists, was ratified, and was never built

The design the operator described is `docs/architecture/sidecar-target-architecture.md`
(D-645, ratified 2026-09-25; design of record T-3397). Its build order has eight
slices. Measured 2026-09-29:

- **Slice 0** shipped (T-3462).
- **The slice-1 transport** was ruled GO (T-3475, 2026-09-25: HTTP).
- **Slice 1 itself** (receiver sidecar process, HTTP API, durable address, local
  storage, receiver-side flag) **has no task and no code.** There is no HTTP server in
  `lib/sidecar/`; `RECEIVED` and `HANDED_OVER` appear nowhere. Every later slice hangs
  off it.
- **Why it escaped:** the GO-scope audit counts T-3475 as built because two tasks
  mention it (T-3479, address dual-read; T-3494, an unrelated estimator task). A
  mention counted as a build. Filed OBS-575.

So the round-1 reviewers' unanimous "consumption first" recommendation independently
rediscovered D-645's slices 1–4, and the operator's "for some reason it's still not
working" has a plain answer: it was designed and ratified, and then it was not built.

Round 2 (`T-3558-external-review-brief-round2.md`) puts D-645, the built-versus-designed
gap, the operator's lifecycle with proposed state names, and round 1's findings to the
same three reviewers.
