<!-- reviewer: deepseek/deepseek-v4-pro-0813 via OpenRouter; tokens in 1529 out 2032; cost 0.00382427456 -->

RECOMMENDATION: B — function names route; instance ids ride inside

SCORES:

| Driver (weight) | A | B | C | D |
|---|---|---|---|---|
| D1 Antifragility (9) | −1 | +2 | +1 | 0 |
| D2 Reliability (7) | −1 | +2 | +1 | −1 |
| D3 Usability (5) | 0 | +1 | +1 | −1 |
| D4 Portability (3) | −1 | +2 | +1 | 0 |
| F-RECALL (6) | −1 | +1 | 0 | −1 |
| F-AUTONOMY (4) | 0 | +1 | 0 | −1 |
| F3 Prompt quality (7) | 0 | +1 | +1 | 0 |
| F1 Context Fabric (7) | 0 | 0 | 0 | −1 |
| F2 Component Fabric (6) | 0 | +1 | 0 | 0 |
| **Total** | **−15** | **+62** | **+29** | **−23** |

Dropped drivers: none. The agent dropped F-RECALL, F1, F2, F3 claiming they are untouched. That is wrong. Routing-address design shapes what future sessions can retrieve (F-RECALL), how the memory layer resolves names across clones (F1), how topology maps treat project instances (F2), and how prompts must be written against the address grammar (F3). I score all of them, but modestly: the decision constrains these drivers rather than activating them.

PER OPTION:

**A — both labels at every level route.**
Steelman: Nothing is ambiguous. The envelope carries every possible identity, so a router can decide on any field without opening the message. This is the only option that survives a future where multiple hubs, multiple sessions, and multiple agent instances do not all agree on name resolution. It makes every routing decision explicit on the wire, which is easiest to audit mechanically. An advocate would say: the verbose address is the address that cannot lie.
Strawman: This is address sprawl. Every certificate rotation, every respawned agent instance, every checkout change forces every sender to know ephemeral detail just to place a call. The envelope becomes a serialisation of the running estate rather than a route. Its real motive is fear of resolution logic, not a design principle; it punts all naming complexity into every message forever.

**B — function names route; instance ids ride inside** (agent’s recommendation).
Steelman: The envelope carries what routing actually needs — stable, functional identity — and the inside carries what the receiver needs to disambiguate the running instance. This separates “where does this message go” from “which exact thing should act on it,” which is exactly the split routing versus metadata exists to enforce. It keeps addresses stable across certificate rotation and agent respawn, which are exactly the events that should not break delivery. An advocate would sign: route on what is true, not on what is running.
Strawman: B is unresolved. It assumes TermLink will supply stable hub names it has not yet supplied; until then, it is A’s complexity with extra steps and one hand waving at a future promise. The “exact-instance” marker is a second, ad-hoc routing path smuggled inside the envelope design, which means senders must understand two addressing grammars. It also quietly imports a semantics problem: “function name” means different things at host, hub, project, and agent level, and B does not define those boundaries.

**C — minimal.**
Steelman: C accepts reality: today’s hub name is its fingerprint, and the routing system works. It makes the smallest possible change — project and agent function names route, instance detail rides inside — without inventing a hub-naming scheme TermLink has not committed to. An advocate would say: do not let a stable-name wish become a routing blocker; adopt C now and rename later when the stable hub name exists.
Strawman: C bakes the certificate rotation failure into the address standard. A hub whose identity changes whenever TLS rotates is not a name, it is an accident of infrastructure; routing on it means every rotation is a system-wide address migration. C is the option that looks minimal today and costs most tomorrow, because it standardises the transient as if it were permanent.

