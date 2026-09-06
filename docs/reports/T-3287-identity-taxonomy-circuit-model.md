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

**Next in dialogue:** operator to (a) confirm/replace the taxonomy as stated,
(b) complete Q-B, (c) weigh in on the discovery/provisioning boundary and whether
`agent_id` is a label or an authenticated key.
