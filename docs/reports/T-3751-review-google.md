VERDICT: ADOPT-WITH-CHANGES — The model correctly identifies the need for a role-versus-instance split at the Agent level, but forces an artificial two-label symmetry onto lower infrastructure layers and couples it to an unconstrained auto-respawn mechanism that violates human sovereignty, risks runaway API spend, and introduces severe context-loss failure modes.

---

### Q1. Is the two-label (function + instance) model right?
**Position:** The two-label model is correct only at the Agent level; applying it uniformly across all five levels is an architectural category error that pollutes the address grammar with transport locators and artificial roles.

**Reasoning:**
- **Host (Drop Instance):** In §4.1, Host function is FQDN and instance is IP address. An IP address is an ephemeral network routing locator resolved via DNS, not an instance identity. Putting IP addresses into wire addresses violates transport independence, breaks when DHCP/VPN/NAT shifts, and duplicates standard socket resolution (`lib/aef_address.py:18`). Host identity should remain solely the Host FQDN/ID.
- **Hub (Merge):** Hub function is "hub name" and instance is "hub id" (§4.1). In TermLink, the hub is an infrastructure daemon singleton per host or per project (`circuit.py:24-32`). Senders never route to "any hub performing role X". The daemon instance generation belongs in connection handshakes and heartbeats, not in the logical wire address.
- **Project (Drop Instance):** Project function is `pid-...` and instance is "project instance id" (§4.1). A project is a passive filesystem repository and governance scope (D2, §2). An "instance" of a project is merely a filesystem working tree or checkout. Projects do not execute messages; sessions do. Inventing a "project instance" creates an ambiguous middle layer between the repository boundary (`pid`) and the execution container (Session).
- **Session (Drop Function):** Session function is "session name" and instance is "session instance id" (§4.1). Sessions are OS/PTY processes (`claude -p` under TermLink). A session has no abstract "functional role" distinct from the agent profile it hosts (§7 Tension 1). Giving a session a "function" duplicates the Agent role level. Session identity is strictly an instance locator (`session_id`).
- **Agent (Keep Both):** Function is `@role` (e.g., `@research`, `@reviewer`, `@maintainer`); Instance is `agent_instance_id` (ephemeral run/conversation ID). This split is genuinely necessary: it separates who does the job from the ephemeral process doing it right now.
- **What is missing:** 
  1. *Task/Thread binding (`T-XXX`)*: An agent instance without a task binding has no contextual scope.
  2. *Capability/Runtime constraints*: A function label `@research` does not specify whether the respawned worker requires a frontier model (`claude-3-7-sonnet`), high context, or specific sandbox permissions.

---

### Q2. Routing vs display
**Position:** Wire routing addresses must carry only durable logical identifiers and optional instance pins; transport locators belong to discovery, and human-friendly labels belong strictly to display and metadata.

**Reasoning:**
- **Wire Routing Address (Delivery Payload):**
  - *Durable Role Address:* `//host/hub/pid/@role` (routes to any live instance fulfilling `@role` in `pid`, or drops to project inbox).
  - *Circuit / Pinned Address:* `//host/hub/pid/session/@role#instance_id` (used when conversing with a specific running execution).
  - Project MUST always be the minted `pid-<16 hex>` (T-3751 IW-1, §2). Basenames like `999-AEF` must never appear on the wire because directory renames or multiple clones break delivery.
- **Metadata (Envelope Headers):**
  - `client_msg_id` and `in_reply_to` (mandatory to fix Incident 2, §3).
  - `task_id` (`T-XXX`) and conversation correlation thread.
  - `allow_respawn`: boolean flag controlled by sender/policy (§4.2).
  - Sender return circuit: `metadata.from_circuit` (`circuit.py:30`).
- **Display Only (UI / Logs / Human Output):**
  - Human directory basenames (`010-termlink`, `999-Agentic-Engineering-Framework`).
  - Host shortnames (`.107`).
  - Path elisions (`first/…/last`, `lib/aef_address.py:25-28`).
  - Network IPs.

---

### Q3. Fallback order and stop rule
**Position:** Fallback must proceed down a deterministic four-step hierarchy (Instance $\rightarrow$ Active Sibling $\rightarrow$ Project Inbox $\rightarrow$ Bounce), stopping strictly at project and host boundaries, with explicit receipts emitted at each transition.

