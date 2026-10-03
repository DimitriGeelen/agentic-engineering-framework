<!-- reviewer: mistralai/mistral-medium-3-5 via OpenRouter; tokens in 3933 out 1644; cost 0.0182295 -->

```
VERDICT: ADOPT-WITH-CHANGES — Two-label model is sound but needs stricter routing rules and respawn guardrails

Q1: **Keep both labels for all levels except Host (drop IP as instance label).**
   - Host: FQDN suffices (IP is transport detail, not identity; §5, §7.5).
   - Hub/Project/Session/Agent: Function + instance labels are necessary. For Project, add **vendor/model** as a *metadata* label (not routed) to satisfy Portability (§1.1). Session "name" is a role (e.g., `worker-<n>`) and must be routable; instance id is ephemeral.

Q2: **Wire address: function labels only; instance labels in metadata.**
   - Routing must target *function* (durable intent), not instance (ephemeral). Wire format: `aef::host=<FQDN>::hub=<name>::project=<pid>::session=<name>::@<agent-name>::` (§3.3, §4.1). Instance labels travel in headers (e.g., `X-AEF-Instance: <id>`) for debugging and matching.

Q3: **Fallback algorithm:**
   1. Try instance-first delivery (current sidecar path). If **RECEIVED** not returned in `<T>` (e.g., 5s), proceed.
   2. Climb to session function label: if session dead, check for *any* live session with same function label in the project. If found, deliver there (new receipt: `SESSION_REDIRECTED`).
   3. If no session, climb to project: if project instance dead, **respawn a new project instance** (Tier-3, §1.1 D5) *only if* the message is from a trusted sender (whitelist) and rate-limited (e.g., 1 respawn/5min/project). Receipt: `PROJECT_RESPAWNED`.
   4. If project unresolvable, climb to hub: post to hub inbox topic (`inbox:<hub>/<pid>`). Receipt: `HUB_ACCEPTED` (explicitly *not* delivered).
   5. **Stop rule:** Never fall back across projects (§4.3). If hub fails, bounce with `NO_ROUTE` (sender sees this immediately).
   - Receipts at each step must include the *level* that accepted the message (§3.1, §3.3).

Q4: **Respawn safety:**
   - **Authorization:** Only messages from *known projects* (whitelisted `pid-…`) may trigger respawning. Unknown senders → bounce.
   - **Cost control:** Respawn only for **urgent** messages (flagged by sender) or after human approval (Tier-0). Rate limit: 1 respawn/hour/agent-function by default.
   - **Context:** Message must include a `context-hash` (e.g., SHA-256 of the last N transcript lines). New instance verifies hash before acting (§4.2, §7.4).
   - **Malicious messages:** Reject if message size >10KB or contains non-UTF-8 (basic sanitization).

Q5: **Exactly-once:**
   - **Single-writer claim per function label** (extend D7). First live instance to claim the function label (via distributed lock, e.g., TermLink KV) takes the message. Others ignore it. Lock TTL = 30s (matching watcher tick §3.3 R3).
   - **Deduplication:** Sender includes `msg-id` (UUIDv4). Recipient logs `msg-id` in a per-function-label deduplication store (TTL=24h).

Q6: **Incident coverage:**
   - **Prevents:** §3.1 (no receipts: now explicit `HUB_ACCEPTED` vs `DELIVERED`), §3.2 (replies bound by `client_msg_id` + `msg-id`), §3.3 (hub ≠ agent delivery: receipts distinguish levels), §3.4 (per-session ready flag: now per-instance), §3.7 (push vs inject: wire address targets function, not transport).
   - **Leaves open:** §3.5 (shared signing identity: needs TermLink fix, outside AEF), §3.8 (orphans: add TTL on registry entries, e.g., 1h).
   - **New risk:** A respawned agent may act on stale context if `context-hash` is missing or mismatched (§4.2).

Q7: **Prior art:**
   - **Erlang/OTP:** Copy registered names (function labels) + PIDs (instance labels). Avoid: silent PID reuse (we need explicit respawning).
   - **Akka/Orleans:** Copy virtual actors (function labels) with activation on demand. Avoid: unbounded activation (we need rate limits).
   - **Email MX:** Copy fallback hierarchy (hub → project). Avoid: no delivery receipts (we mandate them).
   - **SIP/XMPP:** Copy request/response correlation (our `msg-id`/`client_msg_id`). Avoid: complex NAT traversal (we assume TermLink handles transport).

Q8: **Recommendation:**
   Adopt with changes:
   1. Drop Host IP instance label (§7.5).
   2. Add vendor/model as *metadata* for Portability (§1.1).
   3. Mandate `context-hash` for respawned agents (§4.2, §7.4).
   4. Add TTL to registry entries to prevent orphans (§3.8).
   5. Explicitly distinguish `HUB_ACCEPTED` vs `DELIVERED` in receipts (§3.1).

TOP 3 RISKS:
1. **Respawn abuse:** A malicious project floods with messages to trigger respawning (e.g., 100 `research` agents). *Scenario:* Attacker sends 100 urgent messages to `pid-attacker` with spoofed `pid-999-AEF`. *Mitigation:* Whitelist senders + rate limits (Q4).
2. **Stale context:** Respawned agent acts on outdated context. *Scenario:* `context-hash` points to a deleted file; agent loads empty context and sends wrong reply. *Mitigation:* Require hash verification + human fallback for Tier-0 actions.
3. **Split-brain delivery:** Two instances claim the same function label due to lock race. *Scenario:* Network partition causes both instances to see themselves as the single writer. *Mitigation:* TermLink KV must support fencing tokens (outside AEF scope; flag as dependency).

WHERE I DISAGREE WITH THE AGENT'S READING (§4.3, §7):
- **§4.3:** "D1 + D5 applied" is incomplete. D1/D5 assume *pre-authorized* self-heal, but respawning on arbitrary messages is *not* pre-authorized for cost reasons (§5, §7.2). Need explicit authorization checks.
- **§7.2:** Respawn authority is *not* just D5. D5 covers *re-provisioning a missing child*, but respawning a *new* agent (not a replacement) is a Tier-0 action requiring human approval if it incurs cost.
- **§7.3:** Exactly-once is not addressed by D7 alone. D7 serializes writes, but does not prevent duplicate delivery to two instances of the same function. Need deduplication (Q5).
```
