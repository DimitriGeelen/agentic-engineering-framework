# T-3558 external review — zai

Reviewer: Z.ai GLM-5.3 (opencode, Z.AI Coding Plan). Run 2026-09-29 in a neutral scratch directory with only `T-3558-external-review-brief.md` as input. Reproduced verbatim below.

---

## Review: agent-to-agent addressing, identity and trust (T-3558)

### 1. Is the routing/trust split right?

Yes, as architecture; no, as sequencing. Routing (where) and trust (who) are genuinely different problems, and conflating them is what produced F-1: a machine identity was asked to do both jobs and did neither. But the proposal lets routing land now and defers trust to a future TermLink change, creating an indefinite window where `inbox:<circuit-id>` is universally routable and universally spoofable (F-5 unmitigated) — and hub-side verification is only "optional". Worse, the split ignores a cheap interim: AEF already holds a per-project signing key (`bdd184bd89f318e4`). Recipients can sign-and-verify payloads end-to-end over an untrusted hub *today*, with fingerprints exchanged out-of-band, without waiting for TermLink's identity layer. The proposal gates a solvable problem on someone else's roadmap. The split is right; the schedule and the ownership of the trust half are wrong.

### 2. Where should identity live?

Per **project**, with session/agent carried as signed claims inside the envelope, and the machine key retained purely as transport identity.

Reasoning: the project is AEF's unit of accountability — the human owner, governance rules, and the existing signing key all live there. Agents and sessions are ephemeral instances of a project; keying at that level means keys die on restart or need a registry mapping them back to the project, at which point the project key is the anchor anyway. The decisive constraint is the fallback ladder: trust must be anchored at or above the coarsest address you actually use. Observed traffic uses hub/project level (`inbox:cacc73ea32b121dd/999-Agentic-Engineering-Framework`); if keys were per-session or per-agent, every fallback delivery to project level would arrive at a rung that cannot verify as the addressee. Per-project keys keep address level and trust level consistent. This also fixes F-4 deterministically: identity resolves from cwd → project root → key, not from 173 candidate sessions — and "ambiguous whoami treated as no mailboxes" must become a hard error, not a silent default (it is a confused-deputy hazard and violates AEF's own no-silent-failures directive).

### 3. Should `dm:` be demoted?

Demote, but as **policy, not mechanism**: AEF never uses `dm:` for agent traffic; `inbox:` carries everything; `dm:` remains available for host-key transport where keys genuinely differ. Do not re-key `dm:` per project: pairwise topics have an n² sprawl and canonical-ordering problem, no story for multi-party conversations, and — fatally — they don't compose with the fallback ladder (a coarse-level recipient can't watch a topic named by a fine-level pair). Two caveats the proposal misses: (a) pairwise *privacy* between co-resident projects must then come from payload encryption to the recipient's published project key, not from topic naming; (b) abandoning `dm:d199…:d199…` must be a coordinated migration with a deprecation watch window — F-3 happened precisely because a peer's watcher was left on a topic AEF silently stopped using. Publish the change, watch both topics for a defined period, post a final notice to the old venue.

### 4. Security

Concrete threats:

- **Spoofed sender (F-5):** anyone with hub post access claims any `from_circuit`. Proposal closes this only if verification is *mandatory*. "Optional hub-side verification" is worse than none — it mints a "verified" signal that recipients will over-trust. Make verification recipient-side and mandatory (unverified messages render flagged), hub-side optional as defence in depth.
- **Cross-project reading (F-1):** the proposal fixes *interleaving*, not *eavesdropping*. Hub topics remain globally readable append-only logs; unless TermLink adds ACLs (it has none), every project on the hub — and every host the hub spans — can read every other project's inbox. Task content, code, credentials flowing peer-to-peer into world-readable topics is a live data-exposure surface. Close it with end-to-end encryption to the recipient's published key; keep the hub untrusted.
- **Replay:** unaddressed. A signed message re-posted, or a stale instruction re-consumed after a crash, defeats signing (the signature is still valid). Need per-sender monotonic sequence numbers, freshness windows, and idempotent consumption. Signing without replay protection is half a control.
- **Additional gaps:** inbox-name squatting (what binds `inbox:<circuit>` to its rightful owner — first-come wins helps attackers); key rotation and revocation (nothing published, nothing revocable — and confirm `rail-identity.key` never travels in anything that clones or syncs); wake-event authenticity once agents act on wakes.