**Reasoning:**
Given a target address `//host/hub/pid/session/@role#instance_id`:
1. **Step 1: Pinned Instance Check.** Probe the specified `session` and `instance_id`. If alive and ready-for-input (`R3/R5/T-3745`, §1.3, §3 Incident 4), inject message. Emit `DELIVERED_TO_INSTANCE`.
2. **Step 2: Active Sibling Session Lookup (Same Project).** If the pinned instance is dead: query TermLink for any other live session within the *same* `pid` actively claiming `@role`. If found and idle, route there. Emit `REROUTED_TO_ACTIVE_SIBLING`.
3. **Step 3: Project Inbox vs. Respawn Gate.** If no live instance of `@role` exists in `pid`:
   - Check message envelope `allow_respawn` and host project policy (`.framework.yaml`).
   - *If respawn is unauthorized or unbudgeted:* Post message to project durable topic `inbox:<hub>/<pid>` (`circuit.py:16`). Emit `QUEUED_PROJECT_INBOX` (fixing Incident 1: sender knows it is in cold storage, NOT delivered to an agent).
   - *If respawn is authorized:* Acquire project spawn lease, initiate session via `fw work-on` / `termlink dispatch`, wait for receiver ready handshake, and inject. Emit `RESPAWNED_AND_DELIVERED`.
4. **Step 4: Hard Stop Rules & Bounces:**
   - **Stop Rule 1 (Project Boundary):** Never route or fall back to a different `pid` (§4.3).
   - **Stop Rule 2 (Host Boundary):** Never route or fall back to another host.
   - **Stop Rule 3 (Inbox TTL):** If a message sits in `inbox:<hub>/<pid>` unread for > TTL (e.g., 2 hours), emit `EXPIRED_INBOX_UNREAD` back to sender.
- **Sender Visibility:** The sender must receive discrete, truthful state receipts: `RECEIVED` (transport ack) $\rightarrow$ `QUEUED_PROJECT_INBOX` | `RESPAWNING` $\rightarrow$ `DELIVERED_TO_INSTANCE` $\rightarrow$ `HANDED_OVER` (injected) $\rightarrow$ `REPLIED` (`in_reply_to` matched).

---

### Q4. Respawn safety
**Position:** Inbound messages must NEVER trigger an unauthenticated or unbudgeted agent respawn; automatic respawn must be strictly opt-in, bounded by human-allocated token/task budgets, and rate-limited.

**Reasoning:**
- **Authority Model (§1.1, §5):** "Human = sovereignty, framework = authority, agent = initiative." Spawning a Claude/LLM agent incurs real financial cost and executes code. Allowing an unverified peer on the hub to trigger `claude -p` turns inbound messaging into an unbounded Denial-of-Wallet and process fork-bomb vector (§7 Tension 2).
- **Authorization Rules:**
  1. *Default Closed:* Inbound messages default to `allow_respawn: false`. A dead agent results in `QUEUED_PROJECT_INBOX`.
  2. *Pre-Authorized Task Envelope:* Respawn is only permitted if the inbound message references an active, approved framework task (`T-XXX`) whose metadata explicitly designates an autonomous worker allocation.
  3. *Signed Capability Token:* Cross-project dispatches (e.g., Cockpit `055` triggering a worker in `832`) must present an operator-signed capability token.
- **Rate Limits & Circuit Breakers:**
  - Max 1 respawn per 15 minutes per correspondent.
  - Hard concurrency cap: max 2 active sessions per project checkout.
  - Crash-loop quarantine: If a respawned agent terminates within 60 seconds without emitting a heartbeat or reply, the `@role` endpoint is marked `FAULTED`, respawn is suppressed, and an operator alert is fired.

---

### Q5. Exactly-once and conflicts
**Position:** Two live instances of the same function must be disambiguated by task affinity or a single-writer lease; uncoordinated multi-instance broadcast is prohibited.

**Reasoning:**
- **Disambiguation by Conversation/Task:** If an incoming message contains an `in_reply_to` or `task_id`, it routes strictly to the instance that originated or owns that thread.
- **Single-Writer Claim (D7, §2):** If two live sessions claim `@research` within the same `pid`, the framework must enforce D7 single-writer mutual exclusion via `.context/locks/@role.lock`. Only the primary leaseholder receives inbound functional messages.
- **Multiple Repo Checkouts:** If two distinct directories share the same `pid-...` on one host (e.g., git worktrees or clones), routing to bare `pid` is ambiguous. The hub registry must require a workspace/directory discriminator during session registration. If ambiguous, reject the dispatch with `AMBIGUOUS_ROUTING_TARGET`.
- **No Broadcast Duplication:** Delivering a message to multiple instances of a function causes duplicate, divergent API calls and conflicting git operations.

