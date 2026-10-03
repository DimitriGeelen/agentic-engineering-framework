<!-- reviewer: qwen/qwen3.8-max-prime via OpenRouter; tokens in 4009 out 10634; cost 0.143644 -->

VERDICT: ADOPT-WITH-CHANGES — keep the function/instance split for active levels, but do not make IP or “project instance” routable, and only allow respawn under strict leases, budgets, and level-specific receipts.

Q1. Position: The two-label idea is right in principle, but only some levels should carry two routable labels.

- Host: keep FQDN only as the routing identity. Drop IP as an address label. IP is resolution state, not durable identity (§2 D2). If needed, use an optional host boot/epoch id in metadata.
- Hub: keep both labels if hubs can restart or multiply: hub function/name plus hub instance id. For the current one-hub-per-host case (§2 D6), function can be implicit, but instance id should appear in receipts/liveness.
- Project: keep `pid-…` as the durable function/namespace. Do not make “project instance id” a routable project identity. Project is passive in the ratified model (§2 D2); if you need a live context holder, define a “workspace/run” instance under the project, not a callable project.
- Session: keep session instance id. Treat session name as display/matching unless it is a formally defined long-lived queue/class. A human conversation or one-off worker session is not a stable function (§7.1).
- Agent: keep both labels: agent function name (`research`) and agent instance id. This is the core useful case.
- Missing labels: add metadata-only labels for vendor/runner/model, capability/role, task id, context pointer, and security class. Do not put vendor/model in the primary wire address if portability matters (§1.1, Portability).

Q2. Position: Wire address should carry durable routing labels plus optional instance hints; dynamic labels belong in receipts/metadata.

Routable wire fields:
- host FQDN
- hub name/id if needed
- project `pid-…`
- agent function name (`@research`)
- optional session instance id when session affinity matters
- optional instance ids/epochs as hints, not required route keys

Metadata/receipt-only:
- host IP
- hub instance id (unless multi-hub routing requires it)
- project/workspace instance id
- agent instance id (as actual resolved incarnation)
- session name
- vendor/model/runner
- task/context id

Display-only:
- human-readable project name
- session name unless formally routable
- fleet/UI labels

The sender’s receipt must name the level that actually accepted the message (§4.3), e.g. `level=hub`, `level=receiver`, `level=session`, `level=agent`, with original target and resolved actual instance. That directly attacks the §3 pattern: “true at one level, false at the level the sender cared about.”

Q3. Position: Resolve by exact instance if possible, then by function within the same project; stop at project boundary and bounce rather than silently widen scope.

Algorithm:

1. Validate address, sender identity, and policy.
   - Bad syntax, unknown project id, unauthorized sender → `BOUNCED: INVALID_ADDRESS / UNKNOWN_PROJECT / UNAUTHORIZED`.

2. Resolve host/hub.
   - Host unreachable → `BOUNCED: HOST_UNREACHABLE`, unless durable store-and-forward is explicitly allowed; then return `HUB_ACCEPTED_ONLY`, clearly marked as not agent-delivered.
   - Hub cannot route to project registry → `BOUNCED: NO_PROJECT_REGISTRY`.

3. Look up project by `pid-…`.
   - Unknown pid → `BOUNCED: UNKNOWN_PROJECT`.
   - Known pid but no supervisor/receiver for that project → `PROJECT_UNAVAILABLE` or explicit `STORED_AT_PROJECT`, not delivered.

4. If the address includes an agent/session instance hint:
   - Exact instance alive, lease valid, and it acks → `DELIVERED: exact instance`.
   - Exact instance stale/dead by positive proof or expired lease → continue to function resolution.
   - If no positive proof (§2 D4), do not respawn; return `NOT_CONFIRMED` or queue with explicit low-confidence status.

5. Resolve agent function within that project.
   - Active single-writer claim exists (§2 D7) → deliver to claimant → `DELIVERED: function claimant`, receipt includes actual instance id.
   - Session was preferred but dead → if session affinity is non-required, deliver in a new session and receipt `SESSION_REPLACED`; if session is required, bounce `SESSION_REQUIRED`.

6. No live claimant: consider respawn.
   - If respawn policy denies → `TARGET_UNAVAILABLE` or explicit `STORED_AT_PROJECT`, never `DELIVERED`.
   - If allowed, supervisor starts exactly one new instance, waits for readiness and context-load ack, then delivers → `RESPAWN_DELIVERED`, with new instance id and context pointer.
   - If spawn/readiness/context-load fails → `RESPAWN_FAILED`.

Stop rule:
- Never fall back across projects (§4.3).
- Never substitute a different agent function unless explicitly aliased.
- One respawn attempt per message/function/cooldown unless human approves.
- Repeated failures escalate to operator, not silent retry.

Q4. Position: An inbound message should trigger respawn only under preauthorized recipient policy, not merely because D5 exists.

Safe conditions:
- The target project manifest declares the agent function as respawnable.
- Sender is authenticated and allowed by the recipient project.
- The message has a valid task or creates a governed triage task; AEF’s “nothing gets done without a task” should still apply (§1.1).
- Rate limits, concurrency limits, cooldowns, and token/cost budgets are enforced.
- Duplicate `client_msg_id` messages are deduped.
- The respawned agent starts with minimal privileges and treats inbound content as untrusted until a human or trusted task grants more authority.

Who pays/authorizes:
- The recipient operator pays, so the recipient side must authorize.
- D5 Tier-3 self-heal (§2) should be read as “replace a known dead child of an active supervised task,” not “any peer may start a paid model.”
- External or low-trust messages should default to queue/triage/human review, not paid respawn.

