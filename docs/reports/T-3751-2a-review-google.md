RECOMMENDATION: B — Route on logical function names and project ID; carry dynamic instance qualifiers inside as metadata.

SCORES:

| Driver (weight) | A | B | C | D |
|---|---|---|---|---|
| D1 (9) | −2 | +1 | −1 | 0 |
| D2 (7) | −2 | +1 | −2 | 0 |
| D3 (5) | −2 | +2 | 0 | −1 |
| D4 (3) | −2 | +1 | 0 | 0 |
| F-AUTONOMY (4) | −2 | +2 | 0 | −1 |
| F2 (6) | −2 | +2 | −1 | 0 |
| **Total (with F2)** | **−68** | **+49** | **−29** | **−9** |
| *(Subtotal without F2)* | *(−56)* | *(+37)* | *(−23)* | *(−9)* |

Dropped drivers and why:
- **F-RECALL (6):** Dropped; envelope addressing syntax does not alter the storage, indexing, or retrieval of historical project learnings.
- **F1 (7):** Dropped; routing headers define transit endpoints, not the memory models of working, episodic, or project context.
- **F3 (7):** Dropped; message delivery mechanics do not directly impact LLM prompt synthesis, reasoning quality, or context curation.
- *(Note on F2: The agent dropped F2, but envelope routing directly establishes the messaging topology, boundary isolation, and drift surface; it is restored above.)*

---

PER OPTION:

### Option A — Both labels at every level route
- **Steelman:** In an estate running concurrent sessions, multiple checkouts, and ephemeral container IPs, unambiguous point-to-point delivery demands exact physical coordination on the wire. Placing host, IP, hub fingerprint, checkout ID, session ID, and agent instance directly on the envelope guarantees deterministic targeting without relying on directory synchronization or late-binding proxies. When an operator needs to isolate and trace a specific misbehaving subagent on a specific checkout, full-coordinate routing prevents accidental crosstalk.
- **Strawman:** If we do not stamp every IP address, git checkout number, session identifier, and process instance onto the envelope, messages might get confused about which terminal window is open. This treats transient runtime execution context as immutable network topology, shattering delivery every time DHCP renews, a container hops interfaces, or an agent restarts. It forces senders to micromanage physical state they should never need to know.

### Option B — Function names route; instance ids ride inside
- **Steelman:** Decoupling stable functional roles (`host/hub/project/@role`) from transient execution instances is the cornerstone of resilient distributed routing. Senders address the capability they require, allowing messages to survive agent respawns, session cycling, and host IP churn, while senders requiring point-to-point session pinning can still opt into explicit instance matching via payload metadata. This aligns with the unanimous 7-vendor consensus, isolates routing from cryptographic certificate rotation, and establishes a durable architectural boundary for the estate.
- **Strawman:** Let us assume TermLink will immediately build a naming directory for stable hub names, and pretend routing to `@research` always delivers correctly even when duplicate checkouts run identical roles. It claims antifragility by declaring that all hard problems—like instance collision, leader election, and unbuilt hub registries—can simply be swept inside the message body.

### Option C — Minimal (hub keeps fingerprint as routing name)
- **Steelman:** Pragmatism requires shipping an address format that works with TermLink's existing infrastructure today rather than waiting on an unbuilt hub-naming specification. The TLS fingerprint is an immutable, cryptographically verifiable identifier that already indexes active hubs and durable inbox topics on the host. It captures 90% of Option B's logical decoupling for projects and agents without incurring external architectural dependencies or cross-team delays.
- **Strawman:** Let us hardcode ephemeral TLS certificate fingerprints into durable envelope addresses and persistent queue topics because writing a configuration string is inconvenient. The first time a certificate rotates for standard operational hygiene, every durable inbox topic is orphaned, stored routing tables break, and cross-agent communication drops silently. It trades basic operational stability to avoid a single naming agreement with TermLink.

