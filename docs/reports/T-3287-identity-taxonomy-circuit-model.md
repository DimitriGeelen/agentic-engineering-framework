# T-3287 — Cross-agent identity taxonomy + circuit-establishment model

**Status:** inception / exploration (opened 2026-09-06)
**Parent of:** T-3286 (narrow producer-parity fix — carry level-5 agent id on the wire)
**Related:** G-105 (producer/consumer identity parity gap), T-2904 (rail-identity, project-level signing), T-1841 (be-reachable / listener heartbeat), T-1693 (shared-host-envelope-identity, forward-compat reader)

> This file is the persistent thinking trail (C-001). The conversation is
> ephemeral; this is not. Updated incrementally as the dialogue produces findings.

---

## Problem Statement

The trigger was a concrete fault: on a live cross-project TermLink thread
(100-Video-riper's course-transfer coordination), several **distinct agents on
one host collapse into a single correspondent**. The narrow cause is known and
filed (G-105 / T-3286): the agent-chat producers never stamp a logical
`agent_id`, so the reader falls back to the shared crypto fingerprint.

But the operator reframed the fault as the tip of a larger absence: the framework
has **no explicit taxonomy of identity** and **no model of a durable connection**
between two agents. "Who is talking" and "how do I reach them again" are currently
emergent accidents of whatever termlink resolves, not a designed addressing
scheme. This inception is to design that scheme before building more of it.

---

## The proposed taxonomy — 5 levels

A hierarchy of nested identity scopes. Each level is contained by the one above.

| # | Level | What it is | Contained by |
|---|-------|-----------|--------------|
| 1 | **Host** | A physical/virtual machine | — |
| 2 | **Hub** | A termlink hub process running on a host | Host |
| 3 | **Project** | An AEF (or other) project living under a hub | Hub |
| 4 | **Session** | A running session (a `claude` process) in a project | Project |
| 5 | **Agent** | An agent *profile* active within a session | Session |

Key properties the operator stated:

- **Agent profiles are switchable within a session** (level 5 is mutable inside a
  fixed level 4). So the (session → agent) edge is one-to-many *over time*.
- **Level 4 (session) is the minimum runnable unit** — "we need to run in a
  project", i.e. nothing below a session actually executes; an agent is a *role
  the session is currently wearing*, not an independent process.
- A **fully-qualified address** is therefore `Host.Hub.Project.Session.Agent`
  (levels 1–5). The operator initially said "host+hub+session" and corrected to
  include **project** — the unique addressable identity needs all of
  host+hub+project+session, with agent as the optional most-specific leaf.

Analogy anchors (for reflection, not yet decisions):
- **Actor-path addressing** — `/host/hub/project/session/agent`, exactly like
  Erlang/Akka hierarchical actor references.
- **DNS** — hierarchical, delegated resolution; each level knows how to resolve
  its children.
- **Telephony circuit** vs packet — see the circuit model below.

---

## The circuit-establishment model

The operator's core move: communication is not only **broadcast**. Two parties
establish a **dedicated circuit** — a durable, addressable channel — and can
**re-use it later** via a stable **circuit ID**.

- **Party A** (at least level 4 — a host.hub.project.session) initiates contact to
  **Party B** (down to level 5 — a specific agent).
- On success, a **circuit is established** and gets a **circuit ID**.
- Later, Party A re-contacts Party B by naming the circuit ID rather than
  re-resolving from scratch. (Cheaper, and it pins *the same* B.)

This is a **connection-oriented** overlay on top of what is otherwise a
publish/subscribe (broadcast) substrate. The circuit ID is the session-of-the-
conversation — distinct from level-4 "session", so naming will matter (see Open
Questions).

---

## The regressive resolution ladder (the interesting part)

The question the circuit model forces: **what happens when re-connecting on a
circuit fails?** The agent (level 5) may be gone. The operator's answer is a
**graceful-degradation ladder that climbs to the nearest ancestor able to
re-provision the descendant**, then re-establishes downward:

```
Try circuit -> level 5 (agent) unreachable
  climb to level 4 (session):  "I want agent X - can you (re)instate it?"
  not found -> level 3 (project): "can you start a session (that can host X)?"   <- the bridge
  not found -> level 2 (hub):     "do you have project P? start a session for it"
  not found -> level 1 (host):    "I need a termlink hub - can you stand one up?"
                                   then resolve down: host -> hub -> project -> session -> agent
```

Each rung is "ask the parent to (re)create the missing child." This is precisely
an **OTP supervision tree**: a supervisor at level N is responsible for
(re)starting its level N+1 children, and a request that can't reach a child
escalates to the supervisor that owns it. The novelty here is that the *client*
drives the escalation as a resolution ladder, and the same ladder doubles as
**provisioning** (level 1 "do you have this capability? stand it up") — discovery
and orchestration are the same walk.

**Open tension already visible:** discovery (find an existing B) and provisioning
(create a B) are merged in this ladder. That is powerful (self-healing circuits)
but dangerous (a typo'd address could provision a whole hub). The boundary between
"reconnect to what exists" and "materialise what doesn't" needs an explicit gate.

---

## Two follow-up questions the operator raised

### Q-A — Negotiation / election on a broadcast with multiple candidates

If Party A broadcasts at, say, level 4 ("I want an AEF session on this
host/hub/project") and **multiple candidates** can answer (multiple sessions, or
multiple projects, or multiple agents), **who picks it up?** You don't want all of
them to, and you don't want none. This needs a **negotiation / claim / election**
protocol:
- first-to-claim-locks (a mutex on the request),
- bidding / capability-scored election (best-fit answers),
- or supervisor-assigns (the parent picks one child).

**Note — TermLink already ships a claim primitive.** `termlink channel claim` /
`claim_transfer` / `claim_force_release` / `claims_summary` exist. That is very
likely the substrate for "exactly one candidate takes this", and the design
should reuse it rather than invent an election. To verify in the design phase.

### Q-B — "termlink or termlink" (INCOMPLETE — needs the operator to finish)

The dictation cut off: *"Second question. termlink or termlink."* Best guesses at
the intended question, for the operator to confirm/replace:
1. **Substrate choice** — should circuits be built on **termlink** primitives
   (dm topics + claim + events + heartbeat) or on **something else**?
2. **termlink vs TermLink** — a naming/branding disambiguation between the binary
   and the product?
3. **termlink hub vs termlink fleet** — which layer owns hub provisioning at
   level 1–2?

-> **ACTION: operator to complete Q-B.**

---

## What the framework already has (primitives to reuse, not reinvent)

Mapping the model onto existing TermLink / AEF mechanisms, so the design composes
rather than greenfields:

| Model concept | Existing primitive (candidate) |
|---------------|-------------------------------|
| Level-5 agent identity on the wire | `metadata.agent_id` (T-3286 fix) + reader tier-1 (already built) |
| Level-3 project identity (signed) | `rail-identity` project key (T-2904) — project-level, one layer of the 5 |
| Presence / "is B alive" | be-reachable + listener heartbeat (T-1841); `agent-presence` topic |
| Circuit (durable channel) | `dm:<addr>:*` topics + `conversation_id` metadata (partial today) |
| Circuit ID | `conversation_id` is a proto-circuit-id, but per-thread not per-pair-durable |
| Re-provisioning ladder | **absent** — no supervisor/escalation walk exists yet |
| Election on multi-candidate | `channel claim` family (exists, unused for this) |
| Signaling between levels | `event emit/wait/poll`; `inject` doorbell (agent-send) |
| Host/hub provisioning (level 1–2) | `termlink hub start/status`; `fleet` verbs — the raw capability exists |

**The gap is not primitives — it is the addressing scheme and the escalation
walk that tie them together.** Most rungs of the ladder have a primitive; nothing
composes them into "resolve `H.Hub.P.S.A`, and on miss climb to the parent."

---

## Open design questions (to work through together)

1. **Addressing syntax** — is the canonical address a path
   (`host/hub/project/session/agent`), a tuple, or a flat resolvable id? What is
   the wire form on an envelope?
2. **Circuit ID vs conversation_id** — is a circuit *per pair of endpoints*
   (durable, survives many conversations) or *per conversation*? The operator's
   "re-connect later on the same circuit" implies per-pair-durable, which
   `conversation_id` is not today.
3. **Discovery/provisioning boundary** — where is the gate between "reconnect to
   an existing B" and "create a B"? Who is allowed to trigger level-1/2
   provisioning, and with what authority (this is a sovereignty question —
   standing up a hub is consequential)?
4. **Election policy** — first-claim, bid, or supervisor-assign for Q-A?
5. **Identity vs authentication** — is `agent_id` a *cooperative label* (current
   design, unsigned free text — T-2905) or an *authenticated identity* (its own
   key per level)? The operator's word "fingerprint" leans toward authenticated;
   that is a much larger build and must be decided explicitly, not drifted into.
6. **Profile-switching semantics** — if level 5 switches mid-session, does the
   circuit follow the *session* (level 4, stable) or the *agent profile* (level 5,
   mutable)? A circuit pinned to level 5 breaks on every profile switch; pinned to
   level 4 survives but loses agent-grain distinctness. This directly re-touches
   the original T-3286 grain question.

---

## Reflection findings — round 2 (2026-09-06)

These are agent-proposed refinements from reflecting on the model, NOT yet
operator-ratified decisions. Marked so a later reader can tell proposal from
ratification.

**F1 — [OVERRIDDEN by D1, 2026-09-06] Level 5 (agent) is a PREDICATE over level 4, not an address.** An agent is
a profile a session *wears*, and profiles switch within a session, so an agent has
no independent existence to open a circuit to. The real endpoint is always the
**session** (level 4, the stated minimum runnable unit). "Reach agent X" is not an
address lookup — it is a *query*: "route me to a session currently presenting
profile X." Two agents may be worn by one session over time; one profile may be
worn by two sessions at once. So level-5 addressing is a filter over level-4
endpoints, not a level of its own in the routing sense.

**F2 — [OVERRIDDEN by D1, 2026-09-06] Circuit pins to level 4; the role label rides on each message (level 5).**
Falls out of F1 and cleanly dissolves the profile-switching tension (open question
#6): the circuit survives profile switches because the session is stable; the
current role is carried per-message as a label. This ties back to T-3286: the fix
should stamp BOTH a stable session/circuit id AND the current agent/role label —
the router uses the session, the thread transcript *shows* the role. Distinct
agents read as distinct even when the underlying circuit is one session.

**F3 — Circuit ID is DNS-shaped, not IP-shaped.** The circuit ID should name the
*logical* endpoint (project + role) and re-resolve to the current concrete
session on reconnect — like a hostname resolving to a changing IP. This is what
makes the ladder work: reconnection does not require the old session to still
exist; it re-resolves the stable name to whatever session satisfies it now.
`conversation_id` today is per-conversation, not this stable per-endpoint handle —
gap.

**F4 — Split the ladder into RESOLVE vs PROVISION with a sovereignty gate.** The
ladder as stated merges discovery ("find existing B") and provisioning ("ask a
parent to create B") into one walk, and auto-provisions up to "host, stand up a
hub" — which a typo'd address would also trigger. Proposed split:
- **Resolve** (climb to find what exists): cheap, side-effect-free, always allowed.
- **Provision** (materialise a missing child): consequential, authorized, rate-
  gated; above some level it needs a human or a standing policy (Authority Model —
  agents hold initiative, not authority to commit infrastructure). WHERE the gate
  sits (session? project? hub?) is an operator decision, open.

**F5 — Reuse `channel claim` for Q-A election, do not invent one.** v1 pattern:
broadcast the request to the level-N topic; candidates race to `claim` it;
first-claim wins the mutex; the rest back off. Best-fit (capability bid + a short
auction window, parent picks) is a v2 option. First-claim is the likely v1 and is
the exact mechanism that decides which AEF session owns the Video-riper transfer
circuit instead of all-or-none answering.

## Ratified decisions

**D1 (2026-09-06) — Identity is INSTANCE-identity, not role-identity.** Operator
ruling. A circuit is a specific established channel down to a specific
agent-instance (level 5). The circuit ID is **transient** — it dies with the
circuit; only the caller's retained reference to it persists, used to *attempt*
the fast-path re-establishment. Reconnect is optimistic-then-degrading: try the
circuit ID; if the endpoint is gone, climb the ladder (5→4→3→2→1) until an
ancestor can re-provision, then establish a NEW circuit with a NEW id. The ladder
does NOT preserve identity — it yields a working equivalent, not "the same B".

Consequences:
- Overrides F1/F2. Level 5 is a FIRST-CLASS endpoint with its own liveness, not a
  predicate over level 4 — the tell is that the operator lists "agent gone" and
  "session gone" as INDEPENDENT failure levels.
- Settles the origin bug unconditionally: under instance-identity two distinct
  agent-instances must NEVER collapse to one correspondent, so T-3286 (always
  separate them) is correct in all cases. Role-identity would have made the
  collapse sometimes-correct; it was ruled out.

**D1-open (grill in flight) — profile-switch liveness.** For D1 to be internally
consistent, a profile switch within a live session must KILL the level-5
agent-instance and its circuit (agent-instance = (session, current-profile-epoch),
independently mortal). If a switch does NOT kill the circuit, agent-liveness is
not independent of session-liveness and level 5 collapses into level 4,
contradicting D1. Awaiting operator ruling.

**D2 (2026-09-06, operator-proposed → agent-refined into two clean strings) —
every level has a DURABLE NAME; the circuit ID is durable-name + session.**
Operator walked each level's durable name:

| # | Level | Durable name | Nature |
|---|-------|--------------|--------|
| 1 | Host | **FQDN** (or IP) | active, DNS-static |
| 2 | Hub | hub id — one termlink hub per host is the entry point ("I need to be a termlink hub") | active, singleton-by-type |
| 3 | Project | the **root directory / path** it is bound to | **PASSIVE** — a location, not a process |
| 4 | Session/instance | the **termlink-generated instance ID** (always unique) | active, transient |
| 5 | Agent | the **@agent-name** (declared; a bootstrap act — create/collaborate-to-create — establishes it) | active, project-scoped durable name |

The operator's **passive-project insight** is the structural payoff: level 3 is
not an actor. "AEF is always bound to a root directory, which is its project
directory — it's not allowed to go out there" (ties to T-559 project-boundary).
A project cannot *do* anything, so its rung on the resolve/provision ladder is
never "ask the project" — it is "ask the HUB to start an instance bound to
project-path P." The project is uniquely *addressable* (by path) but never
*callable*. This dissolves an apparent 5-actor ladder into 4 actors + 1 address.

**Agent refinement — separate the two strings the operator briefly merged.** The
operator's composite ("L1 FQDN / L2 hub / L3 path / L4 session / L5 @name") is
correct but names *two different things* at once. Split cleanly:

- **Durable name** = `FQDN / [hub] / <project-path> / @agent-name` — **no session
  segment.** This is the CORRESPONDENT: the who-you-talk-to. It survives instance
  death, it is what the ladder re-resolves to, it is DNS-static (an A-record that
  keeps its name across IP changes). Stamped on the wire as the level-5 `agent_id`
  (the T-3286 leaf).
- **Circuit ID** = durable-name **+ session-id** — this live binding. It is the
  ACTOR: the specific running instance, transient, needs live resolution (the
  DNS *A-record lookup*, not the name). Dies with the session; the caller retains
  it only to *attempt* the fast path (consistent with D1).

So the two-layer identity, sharpened: **durable name = the correspondent the peer
sees** (continuity; what you stamp so distinct agents read as distinct); **instance
id = the actor the coordination layer sees** (the discriminator; can conflict; the
thing that decides who owns a claim). One string for "who is this", one for "which
live process". T-3286 stamps the first; the circuit/claim layer keys on the second.
*Operator asked to reflect and agree — not yet ratified; this is the agent's
proposed split of the operator's composite.*

**F6 (2026-09-07, verification finding — challenges operator's slash claim).**
Operator claimed "all LLM harnesses use `/` for agents (Codex, OpenCode,
Antigravity, Anthropic)" and asked to be challenged if wrong. Verified via web
search (Sept 2026): **the claim is nuanced and the load-bearing half is wrong.**
Slash is near-universal — for **commands / workflows / session control**, NOT for
agent *identity*:
- Claude Code: `/` = commands; an agent is invoked by **@-mention** (`@code-reviewer`) or `--agent`.
- OpenCode: `/<name>` = commands; subagents are **@-mentioned** (`@file-writer`); docs say the `@` prefix is *for* invocation.
- Codex CLI: `/model`, `/agent`, `/status` are session **commands** — `/agent` manages threads, it is not an agent's name.
- Antigravity: slash commands invoke agent **workflows** (`/goal`, `/boost`, `/agents`) — a partial point *for* the operator (it blurs command↔agent), but still names workflows, not a specific agent's identity.

**Design consequence (why F6 matters, not trivia):** we are designing an
*identity* (the "who"), which across the ecosystem is the **@-mention** role, not
the `/command` role. And `/` is **already our path separator** (levels 1→5). Using
`/agent-name` for the leaf overloads slash into three jobs (separator, command,
identity) and reads as "a command" to anyone fluent in these tools. Proposal:
**agent leaf = `@agent-name`** — ecosystem-aligned for "who", and it composes:
`/` separates levels, `@` marks the identity leaf, `:` binds the transient session:

```
Durable name:  fqdn / <project-path> / @agent-name
Circuit ID:    fqdn / <project-path> / @agent-name : <session-id>
```

Sources: code.claude.com/docs/en/agent-sdk/subagents · opencode.ai/docs/agents ·
opencode.ai/docs/commands · developers.openai.com/codex/guides/slash-commands ·
antigravity.google/docs/slash-commands. *Awaiting operator decision: align to `@`
for the leaf, or deliberately diverge (Antigravity-style slash-for-workflow).*

**Open — availability vs memory antifragility (surfaced round 5, unresolved).**
D1's ladder guarantees *availability*: the re-provisioned instance wears the same
durable name, so the correspondent is always reachable. But a re-provisioned
instance has **amnesia** — durable NAME ≠ durable STATE. The ladder yields "a
working equivalent, not the same B" (D1), and that equivalent does not remember
the prior circuit's conversation, decisions, or relationship. **Where does
circuit/relationship state live?** Options, unresolved: (a) nowhere — every
re-establishment is a fresh relationship (pure availability, no memory); (b) in the
project (passive, path-bound — survives instance death, the natural home given D2);
(c) in a durable per-correspondent store keyed by durable name. This is the next
real fork after the slash decision.

## Relationship to T-3286 (the narrow fix)

T-3286 (producers stamp `agent_id`) is the **level-5 leaf** of this taxonomy
arriving on the wire. It is correct and compatible with every version of the
larger model, so it is NOT blocked by this inception — but its **grain decision**
(per-session vs per-role vs project) is really question #6 above, and should be
decided as part of this taxonomy rather than in isolation. Recommendation:
proceed with T-3286's *mechanism* (carry whatever id resolves), defer its
*primary-source/grain* choice to this inception's outcome.

---

## Dialogue Log (C-001 extension — the WHY behind the model)

**2026-09-06 — opening.**

- *Operator, on the earlier fix suggestion:* per-role + distinct-by-construction
  fallback "actually does make good sense", but "in my mind it is not fixed. I am
  just presenting it as a fault." -> i.e. not rejecting the fix; widening the lens
  before committing. Correction absorbed: do not treat the producer-parity fix as
  the whole answer.
- *Operator introduced the 5-level hierarchy* (host / hub / project / session /
  agent), self-correcting twice to land on: unique addressable identity =
  host+hub+**project**+session (+agent leaf); level 4 (session) is the minimum
  runnable unit; agent profiles switch within a session.
- *Operator introduced circuits* — dedicated, established, re-usable via circuit
  ID; not only broadcast. Party A (>=L4) initiates to Party B (L5).
- *Operator introduced the regressive ladder* — on circuit failure, climb to the
  parent that can re-provision the child, down to the host ("do you have this
  capability? stand up a hub"). Discovery and provisioning are the same walk.
- *Operator raised Q-A* (election on multi-candidate broadcast) and *Q-B*
  (incomplete — "termlink or termlink").
- *Agent reflection logged in this artifact:* mapped the model to actor-paths /
  DNS / OTP-supervision; identified that the primitives largely exist and the gap
  is the addressing scheme + escalation walk; flagged the discovery-vs-
  provisioning merge as the key tension; flagged identity-label vs authenticated-
  identity as an unresolved fork with large build implications.

**2026-09-06 — round 2 (agent reflection + questions back).**

- *Agent proposed F1–F5* (see Reflection findings above): the load-bearing one is
  F1/F2 — level 5 is a predicate over level 4, so circuit=session and
  role=per-message label. Named the model as actor-path + OTP-supervision +
  connection-oriented-over-pubsub, i.e. borrow proven mechanics.
- *Agent flagged the discovery/provisioning merge* as the tension to resolve first
  (F4), framed as a sovereignty gate.
- *Agent's three questions back to operator:*
  1. Complete Q-B ("termlink or termlink").
  2. Is a hub 1:1 with a host, or can a host run several? (If 1:1, levels 1–2
     collapse to a compound root and the taxonomy is effectively 4 levels.)
  3. Where is the highest level an agent may auto-provision without a human?
     (Agent instinct: resolve freely everywhere; auto-provision sessions under
     policy; require authority for hubs/projects.)
- *Agent's open reaction:* does "circuit = session, label = role" (F2) match
  operator intent, or is a circuit meant to follow an *agent profile across
  sessions* — a stickier identity than the session it currently runs in? That one
  choice ripples through the whole design.

- *Operator asked* whether we should be capturing this so the dialogue/decisions
  are not lost. → Confirmed already captured here (T-3287 artifact + Dialogue
  Log); this round-2 update brings the file current with the chat, which was one
  exchange ahead.

**2026-09-06 — round 3 (operator rules the instance-vs-role fork).**

- *Agent grilled* the tension between "reconnect to the same circuit ID" (sounds
  instance) and "climb the ladder to re-provision agent X" (sounds role), forcing
  a single ruling via two concrete scenarios (profile switch; S1 dies, S2 rises).
- *Operator ruled (D1):* instance-identity. Circuit = channel to a specific
  agent-instance at level 5; circuit ID transient (caller-retained handle, not a
  persistent address); reconnect = optimistic fast-path, else climb the ladder and
  establish a NEW circuit. The ladder yields a working equivalent, not the same B.
- *Agent retracted F1/F2* (its own proposals) as overridden by D1, and delivered
  the payoff it had promised: D1 makes T-3286 correct unconditionally (distinct
  instances must never collapse).
- *Agent's follow-up grill (D1-open):* does a profile switch kill the level-5
  agent-instance? D1 is only consistent if yes (agent-instance =
  (session, profile-epoch), independently mortal). Awaiting ruling.

**2026-09-06 — round 4 (operator gives every level a durable name).**

- *Operator walked the durable name per level:* host = FQDN; hub = "I need to be a
  termlink hub" (the entry point, singleton-by-type); project = its root directory;
  instance = termlink's unique session id; agent = an @-name established by a
  *bootstrap act* (creating/collaborating-to-create the agent gives it its durable
  name). → captured as **D2**.
- *Operator pinned a slip the agent had made:* "you said another instance for
  another project — it's another instance for the SAME project." Multiple instances
  can run for one project under one hub; each has its own distinct termlink id,
  visible in `termlink list`. Absorbed.

**2026-09-06 — round 5 (passive project; the composite; the two-layer synthesis).**

- *Operator's structural insight:* the project (L3) is **not an active component** —
  it is "something uniquely addressable in the sense it's addressable in the file
  path it takes." AEF is bound to its root dir and not allowed out (T-559). → the
  ladder rung for L3 is "ask the HUB", never "ask the project"; 4 actors + 1
  address, not 5 actors.
- *Operator proposed a composite circuit ID* (L1 FQDN / L2 hub / L3 path / L4
  session / L5 @name) and claimed it is "easily derivable from static instance
  information", asking to reflect and agree.
- *Agent caught the merge:* the composite names TWO things — the durable name (the
  correspondent, no session) and the circuit id (durable name + session, the
  actor). Split them (see D2 refinement). Mapped to DNS: durable name = the
  hostname/A-record NAME; circuit id = the resolved live binding. This also
  sharpens the two-layer identity from earlier rounds: correspondent (continuity,
  stamped) vs actor (discriminator, keys the claim).
- *Agent forced the state question (open):* D1's ladder buys availability but the
  re-provisioned instance has amnesia — durable name ≠ durable state. WHERE does
  circuit/relationship memory live? Operator had earlier framed re-provisioning as
  "that's anti-fragility, right?" — agreed it is (availability antifragility); the
  agent's point is the *memory* half is a separate, unanswered question. Logged as
  the "availability vs memory" open fork.
- *On simultaneous instances wearing agent X* (I1 and I2 both present @X): operator
  ruled the resulting task/conflict problems belong at the **AEF layer, not
  termlink** — but asked the agent to challenge that. (Standing challenge, not yet
  worked: instance-identity D1 says I1 and I2 are DISTINCT correspondents even
  though they share a durable name @X, so the coordination layer must key on the
  circuit-id/actor, not the durable name — which is exactly the discriminator role
  the two-layer split assigns it. So D1 + D2 already contain the tools; the open
  bit is whether AEF or termlink enforces the mutex. Consistent with reusing
  `channel claim` at the actor layer — F5.)

**2026-09-07 — round 6 (slash-vs-@ verification).**

- *Operator claimed* all LLM harnesses use `/` for agents and asked to be
  challenged / verified. *Agent verified (web search) and challenged:* slash is
  universal for COMMANDS, not agent IDENTITY; identity is @-mention where it's
  addressable. → **F6**. Proposed `@agent-name` as the leaf so `/` (level
  separator), `@` (identity), `:` (session) each mean one thing. Awaiting operator
  decision.

**Next in dialogue:** operator to (a) decide the agent leaf notation — `@name` per
F6, or deliberate divergence; and (b) rule D1-open (profile-switch liveness). Then
the still-open queue, one at a time: the **availability-vs-memory** state fork
(where circuit/relationship memory lives — likely the passive project, per D2);
Q-B completion; hub 1:1-with-host or not; auto-provision authority line (F4
sovereignty gate); and the AEF-vs-termlink mutex enforcement for two instances
sharing one @name (round-5 standing challenge).