Malicious/mistaken case:
- Quarantine or bounce if sender fails auth, rate limit, budget, or policy.
- Do not auto-execute instructions from the message.
- Log every respawn request with sender, project, function, cost estimate, and decision.

Q5. Position: Use a single-writer lease per function per project; ambiguous live duplicates should be fenced or bounced, not load-balanced silently.

Rules:
- One active claim per `(project pid, agent function)` unless the project explicitly defines a replica pool.
- Claims carry lease TTL and epoch; deliveries include epoch.
- If a second instance tries to claim the same function, it is standby or rejected.
- On failover, the old instance must be fenced before the new one receives mutable work.
- If fencing cannot be guaranteed, return `CONFLICT` and escalate.
- Two checkouts of one project sharing the same `pid-…` must either be disallowed from concurrent active registration or distinguished by a workspace/run instance id. A bare `pid` is not enough to choose between them.
- Transport may be at-least-once; application handlers must dedupe by `client_msg_id` and bind replies to that id (§3.2).

Q6. Position: The model helps many §3 incidents but does not fix them by itself; it also creates a new “respawned but contextless” failure class.

Prevented/mitigated:
- §3.1 receiver down: mitigated if the receiver/sidecar itself is supervised by function and receipts distinguish hub/receiver/agent acceptance.
- §3.3 hub accepted ≠ agent delivered: mitigated by level-specific receipts.
- §3.4 per-session ready flag: helped by session instance labels.
- §3.8 orphans: helped by instance ids plus leases/TTLs.

Left open:
- §3.1 inbox path sending no receipt: model does not fix this unless every reader path must emit a receipt.
- §3.2 replies not bound to message: requires mandatory `client_msg_id` binding.
- §3.5 shared TermLink signing identity: only partially helped; TermLink still needs per-agent identity.
- §3.7 push vs inject: not fixed; urgent injection path still matters.
- §3.9 latency: respawn may help only if authorized and fast.

New failure class:
- `RESPAWN_DELIVERED` can be true at process level and false at task level: a new `research` agent acks, but cannot find/load sufficient context, so the sender stops nudging while no useful work happens. This is the same §3 anti-pattern at a semantic level.

Q7. Position: Copy supervision/registered-name patterns; avoid location transparency that hides failure and unbounded restarts.

- Erlang/OTP: registered name vs PID is exactly function vs instance. Copy supervisors, restart intensity limits, and explicit monitoring. Avoid letting arbitrary remote messages restart processes.
- Akka/Orleans virtual actors: stable identity can activate on demand. Copy activation-by-function, but require durable state, idempotency, and backpressure; do not assume exactly-once.
- DNS + service discovery: name is durable; endpoints/IPs are disposable and health-checked. Copy: IP is not identity.
- Kubernetes: Service/Deployment name stable, pods ephemeral. Copy readiness gates before routing, liveness probes, backoff, and resource budgets.
- Email/SIP/XMPP: MX/resource routing and delivery-status notifications. Copy explicit DSN-like receipts; avoid treating MTA/hub acceptance as inbox delivery (§3.1, §3.3).

Q8. Position: ADOPT-WITH-CHANGES.

Most important reason: function/instance labeling is necessary for safe self-heal, but without leases, budgets, and level-specific receipts it will automate spend and create new silent semantic failures.

Required changes:
1. Do not route by IP; treat it as resolution metadata.
2. Keep project passive; use `pid` as durable namespace and add workspace/run instance metadata instead of a callable “project instance.”
3. Wire address should carry durable function plus optional instance hints; receipts must carry actual resolved level/instance.
4. Respawn only under explicit policy: auth, allowlist, task linkage, budget, rate limit, cooldown, and one-attempt stop rule.
5. Enforce single-writer claims with leases/epochs; bounce or fence conflicts.
6. Mandate `client_msg_id` binding and level-specific receipts for every path, including hub/topic readers.

TOP 3 RISKS:

1. Respawn cost/abuse storm.
Scenario: 832 sends repeated urgent nudges to AEF `@maintainer` while the receiver is down (§3.1). Without rate limits, the supervisor respawns a paid agent per nudge or repeatedly crash-loops. The operator gets a large bill and a flooded fleet, while no original task progresses.

2. Split-brain duplicate claims.
Scenario: two checkouts of the same project on one host share `pid-…`, and both register `@research`. A message is delivered to both or to the wrong one. Both produce conflicting patches and replies. The sender sees `DELIVERED`, but the project state diverges and the “correct” instance is ambiguous.

3. False semantic delivery after respawn.
Scenario: a TermLink session dies. The sidecar respawns `research`, which returns `RECEIVED` and is marked `RESPAWN_DELIVERED`. But the saved context pointer is missing or incomplete, so the new agent cannot follow up. The sender stops nudging because the receipt looks final; the failure is silent at the task level, recreating the §3 anti-pattern.

WHERE I DISAGREE WITH THE AGENT'S READING (§4.3, §7):

- §4.3 says point 4.2 is ratified D1+D5 applied. I disagree: D5 self-heal is not the same as externally triggered paid respawn from arbitrary inbound messages. That is a new authorization boundary.
- §4.3 says project “stops being purely passive.” I disagree: project should remain a passive durable namespace. If a live context holder is needed, model it as a workspace/run/supervisor under the project, not as the project itself.
- §4.1 treats host IP as the instance label. I disagree: IP is resolution, not identity; FQDN should remain the stable routing label.
- §7.1 asks whether session name is a real role. I think usually no: it should be display/matching unless the project defines a durable named session class.
- §7.4 assumes context ingestion is possible. I think the design must require a positive context-load ack before `RESPAWN_DELIVERED`; otherwise respawn creates a new false-positive delivery level.