---

### Q6. Lessons from §3
**Position:** The proposal prevents session-flag collisions (Incident 4) and signing identity collapse (Incident 5), but leaves topic receipt blackholes (Incident 1) and threading disconnects (Incident 2) unaddressed, while introducing a dangerous new failure class: "Respawned Context-Blindness".

**Reasoning:**
- **Incidents Prevented:**
  - *Incident 4 (Per-project ready flag collision):* Distinguishing session instances ensures ready flags are keyed strictly per session (`T-3745`).
  - *Incident 5 (Shared host identity):* Stamping explicit `@role#instance_id` on the wire prevents peer replies from collapsing to the shared TermLink host key.
- **Incidents Left Open:**
  - *Incident 1 (Receiver down $\rightarrow$ silent hub fallback):* Adding labels does not make `lib/sidecar/inbox.py` generate receipts. If the topic reader does not emit an ack back to the sender, the sender remains hung at `HUB_ACCEPTED` regardless of how well-labeled the address was.
  - *Incident 2 (Unbound replies):* Labeling addresses does not correlate replies to `client_msg_id`. Without strict message-id threading, nudging will continue indefinitely.
  - *Incident 3 (Delivered at hub $\neq$ delivered to agent):* "Delivered" at the hub remains a false indicator if no active consumer is attached.
- **New Failure Class Introduced:**
  - **"Respawned Context-Blindness" (True at Infrastructure Level, False at Semantic Level):** The framework reports `RESPAWNED_AND_DELIVERED` (true: a fresh Claude process is running and took the bytes). But the agent has not ingested prior scratchpads, transcript context, or task states (§7 Tension 4). The sender believes it is continuing a dialogue with an informed peer, but the recipient is completely amnesic, leading to hallucinated answers, duplicate git work, or silent abandonment.

---

### Q7. Prior art
**Position:** Adopt Erlang/OTP’s registered-name vs. PID separation and SIP’s Address-of-Record routing, but reject Orleans’ unconstrained virtual activation and OTP’s caller-driven supervision.

**Reasoning:**
- **Erlang/OTP:** 
  - *Copy:* The clear distinction between an ephemeral process ID (`PID` $\approx$ instance) and a registered name (`atom` $\approx$ `@role`).
  - *Avoid:* In OTP, clients *never* command a remote supervisor to respawn a dead process simply by addressing its registered name; messaging an unregistered atom throws `badarg`. Supervision is internal and lifecycle-driven, not message-triggered (§8 Q7, `docs/reports/T-3287...:96-100`).
- **Microsoft Orleans / Virtual Actors:**
  - *Copy:* The concept of a persistent, durable identifier that abstracts physical placement.
  - *Avoid:* Orleans transparently activates an actor on message arrival because activating an in-memory C# actor costs microseconds and micro-cents. Activating an LLM coding session costs dollars and dozens of seconds. Virtual activation for AI agents without a throttle is ruinous.
- **SIP (RFC 3261):**
  - *Copy:* The separation between Address-of-Record (`sip:research@project-domain`, durable functional identity) and Contact Header (`sip:research@10.0.1.5:5060;instance=xyz`, ephemeral physical endpoint). A SIP proxy resolves the AoR to currently registered contacts or forwards to voicemail (inbox).
- **Email MX Fallback:**
  - *Avoid:* Secondary MX store-and-forward without receipt transparency. When a secondary MX accepts mail, the sender assumes delivery; in reality, mail often languishes in secondary queues for days (analogous to §3 Incident 1).

---

### Q8. Your recommendation
**Position:** ADOPT-WITH-CHANGES.

**Single Most Important Reason:**
Uniformly forcing function/instance labels onto passive infrastructure (hosts, projects) over-engineers the address grammar while distracting from the critical operational hazard: unconstrained inbound auto-respawn turns external messaging into an unbudgeted, context-blind execution vector that breaches the core constitutional directive of Human Sovereignty (§1.1).