### Option D — Defer until TermLink sends view on name→id resolution
- **Steelman:** Address envelope formatting is a shared wire contract between AEF and TermLink; unilaterally formalizing envelope syntax before TermLink publishes its IW-3 resolution architecture risks building against an incompatible model. If TermLink's resolution semantics diverge from AEF's assumptions regarding hub and agent resolution, AEF will be forced into an immediate breaking protocol migration. Waiting for the IW-3 response guarantees architectural alignment across the estate.
- **Strawman:** We cannot decide how our own agents address one another until an external subsystem tells us what it thinks about name resolution. This surrenders AEF's architectural initiative and halts multi-agent collaboration despite 7 out of 7 external reviewers already agreeing on the exact envelope boundary. It uses dependency coordination as a pretext for decision paralysis.

---

WHERE THE AGENT'S SCORING IS WRONG:

- **D2 (Reliability) & D1 (Antifragility) on Option C (Agent scored +1, +1; Actual: −2, −1):** The agent overlooked the operational reality that today's hub ID is a TLS fingerprint that changes on certificate rotation. Because durable inboxes are named `inbox:<hub>/<project>`, cert rotation permanently orphans inboxes and drops in-flight messages. Awarding positive reliability and antifragility to an option with a guaranteed message-loss failure mode upon routine cert renewal is a major analytical error.
- **F-AUTONOMY on Option A (Agent scored +1; Actual: −2):** The agent gave Option A a positive score for autonomy. Embedding ephemeral attributes (IP, checkout ID, session ID, instance ID) in the envelope means that whenever an agent crashes, restarts, or migrates, peer routing breaks immediately. Unattended workflows collapse because senders cannot self-heal without external discovery mechanisms to locate the new physical coordinates.
- **D3 (Usability) on Option A (Agent scored 0; Actual: −2):** The agent treated Option A as neutral. Forcing developers and agents to construct, read, and debug 6-tuple addresses packed with 16-character hashes, ephemeral IPs, checkout tags, and session numbers creates extreme cognitive overhead and pollutes diagnostic logs.
- **D1 (Antifragility) & D2 (Reliability) on Option B (Agent scored +2, +2; Actual: +1, +1):** The agent assigned top marks to Option B while ignoring that it explicitly carries an external dependency ("Needs: TermLink gives each hub a stable name"). Furthermore, routing to functional roles without a defined multi-instance resolution policy invites delivery ambiguity. Decoupling provides baseline fault tolerance (+1), but it does not magically turn stress into learning (+2).
- **F2 (Component Fabric) dropped across all options (Agent dropped; Actual: touches all):** The agent dropped F2 claiming it was untouched. Address schemas establish the messaging topology, boundary isolation, and blast radius of the system. Dropping F2 obscured Option A's severe topology drift (−2), Option C's coupling of system topology to crypto keys (−1), and Option B's clean definition of logical architectural boundaries (+2).
- **D2 (Reliability) & D3 (Usability) on Option D (Agent scored −1, 0; Actual: 0, −1):** Deferring maintains the current baseline without introducing new protocol failure modes (D2: 0). What deferral actually damages is usability and developer momentum (D3: −1), leaving agent developers stalled in design uncertainty.

---

WHAT A RULING FOR YOUR RECOMMENDATION MUST STILL SETTLE:

- **TermLink Hub Naming Contract:** The formal mechanism by which TermLink assigns, discovers, and persists human-readable hub names (`hub=main`), including how the runtime maps legacy TLS fingerprints to logical hub names during migration.
- **Multi-Instance Delivery Semantics:** The routing policy when multiple agent instances advertise the identical role on the same project (e.g., two concurrent checkouts running `@research`): round-robin, newest-lease priority, broadcast, or hard rejection when `exact-instance` is omitted.
- **Stale Instance & Dead-Letter Handling:** The exact failure contract when a message with `exact-instance` targets an expired or dead session/instance ID (e.g., synchronous NACK, dead-letter queuing, or automatic fallback to any live functional role instance).
- **Metadata Envelope & Wire Specification:** The precise schema distinguishing the outer routing envelope from internal message headers (IP, checkout ID, TLS fingerprint, lease duration, vendor/model).
- **Same-Host Clone Disambiguation:** How sidecars isolate traffic between two local checkouts sharing the same `pid` when messages do not specify an explicit checkout qualifier in metadata.
