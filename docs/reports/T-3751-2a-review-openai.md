RECOMMENDATION: B — Route ordinary messages by stable logical identity, with explicit rules for ambiguity and a separate, strict exact-instance mode.

SCORES:

| Driver (weight) | A | B | C | D |
|---|---:|---:|---:|---:|
| D1 (9) | 0 | 0 | 0 | 0 |
| D2 (7) | 0 | +1 | −1 | 0 |
| D3 (5) | −2 | +1 | +1 | −1 |
| D4 (3) | −1 | 0 | 0 | 0 |
| F-AUTONOMY (4) | −1 | +1 | 0 | −1 |
| F2 (6) | −1 | +1 | −1 | 0 |
| **Total** | **−23** | **+22** | **−8** | **−9** |

These scores assess the options as described, without assuming a resolver, migration mechanism, or failure policy already exists.

D1 remains neutral throughout: handling churn is reliability; none of these options specifies how failures produce learning or strengthen the system.

Dropped drivers:

- **F-RECALL:** Stable addresses could help link records, but this decision specifies no durable knowledge capture or retrieval.
- **F1:** No change to working, project, or episodic memory, or semantic search is proposed.
- **F3:** Envelope addressing does not directly change prompt quality.

F2 stays: deciding which labels identify components directly affects topology continuity and whether certificate rotation looks like component replacement.

PER OPTION:

**A — Steelman:** Every delivery constraint is explicit, allowing the receiver to reject messages whose intended environment or execution instance no longer matches. Its advocate can reasonably prefer visible delivery failure over accidentally sending work to a replacement agent, especially for messages tied to a particular execution.

**Strawman:** “More address fields mean more precision, so making every field route must be safer.” That confuses identifying a logical recipient with pinning every detail of its current deployment: IP changes, checkout changes, and certificate rotation can invalidate an otherwise valid destination. It also contradicts the agreed exclusions of IP and checkout from routing.

**B — Steelman:** Most messages target a continuing responsibility within a project, so the routing identity should survive replacement of the process or credentials serving it. B preserves that continuity while offering an explicit way to target one execution when necessary. It also accommodates multiple hubs per host without making certificate rotation rename a durable inbox.

**Strawman:** “Just send to `@research`; the resolver will know what you mean.” A role name cannot decide between two eligible agents or determine whether a stale registration still owns the role. Without explicit selection and failure rules, simplicity for senders becomes hidden ambiguity in delivery.

**C — Steelman:** C keeps most of B’s simplification while retaining the hub identity already used by the implementation and durable inbox topics. Its advocate can reasonably argue that stable hub naming introduces allocation, persistence, and migration work before TermLink has supplied its resolution design. It is the smallest immediate change among the substantive simplification options.

**Strawman:** “The fingerprint is already unique, therefore it is a sufficient permanent hub name.” Uniqueness does not provide continuity: rotating a certificate changes both the routing identity and inbox namespace. Calling this minimal counts initial implementation effort while ignoring recurring migration work.

**D — Steelman:** Routing semantics span AEF and TermLink, so waiting for the owner of name-to-id resolution could prevent incompatible assumptions from becoming a contract. A bounded pause with a precise question and deadline can be cheaper than deploying an address model that the messaging layer cannot support.

**Strawman:** “We cannot decide anything until TermLink replies.” The brief already supplies enough evidence to reject IP and checkout routing and identify the fingerprint’s lifecycle problem. An indefinite pause leaves those problems in place without guaranteeing useful new information.

WHERE THE AGENT'S SCORING IS WRONG:

- **D1 + B/C:** The +2/+1 awards confuse resilience with antifragility. Neither option introduces failure learning, and C retains a known source of identity churn.
- **D1 + A:** A may be brittle, but its weaknesses are directly supported under reliability and usability. A separate antifragility penalty needs an argument about learning or strengthening that the brief does not provide.
- **D2 + A:** −1 overlooks its strongest benefit: exact constraints can prevent delivery to an unintended replacement. Its stale-address risks and fail-closed benefits justify a mixed score, pending failure semantics.
- **D2 + B:** +2 assumes too much. Stable names help, but duplicate role registrations, expired leases, and exact-instance fallback remain unspecified; +1 is defensible.
- **D2 + C:** +1 understates the stated certificate-rotation problem. An identity that renames durable inbox topics on credential rotation is a concrete continuity liability.
- **D2 + D:** −1 treats waiting itself as unreliable. The brief gives no deadline or current delivery failure caused by waiting; its clearer costs are usability and autonomy.
- **D3 + A:** Zero ignores the burden of constructing, inspecting, and refreshing five levels of dual routing labels. The ordinary case becomes unnecessarily demanding.
- **D4 + B/C:** +1 lacks evidence of reduced provider, language, or environment lock-in. A stable hub name is useful, but naming flexibility alone does not establish portability.
- **F-AUTONOMY + A:** +1 assumes precision reduces intervention. Requiring senders to track volatile identities can instead create more stale destinations and repair work.
- **F-AUTONOMY + D:** Zero ignores the additional external checkpoint. As written, D provides neither a bounded wait nor a mechanical condition for proceeding.
- **F2 + A/B/C:** Dropping this driver misses the topology consequences. A makes transient checkout and instance details part of routing identity; C makes credentials determine hub identity; B supplies a more durable basis for identifying logical components.

WHAT A RULING FOR YOUR RECOMMENDATION MUST STILL SETTLE:

- **The canonical envelope:** Ordinary routing uses host, stable hub name, `pid`, and agent function. Specify each name’s scope and rename rules. Keep IP, fingerprint, checkout, model/vendor, and lease data as metadata; checkout and friendly session names may aid display but never become routing aliases.
- **Resolution and ambiguity:** Define registration authority, lease enforcement, and what happens when zero or multiple agents match a role. Preserve the absolute project boundary and return observable outcomes.
- **Exact-instance semantics:** Define whether the session ID is needed to scope the agent instance ID. A missing or stale exact target must produce an explicit outcome; it must never silently fall back to the role.
- **Hub continuity and migration:** Define how stable names persist across restarts and certificate rotation, how credentials authenticate those identities, and how existing fingerprint-keyed inboxes and queued messages transition.
- **The TermLink contract:** Confirm these semantics with TermLink through IW-3 before implementation is treated as interoperable. Keep agent respawning outside this ruling.