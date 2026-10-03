Verified against `lib/aef_address.py`, `lib/sidecar/circuit.py`, and `lib/sidecar/inbox.py`. Review follows.

```
VERDICT: ADOPT-WITH-CHANGES — the function/instance split is the right primitive, but the
proposal over-labels (session, host) and under-specifies the two things that actually caused
the §3 incidents: receipt semantics and lease-based claims. Without those, the relabeling
changes nothing observable.

Q1. The two-label model is right at exactly two levels (agent, and arguably hub); wrong or
redundant at the other three.
- Agent: keep both. This is the core of the proposal and it is correct — it is what makes
  D1's "a working equivalent, not the same B" well-defined. The function name is the
  matching key for respawn; the instance id is the matching key for receipts and claims.
- Hub: keep both, but only because multi-hub is on the table (§4.1, "undecided"). While
  hubs are 1:1 with host (D6), a hub function label is dead weight. If hub1..n never
  happens, drop it. Note an existing inconsistency the proposal should name: the "durable
  role address" `<hub>/<project>` (circuit.py:16) embeds a hub *fingerprint* — an instance
  label — at rung 2 of a supposedly durable address. Hub restart = new id = every durable
  inbox topic name changes. Decide now whether topics are keyed by hub id or by host.
- Project: keep pid as the function label; make the new "project instance id" a claim
  token in metadata, NOT a wire slot (see Q2). I disagree with §4.3 that project "stops
  being purely passive" — the callable surface at project level already exists (the
  durable inbox topic); the pid names it. The instance id's real job is disambiguating
  two checkouts sharing one pid (§7.3) and generalizing D7's single-writer claim — that is
  claim metadata, not routing.
- Session: drop the function label from routing. §7.1's answer is: a session name is not a
  role. A human-conversation session's "function" is carrying one conversation, which no
  new session can re-fulfill under the same name meaningfully; a dispatched worker's role
  is already carried by the agent name — which is why circuit.py:39-46 collapses
  session==agent to the 3-form, a measured, correct decision this proposal would reverse.
  A human-readable session label is fine as display metadata.
- Host: one label (FQDN). The IP is not an instance label; it is a resolution artifact
  (see my disagreement on §7.5). DNS is the resolution layer; the address never carries
  the IP.
Missing from the model: (a) a *home-host* notion per project — Q4 needs it to bound where
respawn may occur, and no level carries it today; (b) leases/TTL on instances — without
expiry, two-label addressing recreates §3.8's orphans at every level; (c) vendor/model —
deliberately keep it OUT of the address (Portability, §5): it is an instance attribute in
metadata, relevant to cost policy, never to routing. Role-vs-name for agents: keep one
name per agent; aliases are metadata.

Q2. Wire carries only: host=FQDN, hub id, pid, @agent-name, and session instance id when a
specific circuit is intended (that token is precisely D2/D3's correspondent/circuit
split — aef_address.py:59-71 — and it survives unchanged). Metadata: project instance id
(claim token), hub function name, session display name, vendor/model, home-host, lease
expiry. Display-only: folder names, elided paths (the existing fence at aef_address.py:
216-220, 240-243 is the right pattern — keep it for every new label). IP: resolution
only, never serialized. The pid ruling (§2, 2026-10-03) already made the readable project
name display-only; extend that rule to all function labels: **wire = ids + routing-level
function names; everything else rides in the envelope.** And keep ONE wire grammar: you
currently have two (V9 and the path form) with a known project-slot inconsistency; every
added label multiplies that grammar matrix.

Q3. Algorithm, from "full address does not resolve":
1. Exact circuit (agent+session) via receiver HTTP. Success → RECEIVED(level=circuit,
   instance=<agent-instance-id>).
2. Dead circuit → same function, any live instance wearing @name under the same pid
   (registry lookup, Q5). Success → RECEIVED(level=agent, instance=<other-id>) — receipt
   explicitly notes the session preference was not honored.
3. No live instance → post to the durable inbox topic inbox:<hub>/pid/@<agent>. The hub
   ack is ACCEPTED_AT_HUB — and the sender UI must render it as "waiting", never
   "delivered" (this is the direct fix for §3.1/§3.3: rename the state so it cannot be
   mistaken).
4. Hub unreachable → resolve host, remote-call that host's hub. Host unreachable →
   BOUNCE with the last reachable rung named. No respawn across hosts, ever.
5. Respawn by function: only if (a) the recipient project's policy allows it (Q4) and
   (b) the sender marked the message persistent. Respawn provisions a new instance of
   @<agent> under pid on the project's home host; the message stays in the inbox topic;
   the new instance's reader takes it; receipt = RESPAWNED(pid, @agent, new-instance-id).
6. Stop rule: the message waits in exactly one durable place (the project inbox) and
   never "delivers" at a lower rung. The current climb() (aef_address.py:91-104) drops
   tokens to find a re-provisioning ancestor — that was designed for ladder repair (D1),
   not for delivery. §3.1's failure mode was exactly delivery at a lower rung being read
   as delivery to the agent. Separate "where the message waits" (always project level)
   from "who is provisioned to read it" (respawn by function). Never cross the project
   boundary (§4.3, agreed — and 010's agreement is worth having on record).

Q4. Respawn safety:
- Authority: D5 pre-authorizes a project's own supervision re-provisioning itself. It
  does NOT cover peer-triggered respawn — that converts a remote peer's send into the
  recipient operator's spend. Per-project policy bit in .framework.yaml
  (auto_respawn: none | workers-only | any-agent), default none. The human sets it;
  sovereignty over money (§5) is non-delegable.
- Who pays: whoever hosts the instance — so respawn only on the project's home host,
  never on the sender's host (execution locality changes file access, permissions, and
  whose bill).
- Rate limits: OTP-style restart intensity — N respawns per function per T minutes, then
  stop and page the operator. Plus a cap on concurrently respawned instances per
  project, and receiver-side dedupe on client_msg_id (already built, inbox.py:14-21) so
  retries don't multiply spawns.
- Malicious/mistaken: the respawn decision reads the envelope (sender identity, class),
  never the payload; only signed senders with an established correspondent may trigger
  it — which depends on TermLink per-agent identity (§3.5): flag this as a hard
  dependency, because today all agents on a host sign as one identity, and any
  respawn trigger keyed on the current shared identity is spoofable by any local agent.

Q5. Exactly-once: a function claim = lease on (pid, @name), held by exactly one instance,
heartbeated, TTL-bounded. The hub is the single arbiter — the claim must be a hub-owned
object (KV with compare-and-swap, or a well-known topic where latest write wins), not a
local file, because two checkouts on one host can both see their own disk. Delivery goes
to the claim holder; a tie breaks to lowest instance id; the loser stands down its
watcher entirely — not just declines this message (T-3745's lesson generalized: the
failure wasn't only misdelivery, it was a second watcher existing at all). The loser
re-ingests from inbox offsets on reclaim; client_msg_id dedupe makes that safe. Leases
also fix §3.8: a claim/registry entry that cannot be renewed expires, and senders stop
believing in receivers that died 22 hours ago.

Q6. Prevented: §3.2 (binding replies by client_msg_id + function makes REPLIED
  achievable and stops nudge ladders); §3.4 (session instance ids make ready-flag keying
  exact); §3.8 (leases). Partially prevented: §3.1/§3.3 — only if the receipt contract
  (level + instance + waiting-vs-taken) is enforced as part of this change; the
  two-label model alone does nothing for §3.1, which was a code gap (no receipt on the
  topic path at all), not a naming gap. Not prevented: §3.5 (shared signing identity —
  TermLink's fix, and a dependency for Q4); §3.7 (push-vs-inject is a wake-path issue);
  §3.9's 49-min median (a watcher/tick/human-loop problem; respawn only helps the tail).
New failure class introduced — yes, two:
- Label confusion: the sender addresses a function, receipts an instance, and the
  instance is stale (lease not yet expired, process half-dead). "Delivered to @research"
  was true at the label, false at the level the sender cares about — the same shape as
  §3, one level deeper.
- Cross-instance ack: a respawned instance answers with a DIFFERENT instance id than the
  one addressed; if ack matching keys on instance id, REPLIED never lands and the nudge
  ladder fires at an agent that already answered. Match on (function, client_msg_id),
  never on instance id.
Also: IW-2 migration — old senders address folder-name topics; a respawned reader
  watching only pid-keyed topics won't see them. The dual-read pattern (inbox.py:110,
  read_topics) must cover every new reader, including respawned ones.

Q7. Prior art:
- Erlang/OTP: registered names + whereis = exactly the function/instance split;
  supervision trees with restart intensity = exactly the Q4 stop rule. Copy both. Avoid:
  OTP's distributed global registry had split-brain races — use one arbiter (the hub).
- Orleans/Akka virtual actors: "the actor id always exists; the runtime activates an
  instance on first message" IS §4.2 — proof the model works. Copy the model; reject the
  autonomy: here placement and spend are the operator's, so activation is policy-gated.
- DNS + service discovery (SRV/Consul): name → endpoint with TTL health checks. Copy
  lease/TTL semantics and resolve-late addressing; avoid caching beyond TTL (a cached
  stale endpoint is §3.8 verbatim).
- XMPP: node@domain/resource is the closest grammar — resource = your instance label.
  Copy the grammar shape; avoid its presence-storm scaling problems (you have one
  operator, not millions of buddies).
- Email MX fallback: priority-ordered fallback works, but backup-MX acceptance created
  the "accepted ≠ delivered" backscatter class — which is §3.1. Copy the priority
  ordering; legislate against silent lower-rung acceptance (Q3's rename does this).

Q8. ADOPT-WITH-CHANGES. Single most important reason: the split is the right primitive —
it is what makes "working equivalent" well-defined, and forty years of prior art
converged on it — but the incidents in §3 were caused by receipt semantics and stale
liveness, not by missing labels, and the proposal as written adds labels without
changing either. Changes:
1. Drop the session function label from routing (metadata/display only); keep the
   session==agent collapse (circuit.py:39-46).
2. Drop IP from the address; resolution only.
3. Project stays passive for routing; project instance id is a claim token in metadata.
4. Receipts name level + instance + waiting-vs-taken; rename HUB_ACCEPTED so it cannot
   be read as delivered; match acks on (function, client_msg_id), not instance id.
5. Leases with TTL on function claims, hub as single arbiter; losing instances stand
   down watchers entirely.
6. Respawn: per-project policy default off, home-host only, OTP restart-intensity limit,
   envelope-only decision, signed-sender requirement (depends on TermLink T-3325/per-
   agent identity).
7. Add a home-host field to the model (needed by 6; currently absent from all five
   levels).
8. Sequence after IW-2, or dual-read both topic spellings in every reader including
   respawned ones.

TOP 3 RISKS:
1. Stale-lease misdelivery. @research dies at 09:00 with a 10-minute lease; message
   arrives 09:02; registry still names the dead instance; sender gets RECEIVED and stops
   nudging; nobody reads the message for hours. Same shape as §3.1, now with a receipt
   that lies more convincingly. Mitigation: RECEIVED is never terminal — HANDED_OVER
   requires transcript evidence (as already designed, §1.3), and that contract must
   survive this change.
2. Respawn cost loop. A peer's retry ladder (observed at rung 4, §3.1) meets
   auto_respawn=on and a context that crashes the fresh agent on ingest: each retry
   spawns, ingests, crashes, dies — a bill and a token burn driven entirely by a remote
   sender. If the intensity limit isn't built in the same slice as the respawn path, the
   first malformed message is a denial-of-wallet.
3. IW-2 split-brain. Old-version sender posts to inbox:<hub>/010-termlink; respawned
   reader watches inbox:<hub>/pid-…; receipt says RESPAWNED (true — an instance was
   started) while the message sits in a topic nobody reads forever. The migration
   reintroduces the exact §3 failure class it was meant to eliminate; dual-read is not
   optional.

WHERE I DISAGREE WITH THE AGENT'S READING (§4.3, §7):
- §4.3 "point 4.2 is ratified D1 + D5 applied": half right. D5 pre-authorizes a
  project's own self-heal; it does not authorize peer-triggered spend. Peer-triggered
  respawn is a new authority grant and needs an explicit operator ruling, not a
  derivation.
- §4.3 "project stops being purely passive": unnecessary. The inbox topic is the
  callable surface; the pid names it. You get respawn-by-project without putting an
  instance label on the wire, and you keep D2's clean passive/active line.
- §7.1: the agent leaves "is a session name a real role" open. It isn't — and the
  codebase already answered it correctly by collapsing session==agent for dispatched
  workers. Adding a session function label reverses a measured decision.
- §7.5: FQDN-vs-IP is framed as function-vs-instance. Wrong frame — it is stable-name-
  vs-resolution-artifact. The IP never belongs in the address; the question dissolves.
- §7.3: "two live instances — who takes the message?" understates it. For two checkouts
  sharing a pid the question is who runs a watcher at all; T-3745 showed the second
  actor's existence (not its delivery choice) is the hazard. The loser must stand down
  entirely.
```