Closed: co-resident interleaving (immediately), attribution (eventually, if verification becomes mandatory). Open: confidentiality, replay, squatting/binding, revocation, and the entire interim window before TermLink ships.

### 5. Consumption (F-3)

Nothing in the proposal addresses it. It is an addressing-and-identity proposal; the measured failure is that nobody reads the mail — 73h round trips, 49 unread, AEF's own 7 unread for 24h until a same-day alarm. A perfect identity layer over unread inboxes produces authenticated 73-hour silences. Smallest mechanism that works, using only what exists:

1. **Make mail consumption a gate, not a habit.** AEF's entire thesis is structural enforcement ("nothing gets done without a task"); add "no task opens or closes across unread mail addressed to this project's circuit." Every session start and task boundary reads `inbox:` at project level. This converts noticing from opt-in behaviour to framework rule, and it productizes the alarm AEF already built once.
2. **Ack-on-receipt, escalate-on-silence.** TermLink already has wake events, receipts, `--await-ack`. Rule: any inbound message requesting response gets an immediate machine ack ("seen by `<circuit>`, disposition pending"); no disposition within a deadline (one working session / N hours) raises an alarm. Round trips collapse from days to minutes-plus-disposition.
3. **Watch every rung you own, at minimum project level.** F-3 happened because a peer watched one prefix. The ladder only works if the coarse levels are always attended; sessions may watch finer.

None of this requires a TermLink change. It should ship before or with the routing change, not after.

### 6. What is missing

- **A key directory and lifecycle story.** Where does a verifier get the authoritative project fingerprint? Publish a signed "project card" (fingerprint, scheme version, watched topics) at a stable topic at project registration, confirmed out-of-band by the operator. Without this, verification cannot start and TOFU lets squatters win. Plus rotation/revocation windows.
- **A migration and spec-integrity protocol.** F-2 (ruling text vs code) and F-3 (silently moved topics) were coordination failures. Generate the ruling's examples from the code's constants or vice versa — one normative source. Version the addressing scheme per project so peers can detect drift.
- **Cross-host semantics.** The circuit's `host` rung and fallback-to-host are undefined when hubs are per-host. What routes between hubs, and what does "host" address? This will break exactly when multi-host matters.
- **Mapping inbound mail to AEF's authority model.** A peer message that requests action must flow into task creation and Tier-0 approval, not act as a side channel around the human. The proposal is silent on whether peer mail can spawn tasks and who owns acceptance criteria.
- **State the answer to the peer's open question now:** `from_circuit` is routing-only and untrusted input until verification ships. Peers may already be trusting it.

```
VERDICT: amber
GUIDANCE: Direction is sound; require these changes before proceeding.
  1. Ship the consumption half first or simultaneously: mail-read as an AEF gate at
     every session start and task boundary (project-level inbox at minimum), plus
     mandatory ack-on-receipt with escalation-on-silence. No TermLink change needed.
     Without this the measured failure (F-3) is untouched.
  2. Do not gate trust on TermLink: start signing payloads with the existing
     per-project key now and verify recipient-side against out-of-band fingerprints.
     Verification must be mandatory recipient-side; drop "optional hub-side" as the
     primary control before it mints over-trusted attestations.
  3. Anchor keys at project level; sessions/agents are signed claims inside the
     envelope; machine key stays as transport identity. Fix F-4 by resolving identity
     from project context and make ambiguous whoami a hard error.
  4. Add confidentiality, replay, binding and rotation to the trust half: end-to-end
     encryption to published recipient keys (hub stays untrusted), per-sender
     sequence numbers with idempotent consumption, inbox-name-to-key binding, and a
     revocation story. The proposal currently closes only spoofing, partially.
  5. Treat the dm: demotion as a coordinated migration with a deprecation watch
     window on the old shared topic, and make ruling text and code derive from one
     source so F-2 cannot recur.
  6. Define cross-host hub routing and how inbound peer mail enters AEF's task/Tier-0
     authority path before multi-host use.
TOP RISK: The proposal optimizes addressing while the brief itself shows the real
  failure is consumption — nothing in it makes an agent notice or act on a message,
  so a complete identity layer still yields authenticated 73-hour silences.
```
