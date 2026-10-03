<!-- reviewer: deepseek/deepseek-v4-pro-0813 via OpenRouter; tokens in 3783 out 3748; cost 0.01627122 -->

VERDICT: ADOPT-WITH-CHANGES — the diagnosis is right, but the proposal conflates *identity* with *delivery policy*; separate them before implementing.

Q1. **Two-label model: right diagnosis, incomplete fix.**  
The core insight — every level needs both a stable *function* name and a dynamic *instance* identity — is correct and directly addresses the §3 pattern ("true at one level, false at the level the sender cares about"). But the table as proposed has holes:

- **Agent level:** you need *three* things, not two: the function name (`research`), the instance id (transient), and a **disambiguation key** when two `research` agents exist (see Q5). The instance id *is* the disambiguator, but the proposal doesn't say how a sender *chooses* between two live instances, or whether a new instance replaces or joins the old. This is the exactly-once problem sharpened.
- **Session level:** a "session name" is not a function. It's a *receptacle identity* at best; sessions don't have roles, they have *continuity*. Calling it a function label invites respawn-by-function logic on something that isn't a function. Keep session *instance* id, give it a session *channel name* if you need display, but don't call it function.
- **Project level:** the project *instance id* is real and overdue — §2's "passive" project was exactly the fiction that broke down when ready-flags and inbox topics lived at project scope but meant session scope (§3, incident 4). But a "project instance" on disk isn't a running thing. Clarify: is it a checkout identity? A working-copy id? A git worktree? Otherwise "respawn a project instance" (4.2) is undefined.
- **Missing: a vendor/model label at agent level.** §5 requires cross-vendor portability. `research` under Claude and `research` under Codex are not the same function; a function label alone is not enough to respawn "the same" agent. Add an explicit *implementation* or *model* slot (metadata, not routing — but required for respawn authorization).

Bottom line: keep both labels at host, hub, agent. At project and session, keep instance ids but drop the pretense of function labels; add a model label at agent level.

Q2. **Routing vs display: route by instance, fall back by function, display everything.**  
The wire address used for delivery should carry *instance* identity wherever possible, because instance identity is what makes delivery unambiguous (§2 D1). Function labels belong in *two* places: (a) metadata in the envelope, so the receiver can decide what to do when the instance is gone; (b) display, so the human can read it. That yields:

