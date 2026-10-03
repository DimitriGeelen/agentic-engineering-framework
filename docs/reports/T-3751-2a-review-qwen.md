<!-- reviewer: qwen/qwen3.8-max-prime via OpenRouter; tokens in 1653 out 14516; cost 0.180804 -->

RECOMMENDATION: B — Route on stable function labels; keep instance ids as metadata, with a strict exact-instance exception and a fingerprint-to-stable-name migration rule.

SCORES:

| Driver (weight) | A | B | C | D |
|---|---:|---:|---:|---:|
| D1 Antifragility (9) | −2 | +1 | 0 | 0 |
| D2 Reliability (7) | −2 | +1 | 0 | −1 |
| D3 Usability (5) | −1 | +2 | −1 | −1 |
| D4 Portability (3) | −1 | +1 | 0 | 0 |
| F-RECALL Recall Leverage (6) | −1 | +1 | −1 | 0 |
| F-AUTONOMY Autonomy (4) | −1 | +1 | 0 | −1 |
| F2 Component Fabric (6) | −2 | +2 | −1 | −1 |
| F1 Context Fabric (7) | dropped | dropped | dropped | dropped |
| F3 Prompt quality (7) | dropped | dropped | dropped | dropped |
| **Weighted total** | **−62** | **+51** | **−17** | **−22** |

Dropped drivers:
- F1 Context Fabric: this decision changes routing identity, not memory storage/search architecture directly.
- F3 Prompt quality: envelope routing does not materially change prompt design or prompt-quality work.

PER OPTION:

**A — both labels at every level route.**  
Steelman: Every possible identity is visible on the envelope, so routers, auditors, and replay tools can see exactly why a message went where it did. In a messy multi-hub, multi-session estate, that full fidelity can prevent ambiguous delivery and make incidents easier to reconstruct.  
Strawman: It turns every transient fact—IP, checkout, session, certificate fingerprint—into a routing key. A DHCP lease, certificate rotation, or restarted session then breaks delivery even though the intended agent function has not changed. It also ignores the review consensus that IP, checkout, and session should not be routable.

**B — function names route; instance ids ride inside.**  
Steelman: B routes the stable intent: host, hub role, project `pid`, and agent function. Instance facts remain metadata, so normal restarts, certificate rotation, and clone churn do not change the address. The `exact-instance` escape hatch preserves precise delivery when genuinely required.  
Strawman: B assumes TermLink will provide stable hub names and a safe resolution path, which may not exist yet. If `exact-instance` becomes a common habit, it recreates A’s brittleness with extra steps. Migration of existing fingerprint-named inboxes could be hand-waved.

**C — minimal, but hub routes by fingerprint.**  
Steelman: C ships the non-controversial cleanup now: no IP, `pid` as the only project routing identity, and no checkout/session routing. It uses the hub identity that already exists, so there is no dependency on an unproven naming service. It is the fastest way to reduce envelope complexity.  
Strawman: It makes a TLS fingerprint a durable routing name. Certificates rotate, so the hub address and durable inbox topics change under users. With several hubs per host, fingerprint labels are also unusable for humans and weak for topology.

**D — defer until TermLink’s IW-3 view arrives.**  
Steelman: The hardest part of B is hub name-to-id resolution, and TermLink owns that. Waiting avoids standardizing an envelope that may need immediate rework. If TermLink’s model differs, delay saves a painful migration.  
Strawman: Most of the decision is already settled by the review: IP, checkout, and session should not route. Deferring everything leaves the estate on volatile fingerprint routing and blocks autonomous progress while waiting for one external input.

WHERE THE AGENT'S SCORING IS WRONG:

- **D1 / A:** −1 is too mild. A routes volatile IP, checkout, session, and fingerprint labels; ordinary churn becomes routing failure, so it should be −2.
- **D3 / A:** 0 ignores that the address is long, noisy, and hard to debug. It invites copy-paste of transient ids and accidental routing dependencies.
- **F-AUTONOMY / A:** +1 is backwards. Requiring every exact instance on the envelope makes unattended operation harder, not easier, because automation must track ephemeral identities.
- **D1 / B and D2 / B:** +2 is premature. Until stable hub-name assignment, resolution failure modes, and fingerprint-topic migration are ruled, B is safer but not yet fully robust; +1 is more honest.
- **D2 / C:** +1 is wrong. Fingerprint rotation makes routes and durable inbox topics unpredictable; at best this is neutral, and it becomes negative when rotation happens.
- **D3 / C and D4 / C:** +1 is too generous. A rotating hex fingerprint is not user-friendly, and it ties routing to local certificate state rather than portable logical names.
- **F-RECALL / all:** dropped incorrectly. Routing labels become durable retrieval keys for messages and inboxes. Volatile labels harm future recall; stable labels help it.
- **F2 / all:** dropped incorrectly. Envelope labels define component identity, dependency maps, and blast radius. A creates ephemeral topology nodes; B stabilizes them; C causes hub-node churn.
- **F-AUTONOMY / D:** 0 is too kind. Deferral keeps a human checkpoint open and leaves volatile routing in place, which hurts unattended operation.

WHAT A RULING FOR YOUR RECOMMENDATION MUST STILL SETTLE:

- TermLink must define stable hub function names, uniqueness across hubs/hosts, and how hub instance ids/fingerprints are bound and rotated.
- The migration path for existing `inbox:<hub>/<project>` topics must be explicit: aliases, rewriting, backward compatibility, and retention during fingerprint rotation.
- `exact-instance` policy must define when session/agent instance labels may route, required metadata, TTL/lease, and failure behavior, without implying agent respawn.
- The ruling must classify each label as envelope-routable, inside metadata, or display-only: IP, hub fingerprint, checkout, session, model/vendor, lease, and project boundary must be unambiguous.
- Clones and sessions must be handled: two clones share one `pid`, session/checkout names remain non-routable by default, and display syntax must not accidentally create routing equivalence.
