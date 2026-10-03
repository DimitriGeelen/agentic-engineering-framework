RECOMMENDATION: B — route on function names (what a human can say out loud), carry every instance id inside, and make instance-pinning an explicit opt-in; it is the only option whose addresses survive cert rotation, respawns, and re-checkouts.

SCORES:

| Driver (weight) | A | B | C | D |
|---|---|---|---|---|
| D1 Antifragility (9) | −2 | +2 | −1 | 0 |
| D2 Reliability (7) | −2 | +2 | 0 | −1 |
| D3 Usability (5) | −1 | +1 | 0 | 0 |
| D4 Portability (3) | −2 | +1 | +1 | 0 |
| F-RECALL Recall Leverage (6) | −1 | +1 | −1 | −1 |
| F-AUTONOMY (4) | 0 | +1 | 0 | 0 |
| **Total** | **−49** | **+50** | **−12** | **−13** |

Dropped: **F1 Context Fabric** — the address scheme is something memory *stores*, not something that shapes the memory layer; the pointer-rot effect is counted once, under F-RECALL. **F2 Component Fabric** — `pid` is the routing project boundary in every live option (delivery never crosses projects), so topology and blast-radius semantics don't change. **F3 Prompt quality** — no prompt templates change; ease of composing an address is an agent-usability effect, scored under D3.

PER OPTION:

**A — Steelman.** Precision is safety. `@research#inst-4` is unambiguous: no stale clone picks up the work, nothing is duplicated, and every hop is self-describing — an auditor reconstructs the exact machine, hub instance, checkout, and session from the envelope alone, no lookups. For a framework whose core product is audit trails, an address that carries its own provenance is the most honest address, and extra labels on the wire are information, which never hurt.

**A — Strawman.** Make a sender collect five ephemeral values — a DHCP-reassignable IP, a fingerprint that rotates on cert renewal, a checkout id, a session id, an instance id — just to say "hey, research." Every routine operational event silently breaks or misdelivers, and after any respawn the whole address book is garbage. It's a stack trace cosplaying as an envelope.

**B — Steelman.** Route on the names humans think in (`host`, `hub=main`, `pid`, `@research`); carry the churn (IP, fingerprint, checkout, lease expiry) inside as metadata for those who need it. Routine stress passes through — rotate certs, respawn agents, re-checkout, the address still resolves. When a sender genuinely needs one exact instance, it opts in explicitly with `exact-instance`, so A's precision is available where it pays and absent where it hurts. And this is the two-name model the operator and TermLink's operator *independently converged on*, matching the vendor review point for point: no IP (7/7), pid as the only project identity (7/7), agent function name routes (7/7).

**B — Strawman.** "Function names route" — until two clones of one pid both run `@research` and the bug report lands on the idle one; the name was stable, the delivery was wrong. The plan also silently depends on TermLink minting stable hub names it hasn't minted yet: until then B is just C with an IOU. And the `exact-instance` hatch means every sender now makes a per-message policy decision it was never trained to make.

**C — Steelman.** Zero new dependencies, deployable this afternoon: the fingerprint already exists and already routes. A TLS fingerprint has a property no friendly name ever will — it is cryptographically bound to the hub's certificate, so the address is simultaneously a route and an identity check, with no registry and no fight over who owns the name `main`. Google and xAI said exactly this: one label until multi-hub is actually decided (2 of 7 vendors).

**C — Strawman.** The hub's routing name changes on a schedule nobody here controls — cert renewal — and it names every durable inbox topic, so each rotation renames the entire mail system mid-flight. It is unreadable, untypeable, and post-rotation every log line and archived address points at a name that no longer exists. C isn't minimalism; it's B with the one known-broken part deliberately retained.

**D — Steelman.** TermLink owns the transport and IW-3 is open; ruling on envelope shape before the implementer speaks risks a decision rewritten within a month. The hub-label consensus was the weakest in the review (5/7), which is precisely the signal to wait. A late ruling costs a few weeks; a wrong one costs a migration.

**D — Strawman.** The shape is already settled by parties who don't need waiting on — the operator's model, TermLink's operator independently proposing the same thing, and 7/7 vendors on everything but the hub label. IW-3 will answer *how* names resolve to ids, not *whether* envelopes carry names — so defer the mechanism, not the envelope. Meanwhile 2b is blocked, the fingerprint keeps naming durable topics, and every future session re-asks the question from zero.

WHERE THE AGENT'S SCORING IS WRONG:

- **A/D1 and A/D2 at −1 each are far too gentle.** Cert rotation, DHCP reassignment, and respawn are *routine, scheduled* stresses under A: topics rename, IP reuse can silently misdeliver cross-host, and respawned instances dead-letter. "Fragile under routine stress" is −2 on both drivers, not −1.
- **A/D3 at 0 is wrong.** Senders must compose addresses from live values they don't have (IP, fingerprint, checkout, session, instance ids). That is a daily usability tax and constant cryptic failures: −1.
- **A/F-AUTONOMY at +1 is backwards.** Precision that requires discovering ephemeral ids forces *more* lookup and human disambiguation, not less. 0 at best.
- **C/D1 and C/D2 at +1 each are wrong.** C retains the exact defect this decision exists to fix: a rotating routing key that names every durable topic. Rotation is scheduled fragility, not learning (D1 −1), and post-rotation stale-address failures are the opposite of predictable and auditable (D2 0, not +1).
- **C/D3 at +1 is wrong.** Opaque fingerprints in every address and log line; an "unknown hub cacc73ea…" error after rotation is not actionable. 0.
- **Dropping F-RECALL is the agent's biggest miss.** Addresses are the most-copied artifacts in logs, episodic memory, and decision records. Under A and C they rot (embedded fingerprints and instance ids stop resolving — memory points at ghosts); under D every future session re-discovers the question; only B yields recorded addresses that stay resolvable. That's a weight-6 driver scored for free.
- **D's cost isn't only D2.** Deferral is decision debt that future sessions pay by rediscovery (F-RECALL −1), and it blocks 2b, which depends on knowing what routes.
- Where the agent is *right*: B's D1 +2 and A's D4 −1 are fair, and its winner survives my attack. Its margins don't — B's lead over C is far larger than +44 vs +24 suggests, because C is net-negative once F-RECALL counts.

WHAT A RULING FOR B MUST STILL SETTLE:

- **The TermLink prerequisite and the interim.** Who commits stable hub names, by when, and what routes until they exist — explicitly bless the fingerprint as a temporary hub label *inside* a B-shaped envelope, with a migration plan, or not.
- **Clone semantics.** Two clones share one `pid` and may both run `@research`: does function-name routing deliver to any live one, load-balance, or error? Hub or sidecar owns the tiebreak?
- **Exact-instance failure handling.** Pinned instance dead → dead-letter, return-to-sender, or fall back to the function name? Keep this cleanly separable from 2b's respawn policy.
- **Durable topic migration.** `inbox:<hub>/<project>` today embeds the fingerprint; a stable hub name renames every topic. Who runs the migration, and what happens to in-flight messages addressed under the old name?
- **Where instance ids come from.** A sender marking `exact-instance` needs a way to discover current instance ids (lease/service directory) — plus an explicit rule that display-only labels (checkout alias, session name) never silently become routing keys.