- **Host:** FQDN for routing; IP for resolution only (Q5 tension 5 — you're right, IP is never a routable address at wire level for an app protocol; drop it from the wire, keep it in resolution logs).
- **Hub:** hub id on the wire (unambiguous); hub name in metadata/display.
- **Project:** `pid-…` on the wire (already decided in §2); project instance id in metadata, so the receiver can detect "the checkout that answered is not the checkout I asked."
- **Session:** session instance id on the wire; no function name.
- **Agent:** agent name *plus* instance id on the wire for direct delivery; function name alone in metadata for respawn.

Why not put function labels on the wire? Because every time you route on a function label, you are *choosing* among instances, and that choice is exactly the policy question Q5 is about. Route on instance; fall back on function *only* via an explicit policy step, never implicitly.

Q3. **Fallback order and stop rule: climb by availability, but return a receipt that names the true hand-off level.**  
The rat's nest in §3 is receipts that lie about the level. The algorithm must make the *receipt* the output of every step, not an afterthought. Proposal:

1. **Resolve full address** (host, hub, project, session, agent instance). Try direct receiver (sidecar). If reachable and ack returned → **DELIVERED-TO-AGENT(instance)**. Stop.
2. **If agent instance dead / receiver unreachable**, do not immediately climb. First try *same project, same agent function, different instance* (if one is live and claims the function). If found → **DELIVERED-TO-AGENT(function, new instance)**, with a note "resolved by function, not instance." Stop. (This is the new step the proposal implies but doesn't spell out.)
3. **If no live agent with that function in that project**, try *same project, same session* (hub inbox topic for that session, if sessions have inboxes). If accepted → **HUB-ACCEPTED-FOR-SESSION(session id)**. This is not "delivered"; the receipt must say hub-accepted. This is where §3 incidents 1 and 3 happened — the receipt lied.
4. **If no session, same project** (project inbox). → **HUB-ACCEPTED-FOR-PROJECT(pid)**. This is the floor for same-project fallback. §4.3 says never cross projects; agree, hard stop here.
5. **If project level unresolved** (e.g. pid unknown, project never registered), return **RESOLUTION-FAILURE**, not silent queueing. This is the new stop rule that §3 incident 6 (258 posts, one receipt) needed and didn't have.
6. **Respawn decision is NOT part of delivery fallback.** It is a *separate* step, authorized before or after delivery, but not triggered implicitly by step 5. Reason: respawn is a Tier-0/Tier-3 cost and authority question (Q4), not a routing question.

Sender sees at each step: a distinct receipt state, with the level that accepted, and a monotonically increasing "escalation" counter. No state is ever named "delivered" unless the agent instance (or a live replacement instance) positively acked.

Q4. **Respawn safety: require separate authorization; never trigger on inbound message alone.**  
The proposal's roughest edge. "Spin up a new `research` agent" on any inbound message is an open wallet and a spam amplifier. Rules:

- **Never respawn on an arbitrary peer message.** Respawn requires one of: (a) explicit human authorization (operator, §5 "one human operator"), (b) a pre-authorized policy scoped to a *specific function and project* with a spending cap, or (c) the message carrying a valid delegation token from the project's sovereign (human) — e.g. a scheduled task the human already approved.
- **Who pays:** the project's budget, not the framework's, not the sender's. If the project has no budget line for respawn, bounce with **RESPAWN-UNAUTHORIZED**, which is not a failure — it's a correct refusal. The sender can escalate to the human.
- **Rate limits:** per (project, function) pair: max N respawns per hour, M per day; exponential backoff on repeated bounce for the same function. After limit, messages queue at project level (§3 incident 6 pattern: queue must have a reader, or don't queue).
- **Malicious or mistaken message:** a message addressed to `research` when the sender meant `researcher` is a *misrouting*, not a dead instance. The system must not respawn `research` to satisfy it. Distinguish "function name exists but no live instance" from "function name never existed in this project" — only the first is a respawn candidate, and only with authorization.
- **Context ingestion (§7.4) is a separate, hard problem.** "Ingest the context and follow up" is not a bootstrap; it's a *reconstruction*. The new instance needs: the saved context (where? which checkpoint?), the message thread (`--in-reply-to` chain), and the project state. Specify this before promising respawn. Otherwise the respawned agent is a fresh agent with an old name and no memory — worse than no agent, because it *looks* continuous.

Q5. **Exactly-once and conflicts: lease, don't elect.**  
Two live instances of one function are inevitable (two worktrees of one pid, a human terminal and a dispatched agent in the same project — exactly §3 incident 4). Solutions:

- **Per-function single-writer lease (§2 D7 already does this per project for writes).** Extend it: a function instance that wants to receive messages must hold the lease for (project, function). A second instance with the same function *must not receive* until the lease expires or is transferred explicitly. This is not an election; it's a lock, with a timeout and a clear ownership record.
- **Do not "deliver to both."** That turns a messaging system into a broadcast system by accident, and it's how §3 incident 4 happened (two sessions, one ready flag).
- **Lease holder publishes its instance id** in every receipt. The sender can see that the reply came from instance B, not instance A. If A comes back, it does not silently resume; it must reacquire the lease.
- **Project instance conflicts (two checkouts with the same pid on one host):** the project *instance id* is the disambiguator, not the pid. Pid identifies the *project function*; instance id identifies *this checkout*. Two checkouts with different instance ids can both be live; delivery to a project-level topic must name the instance id it means, or it goes to the project's *default* instance (a configured choice, not a guess).

Q6. **Lessons from §3: prevents most, leaves one gap, introduces one new risk.**  
- **Prevents:** incident 1 (receipts name the true level — no more silent hub-accepted-as-delivered); incident 2 (message id thread binding is orthogonal but the receipt ladder makes reply binding explicit); incident 3 (the notify sidecar receipting as delivered to a project with no wake consumer — project-level receipts now say project-level truth); incident 6 (old pickup queue had no stop rule — the new RESOLUTION-FAILURE/RESPAWN-UNAUTHORIZED stops orphan queues); incident 8 (orphans — instance ids include liveness, dead entries age out).
- **Leaves open:** incident 4 (per-session ready flag) is already fixed per the brief; remains fixed, but the model doesn't help beyond that. Incident 5 (shared signing identity) is TermLink's problem; the model works around it but doesn't fix it. Incident 7 (push vs inject) remains a transport choice, not an address problem.
- **Introduces a new class:** *false respawn*. A dead instance, plus a stale lease, plus an authorization rule that's too broad, plus a message that's only slightly misaddressed, yields a new agent started for no good reason, costing money and creating a second, younger instance that competes with the original when it comes back. This is the same "true at one level, false at the level you cared about" failure, now at the *lifecycle* level. The receipt says "DELIVERED-TO-AGENT(respawned)", the human finds two agents named `research` and neither has the full context.

Q7. **Prior art.**  
- **Erlang/OTP registered names and supervision:** the right model for *function name vs pid*. Erlang separates a registered name (function) from the pid (instance), and supervision restarts children *by policy, not by message arrival*. Copy: explicit registered name, explicit supervisor with restart policy. Avoid: Erlang restarts on crash, not on inbound message — don't let address resolution do supervision.
- **Akka/Orleans virtual actors:** Orleans "activates on demand" is tempting and is exactly the wrong model here — activation on message is a cost-and-abuse vector (Q4). Akka's actor paths are instance-first, with names only as a convenience; copy that priority.
- **DNS + service discovery:** copy the SRV-like separation of *service name* (function) from *endpoint* (instance), and the TTL/liveness from records; avoid DNS's habit of silently returning stale records (this is §3 incident 8).
- **SIP/XMPP addressing:** SIP's use of `alice@example.com` (function at host) with registration binding to an instance is close to the proposal, and its *provisional vs final* receipt distinction is precisely the ladder in Q3.
- **Email MX fallback:** avoid. MX queues quietly for days with bounces only at the end; that's the §3 pattern (silent hub accepted, no reader) institutionalized. If you take anything, take the *bounce* message, not the queue.

Q8. **Recommendation: adopt with changes.**  
Adopt the two-label model at host, hub, agent; drop function labels at project/session; add model label at agent; route by instance, fall back by function *only with receipts that say the true level*; and — the single most important reason — **remove respawn from the delivery path entirely.** Respawn is a lifecycle policy decision, not a routing decision. If it rides on the address system, you will respawn on misrouted messages, on orphan lookups, on stale leases, on every edge case in §3, and each respawn costs real money and creates a new instance that looks like the old one but isn't. Separate "where do I deliver" (this design, done well) from "when do I recreate" (needs its own authorization, budgets, and context-reconstruction design). Do that, and the address model itself is sound.

TOP 3 RISKS:

1. **Respawn-on-message opens a paid-model abuse vector.** Scenario: any peer sends `research` a message; `research` is dead; the address layer, under the proposal's 4.2 as written, spins up a new paid Claude instance to read it. A mistaken or malicious peer repeats this every hour; rate limit is never reached because each respawn is "legitimate" from the system's view. Operator sees the bill at month-end. Fix: Q4 authorization out-of-band.

2. **The "respawned equivalent" is not equivalent.** Scenario: `research` was working on a 2-hour context thread stored in its session. It dies. The respawned `research` ingests the *message* but not the 2-hour thread, then answers the sender in a way that contradicts prior work. The sender, seeing a reply from `research`, assumes continuity. The contradiction propagates downstream. Fix: respawn requires context-reconstruction spec (§7.4) *before* it can claim function continuity, and receivers must mark replies as "from a new instance, context partial."

3. **Two instances of one function, both thinking they're the one.** Scenario: agent `research` is respawned (instance B) while original (instance A) is still running but unreachable for one tick. A's network returns; both hold "research." A lease exists but isn't enforced; B sends a reply, A sends a different reply to the same `--in-reply-to`. Sender marks first reply as REPLIED, second is orphaned; the two `research` instances now diverge on the same conversation. §3 incident 4, replayed at agent level. Fix: single-writer lease (§2 D7 extended) enforced on the receive side, lease owner id in every receipt.

WHERE I DISAGREE WITH THE AGENT'S READING (§4.3, §7):

- §4.3 "Point 4.2 is ratified D1 + D5 applied" — **disagree.** D5 pre-authorizes re-provisioning a missing *child* (infrastructure self-heal), not spending money to start a paid model on an arbitrary peer message. Conflating infrastructure provisioning with agent respawn hides a Tier-0 cost decision inside a Tier-3 self-heal. Keep them separate.
- §4.3 "project gains an instance id and stops being purely passive" — **partially agree.** Project does need an instance id (the checkout), but that doesn't make the *address slot* active. A location with an instance identity is still a location; don't route to it as if it could respond.
- §7.1 "is a session name a real role" — **disagree with framing.** The agent sees a choice between "real role" and "just a label." It's neither; it's a *continuity handle*. Give sessions a name only for display and session-to-session routing, never for function-based fallback.
- §7.2 "respawn authority" — the agent lists it as a tension. I'd elevate it: it's the primary design constraint, not a secondary tension. Everything else follows from where respawn lives in the architecture.
- §7.4 "is the conversation thread enough" — the agent asks; the answer is **no**, and this alone blocks adoption of respawn-by-function until answered.
- §7.5 "is IP ever needed" — the agent is right to doubt it; drop it from the wire address, keep it in resolution metadata.