**D — defer.**
Steelman: The only honest option. The operator and TermLink independently converged on the two-name model, so TermLink’s IW-3 view is not a dependency, it is a co-owner of the decision. Deciding the routing grammar before hearing how the name-to-id resolver will work risks standardising against a mechanism that is about to change. An advocate would say: a decision about the envelope is premature when the sorting office has not published its routing tables.
Strawman: Deferral here is not patience; it is stalling on a decision whose facts are already in the brief. Every day without a ruling means every message continues to carry the wrong mixture of stable and ephemeral labels, and every agent integration bakes in whatever its author guessed. D converts an engineering decision into an unbounded wait for a vendor’s permission slip.

WHERE THE AGENT’S SCORING IS WRONG:

- **D1 / B inflated.** The agent gives B +2 on antifragility, implying B alone makes failure modes strengthen the system. But B depends on an external stable-hub-name service which does not yet exist. A routing design with an unresolved dependency cannot be fully antifragile; +1 is defensible, +2 is premature.
- **D1 / C too generous, and D too kind.** The agent gives C +1 on antifragility and D 0. C standardises the fingerprint, making certificate rotation a recurring address failure — that is fragility, not neutrality. D earns 0 only if deferral is neutral; on this estate, deferral lets incompatible address conventions accumulate, which actively harms future adaptation.
- **D2 / B vs C.** The agent rates B +2 and C +1 on reliability. That gap is real if TermLink delivers stable hub names, but the brief does not say it has. Until that lands, B and C are equally reliable on the wire; scoring B as clearly more reliable treats a promised future as present fact.
- **D3 / D.** The agent gives D 0 on usability. Deferring is not usability-neutral: it leaves every agent author to invent their own address convention, which is the least usable outcome possible for debugging across a multi-project estate. D deserves −1, perhaps −2.
- **D4 / B vs C.** The agent gives B +1 and C +1 on portability. But B introduces a dependency on TermLink’s naming service, which is a provider-specific touchpoint at the exact layer portability cares about. B should beat C here: B’s stable name decouples routing from a transport-layer artifact; C locks portability to TLS rotation behaviour.
- **F-AUTONOMY / A and C.** The agent gives A +1 and C 0 on autonomy. Both are wrong in opposite directions. A makes every sender responsible for every runtime id, which creates more failure-checkpoints, not fewer — 0 or −1. C, by quietly enshrining fingerprint rotation as an address event, creates a recurring human-in-the-loop migration; that harms autonomy, so 0 overstates it.
- **Dropped drivers / all four.** F-RECALL, F1, F2, F3 are not untouched. A routing address is part of the frame future sessions retrieve (F-RECALL); memory search over a session that moved instances depends on stable project-level names (F1); blast-radius maps need to know whether one checkout is routable separately from another (F2); prompt engineering for agent-to-agent message construction depends on how many fields must be specified (F3). None is decisive, but none is zero.

WHAT A RULING FOR B MUST STILL SETTLE:

1. **The exact definition of “function name” at each of the five levels**, including whether session is a function name or an instance label. The agent’s concrete example implies session is optional on the envelope; that must be stated, not implied.
2. **The stable-hub-name mechanism and its fallback.** B assumes TermLink will provide it. The ruling must say what the hub routing name is until then, and what the migration path is from fingerprint to stable name, including what old fingerprints resolve to.
3. **The `exact-instance` marker’s grammar and failure behaviour.** If a sender marks `exact-instance` but the named instance is dead or unreachable, the ruling must specify: queue, reject, fall back to the function route, or prompt a human. “Separate decision 2b” cannot defer the delivery semantics here because B introduces the marker.
4. **Delivery never crosses projects — enforced or assumed?** The brief says it is agreed with TermLink. The ruling must state what happens if an envelope names a project function but also carries cross-project instance metadata inside: does the hub drop it, bounce it, or route on the project function alone?
5. **Clone semantics under one pid.** Two clones share one pid. If one clone must message the other, does the envelope route to the pid and the inside disambiguate the checkout, or do clones of one project never message each other? B implies the former; the ruling must make that explicit, because it determines whether checkout ids ever need routing weight.