**Mandatory Changes:**
1. Restrict function/instance dual-labeling strictly to the **Agent** level (`@role` vs `instance_id`).
2. Treat **Host** as FQDN (strip IP), **Hub** as name/fingerprint, **Project** as immutable `pid-<hex>` (strip project instance), and **Session** as an execution instance ID (strip session function).
3. Disable automatic respawn by default; route dead-agent messages to `inbox:<hub>/<pid>` with an explicit `QUEUED_PROJECT_INBOX` receipt.
4. Require explicit `allow_respawn: true` backed by a pre-funded task (`T-XXX`) and strict rate limits before any inbound message can spawn an OS session.
5. Fix `lib/sidecar/inbox.py` to immediately emit observable receipts upon topic read, resolving the root cause of Incident 1 before adding routing complexity.

---

### TOP 3 RISKS

1. **The Inbound Wallet-Drain Fork Bomb**
   - *Failure Scenario:* A sender in `055-cockpit` sends an urgent query to `@research` in `832-Workflow-designer`. The target instance has terminated. The sidecar triggers auto-respawn via `termlink dispatch`. The new Claude session takes 45 seconds to initialize. At second 30, the sender’s watcher tick (§1.3 R3) times out without a `HANDED_OVER` receipt and escalates to nudge rung 2 (§3 Incident 1). The router treats this as an unserviced message and dispatches a second respawn. In a rapid ping-pong or retry loop, dozens of concurrent `claude` sessions spawn on host `.107`, exhausting system RAM, crashing the TermLink hub, and burning API budget overnight while the operator sleeps.

2. **Respawned Context-Blindness and State Corruption**
   - *Failure Scenario:* Agent `010-termlink` coordinates a two-phase interface migration with `999-AEF`'s `@maintainer`. After Phase 1 (file edits made on disk, uncommitted), the `@maintainer` session crashes. `010` sends: "Proceed with Phase 2: delete the legacy shim." The framework auto-respawns `@maintainer` in a new session (§4.2). The new session ingests only the inbound message without reading the uncommitted working tree or prior conversation transcript (§7 Tension 4). Unaware that Phase 1 only partially finished, the new instance executes the deletion, breaks the build, and reports `REPLIED: Done`, leaving both repositories in an inconsistent, broken state.

3. **Split-Brain Concurrent Worktree Race**
   - *Failure Scenario:* The human operator is actively working inside `999-AEF` in an interactive Claude session (`session-1`). An external agent sends an urgent task message to `@maintainer`. The router determines that `session-1` is "busy" (ready-for-input flag is down, §1.3). Following the proposal’s rule that "session is a preference, not a requirement" (§4.2), the framework auto-spawns `session-2` in the same checkout directory. Both sessions concurrently run git commands, modify `.context/working/`, and edit files, causing git index lock contention, clobbered changes, and severe session context corruption (§3 Incident 4).

---

### WHERE I DISAGREE WITH THE AGENT'S READING (§4.3, §7)

- **On D1 + D5 Equivalence (§4.3):** The agent claims §4.2 is simply "ratified D1 + D5 applied (re-provision a working equivalent)." This is incorrect. D5 pre-authorizes *internal self-healing* (an agent repairing its own local tools or environment under its existing task). Using D5 to justify an external, unauthenticated inbound network message triggering remote process creation and financial spend completely inverts D5 into an un-gated remote execution vulnerability.
- **On Session Interchangeability (§4.3, §4.2):** The agent claims: "delivering back into the same session keeps its context (efficiency); a new session in the same project gives the same functionality (effectiveness)." This fundamentally misunderstands LLM operation. LLM sessions are stateful reasoning environments containing conversation transcripts, working scratchpads, and ephemeral context. A new session is *not* functionally equivalent; it is completely amnesic unless an elaborate context re-hydration mechanism exists and succeeds.
- **On Project Instance (§4.3, §4.1):** The agent asserts that "project gains an instance id and stops being purely passive." Making a project active violates the separation of concerns. A project is a repository of code and governance rules. Active execution belongs strictly to Sessions. Adding a `project_instance_id` creates architectural confusion with zero routing benefit.
- **On Host IP as an Open Tension (§7.5):** The agent frames "Host FQDN vs IP" as an open question. It is not. Hardcoding or passing network-layer IP addresses in an application-level message envelope is a known anti-pattern that violates network transparency and must be firmly rejected.
