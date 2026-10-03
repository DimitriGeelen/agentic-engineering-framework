<!-- reviewer: x-ai/grok-4.7 via OpenRouter; tokens in 2772 out 7439; cost 0.04845 -->

RECOMMENDATION: B — Route on stable function names; keep instance ids inside unless the sender explicitly demands one live instance.

SCORES:

| Driver (weight) | A | B | C | D |
|---|---|---|---|---|
| D1 (9) | −2 | +1 | −1 | −1 |
| D2 (7) | −2 | +1 | −1 | −1 |
| D3 (5) | −2 | +1 | 0 | 0 |
| D4 (3) | −2 | +1 | −1 | 0 |
| F-AUTONOMY (4) | −1 | +1 | −1 | 0 |
| F-RECALL (6) | −2 | +1 | −2 | −1 |
| F2 (6) | −1 | +2 | −1 | 0 |
| **Total** | **−70** | **+46** | **−41** | **−22** |

Dropped: F1 (Context Fabric) — this choice does not store, search, or structure memory; it only names where a message is matched. F3 (Prompt quality) — envelope labels are not prompt-writing work.

PER OPTION:

A — Steelman: If both names are routing keys, a sender can pin host, hub, checkout, session, and agent instance with no side channel and no special flag. Match failure is then a real mismatch, not a guess, and the audit trail is the address itself. For a fleet that already respawns and rotates certificates, putting the live id on the envelope is the only way to prove which process was meant.

A — Strawman: “More fields, more truth.” That collapses if every field must match. The sample address dies on DHCP, cert rotation, checkout rename, and agent restart, and it puts the IP on the route after 7/7 vendors said never. Precision that cannot survive the next restart is not precision; it is a filter that drops mail.

B — Steelman: The envelope should name the role that stays true — host, a stable hub name, `pid-…`, agent function — and carry fingerprints, IPs, checkouts, leases, and instance ids as metadata. That matches the vendor split: two names at the agent, project identity is only `pid`, checkout and session name are not default routes, IP stays off the address, hub gets a stable name plus an instance id. A sender who truly needs one process sets `exact-instance` and adds `session` / `inst`. Cert rotation and respawn then change metadata, not the route, and inbox topics can stay findable. Several hubs per host, which the operator already expects, are why a stable hub name cannot wait.

B — Strawman: “Names good, ids bad, add a flag.” That slogan hides the real work. Two hubs can both be called `main`. A function route with three live `@research` processes is either a fan-out, a lottery, or an error, and the slogan does not say which. `exact-instance` is a second protocol; if a sidecar ignores the flag, mail hits the wrong process and looks delivered. B is right only if those rules are loud and owned, not if the flag is a vibe.

C — Steelman: Do not invent a hub namespace TermLink has not built. Today the hub id is the TLS fingerprint, it already keys `inbox:<hub>/<project>`, and it is unique. Keep B’s discipline everywhere else — no IP, project is `pid`, agent function on the envelope — and let the fingerprint remain the hub route until multi-hub naming is real. Google and xAI wanted one hub label until that decision; C is that caution, shipped.

C — Strawman: “Minimal” here means ratifying the bug. The fingerprint changes on certificate rotation and it is the name of every durable inbox. Uniqueness today is not stability tomorrow. C looks short in the sample and still breaks recall, topology, and unattended delivery on the next cert. Shipping the rotating key as the contract is worse than having no new contract.

D — Steelman: Name-to-id resolution is IW-3, and TermLink is the component that will actually resolve it. Hub naming was only 5/7, with two vendors saying wait. A partial AEF ruling that assumes a stable hub name can box the implementer in. Defer the envelope split until the hub’s view arrives, and do not pretend consensus on the agent and project levels forces a hub-name design this week.

D — Strawman: Treat an open sub-question as a reason to decide nothing. IP-off-envelope, `pid`-only project routing, and “checkout is not a route” are already 6/7 or 7/7. Waiting does not freeze the fingerprint in a new ruling, but it does leave rotating inbox keys in production and calls that prudence. Defer is how a settled split dies in a queue.

WHERE THE AGENT'S SCORING IS WRONG:

- D1 / B: +2 is too high. Stable routes survive stress; that is robustness. Antifragility needs the failure to become learning. Metadata could do that, but B does not yet say how a missed instance is recorded and reused. +1.
- D2 / B: +2 assumes no silent failures. Function-route ambiguity and a dropped `exact-instance` flag are silent-failure designs until specified. +1, not a clean bill.
- D1 / A: −1 is soft. If both labels must match, cert rotation, DHCP, and restart are routing outages, not minor friction. −2.
- D2 / A: −1 understates inbox rename and match-on-dead-id as silent loss. −2.
- D3 / A: 0 is wrong. The sample address is hostile to send, read, and debug. −2.
- D4 / A: −1 is soft. IP plus TLS fingerprint is environment lock-in. −2.
- F-AUTONOMY / A: +1 is backwards. Unattended senders would have to know live instance ids for every hop. −1.
- D1 / C: +1 is the worst cell in the table. The stress case is cert rotation, and C routes on the value that rotation changes. −1.
- D2 / C: +1 ignores that `inbox:<fingerprint>/<project>` is renamed out from under durable mail. −1.
- D3 / C: +1 confuses “shorter than A” with usable. A hex fingerprint is not an actionable name. 0.
- D4 / C: +1 is sign-flipped. A TLS fingerprint as the route is certificate-implementation lock-in. −1.
- F-AUTONOMY / C: 0 misses the human rebind after every rotation. −1.
- D1 / D: 0 treats defer as neutral. Leaving fingerprint-named inboxes in place keeps a known fragility. −1. D2 at −1 is fair.
- Dropped F-RECALL: wrong. The hub label is the key of durable inbox topics. Future sessions either find `inbox:<stable>/<pid>` or rediscover a dead fingerprint. That is recall leverage.
- Dropped F2: wrong. This is the topology identity decision — what counts as the same hub or agent versus drift. Component fabric will key off whatever you put on the envelope.
- Ranking: C at +24 above D at −7 inverts the choice. Adopting the rotating key as policy is worse than not ruling yet. On these scores D (−22) beats C (−41); both lose to B. The agent scored “not A” as health and never scored the fingerprint fact against C.

WHAT A RULING FOR YOUR RECOMMENDATION MUST STILL SETTLE:

- Stable hub name: who assigns it, uniqueness scope (host vs estate), and collision rules. State that several hubs per host are already expected, so the Google/xAI “one label until multi-hub” hold is closed.
- Cutover of existing `inbox:<fingerprint>/<project>` topics to the stable name without stranding queued mail, and a read rule for old fingerprints during rotation.
- Function-route cardinality: if several live agents share `@research`, the hub must fan-out, pick by a stated rule, or reject. Ambiguous deliver is forbidden.
- `exact-instance` miss: hard fail, no silent fallback to another instance, and no implied respawn — that stays decision 2b.
- The matrix in one place: IP display-only; checkout, session name, model/vendor, lease, and hub fingerprint inside; session and `inst` on the envelope only with `exact-instance`. TermLink still owns the resolver (IW-3); this ruling sets the contract, it does not defer the split.
