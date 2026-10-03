# External review brief — T-3751: function + instance labels at every address level, and respawn-by-function fallback

**You are an independent design reviewer.** You did not write this design. Read the
whole brief, then answer the questions in §8 in the format in §9. Be adversarial:
the most useful review names what will break, with a concrete scenario. Where you
agree, say so in one line and spend your words where you disagree.

All file paths are in `/opt/999-Agentic-Engineering-Framework` (read-only access is
fine; you do not need it — the brief is self-contained, but you may verify).

---

## 1. Purpose and background

### 1.1 AEF — Agentic Engineering Framework (this repository)
A provider-neutral governance framework for AI coding agents working in software
projects (`FRAMEWORK.md`). Core principle: *nothing gets done without a task*,
enforced structurally by hooks and gates, not by agent discipline. Authority model:
**human = sovereignty, framework = authority, agent = initiative** — agents propose,
humans decide. Four constitutional directives, weighted: Antifragility (9),
Reliability (7: predictable, auditable, *no silent failures*), Usability (5),
Portability (3: no provider/language/environment lock-in).

AEF is **vendored into consumer projects** (`.agentic-framework/`) and upgraded with
`fw upgrade`. Each consumer runs its own Claude Code (or other) agent sessions under
AEF governance. Today on one host (`.107`) there are, among others:
- **999-AEF** — the framework repo itself (the framework maintainer agent);
- **010-termlink** — the TermLink project (Rust);
- **055-agentic-fleet-cockpit** — a fleet cockpit app that supervises agents;
- **832-Workflow-designer** — a BPMN workflow designer;
- **050-email-archive**, **001-CashWeb-…-integration**, and others.
Agents in these projects **consult each other** constantly: bug reports upstream to
AEF, fixes and patches downstream, review requests, design negotiation between AEF
and TermLink. The operator (one human) supervises all of them and is the bottleneck.

### 1.2 TermLink (010-termlink)
A machine-wide Rust tool for cross-terminal session communication: sessions register
(`termlink list`), a **hub** per host brokers **channels/topics** (append-only,
offset-addressed message logs), PTY inject/output for driving terminals, KV, events,
file transfer, remote (cross-host) calls. Deliberately machine-wide, not vendored
per project, because discovery uses system-level sockets. AEF wraps it (`fw termlink`)
for dispatching worker agents (`claude -p` in a TermLink session) and for agent-to-
agent messaging.

### 1.3 The sidecar (arc-011) — how agents message each other
Design of record: `docs/architecture/sidecar-target-architecture.md` (D-645, from
inceptions T-3396 / T-3397). Each agent runs a **sidecar** with a local **HTTP
receiver**. Round trip as designed:
1. Sender posts to the recipient's receiver → receiver stores message + flag, returns
   **RECEIVED** (sender-side receipt).
2. A **30 s watcher tick** (configurable) checks the flag; **urgent** messages are
   injected into the agent's terminal immediately; non-urgent only when the agent's
   **ready-for-input** flag is up (Stop hook sets it, UserPromptSubmit clears it).
3. Injection confirmed from transcript evidence → **HANDED_OVER** back to the sender.
4. The agent's answer, sent with `--in-reply-to`, → **REPLIED**.
Fallback when no receiver is reachable: post to the recipient's **hub inbox topic**
(`inbox:<hub>/<project>`), read by the recipient at its next prompt.
Requirement register R1–R15 (§7 of the architecture doc), e.g. R3 30 s tick, R5
urgent bypass, R6 bidirectional ack, R7 liveness self-probe, R14 every agent runs a
sidecar, R15 always-on listener per agent session.

---

## 2. The ratified address model today (T-3287, Sep 2026)

Source: `docs/reports/T-3287-identity-taxonomy-circuit-model.md`, `lib/aef_address.py`,
`lib/sidecar/circuit.py`.

Five levels: **host / hub / project / session / agent**.

**D1 (ratified)** — identity is INSTANCE-identity, not role-identity. A circuit is a
channel to a specific agent instance; its id is transient. On a dead endpoint,
*climb the ladder (5→4→3→2→1) until an ancestor can re-provision, then establish a
NEW circuit with a NEW id — "a working equivalent, not the same B".*

**D2 (ratified)** — every level has a DURABLE NAME:

| Level | Durable name | Nature |
|---|---|---|
| Host | FQDN (or IP) | active, DNS-static |
| Hub | hub id, one hub per host | active, singleton |
| Project | root directory path | **passive** — a location, never callable |
| Session | TermLink instance id | active, transient |
| Agent | `@agent-name` | active, project-scoped durable name |

Two strings: **durable name** (correspondent, no session) and **circuit id** (durable
name + session = the live actor).

**D3 (ratified)** — wire grammar V9:
`aef::host=<fqdn>::hub=<H>::project=<path>::session=<S>::@<agent>::`; a path form
`//host/hub/project/session/agent` is used by the sidecar on the wire, where the
project slot is the folder **basename** (inconsistent with V9's full path — found
2026-10-03). Path elision is display-only.

**D4** — circuit lifecycle three-state; invalidation only on positive proof of death.
**D5** — re-provisioning a missing child is **pre-authorized self-heal** (Tier-3).
**D6** — hub is 1:1 with host by default; `hub=` optional.
**D7** — two instances wearing one `@name` in one project serialize writes via a
per-project single-writer claim.

Code fact: the V9 `climb()` drops agent → session → project → hub, host is last
(`lib/aef_address.py:40`); the sidecar never climbs at send time, its lowest emitted
address is `<hub>/<project>`, the project's durable inbox (`lib/sidecar/circuit.py:15`).

**Decided 2026-10-03 (T-3751 IW-1, operator ruling C):** the project slot carries the
**minted project id** (`pid-<16 hex>`, stored in the committed `.framework.yaml`,
created once, shared by every clone; a fork is a new project — T-3534), in both the
path and V9 forms; the readable project name is display-only.

---

## 3. What went wrong in practice (fallback communication experience)

Verified incidents, most recent first:

1. **Receiver down, no receipts (2026-10-03).** AEF's own receiver was not running
   (started by hand, nothing supervised it). Every sender fell back to the hub topic.
   The topic-reading path (`lib/sidecar/inbox.py`) sends **no receipt at all** — so
   055 and 832 saw only HUB_ACCEPTED for a day while AEF had read and answered.
   832's sender escalated nudges to rung 4; the fleet cockpit reported AEF as
   unresponsive.
2. **Replies not bound to the message.** Replies were threaded by conversation but
   not by `client_msg_id`; senders could never mark REPLIED, so nudging never stopped.
3. **Delivered at the hub ≠ delivered to the agent (010-termlink, 2026-10-03).**
   TermLink's notify sidecar receipted mail as delivered, but that agent had no wake
   consumer; it heard nothing for a day.
4. **Per-project ready flag (T-3745).** Two Claude sessions in one project (a fleet
   agent and the operator's terminal) shared one ready flag: the watcher would have
   typed into the busy session, and HANDED_OVER was credited to whichever session
   prompted next. Fixed 2026-10-03: ready flag keyed per session.
5. **Shared signing identity (T-1448).** All agents on a host sign as one TermLink
   identity, so a reply addressed "back" wakes the wrong agent. Fix is TermLink's
   (per-agent identity); meanwhile AEF distinguishes by circuit id.
6. **The old pickup channel (`framework:pickup`).** 258+ posts, one consumer receipt
   (up to offset 81); ~70 posts addressed to AEF had no reader evidence. Retired in
   favour of the sidecar (T-3631 GO).
7. **Push vs inject (S-2026-0412).** Two async "push" messages got no response;
   switching to direct PTY inject got an answer in seconds. `send-file` returning
   ok means "hub accepted", not delivered.
8. **Orphans.** Test receivers survived 22 h in the host registry; dead entries made
   senders believe a receiver existed.
9. **Latency measured (2026-10-02):** peer send → reply median **49 min**, max
   **278 min**. Operator's expectation: receipt "pretty quick", pickup within one
   30 s tick when idle.

Pattern across all of these: **a state was reported at one level ("accepted",
"delivered", "ready") that was true at that level and false at the level the sender
cared about.**

---

## 4. The proposal under review (operator, 2026-10-03, verbatim intent)

### 4.1 Two labels at every level
Every level carries a **function label** (static: what it is) and an **instance
label** (dynamic: which running one):

| Level | Function label (static) | Instance label (dynamic) |
|---|---|---|
| Host | FQDN | IP address (can change) |
| Hub | hub name (assume one per host for now; maybe hub1..n, named hubs, or one hub per project — undecided) | hub id |
| Project | project id `pid-…` (fixed) | **project instance id** (new) |
| Session | **session name** (new) | session instance id |
| Agent | agent name, e.g. `research` | **agent instance id** |

### 4.2 Fallback by function, with respawn
- A message for agent `research` whose **instance** died → **spin up a new
  `research` agent** that ingests the context and follows up on the message.
- A message for a **project instance** that died → spin up a new instance that
  continues from the saved context.
- **Session is a preference, not a requirement:** delivering back into the same
  session keeps its context (efficiency); a new session in the same project gives the
  same functionality (effectiveness). Context is saved often to make this safe.

### 4.3 Agent's reading of how this relates to what is ratified
- Point 4.2 is ratified D1 + D5 applied (re-provision a working equivalent).
- What is new is 4.1: an explicit function label at every level — the thing a
  "working equivalent" must be matched on. It refines D1 (instance identity) by
  adding role identity *beside* the instance id, and changes D2 (project gains an
  instance id and stops being purely passive; session gains a name).
- Proposed fallback (agent's draft, not ruled): resolve by instance first; if the
  instance is dead, respawn by function (D5); **never fall back across projects**
  (010-termlink agrees); the sender's receipt names the level that actually took the
  message.

---

## 5. Constraints

- No silent failures (Reliability directive). Every hand-off must be observable.
- One human operator; agents propose, the human decides. Respawning an agent costs
  money and context; Tier-0 actions (destructive) always need the human.
- Must work across hosts (FQDN), across vendors (Claude, Codex, others), and for
  consumers on older framework versions during migration.
- TermLink is a separate project with its own operator; the address must be agreed
  by both sides (it is about to key agent wake-up on the address — their T-3325).

---

## 6. Open sub-decisions (for context — the operator rules on these)

- **2a** — the two-label model: which labels exist per level, and which are used for
  ROUTING vs only for DISPLAY/MATCHING.
- **2b** — the fallback: order, respawn conditions, stop rule, receipts.
- IW-2 — migrating inbox topic names from folder name to `pid-…` without loss.
- IW-3 — resolving a human name (`--to 832-Workflow-designer`) to an id: who owns that
  directory (AEF or TermLink).

---

## 7. Known tensions the agent sees (check these, and find others)

1. **What a "function" is for a session.** Sessions are created per human conversation
   or per dispatched worker; is a session name a real role, or just a label?
2. **Respawn authority.** D5 pre-authorizes provisioning, but spinning up a paid model
   on an arbitrary inbound message is a cost and abuse vector (any peer can trigger
   spend).
3. **Exactly-once.** Two live instances with the same function (two `research` agents,
   two checkouts of one project on one host sharing `pid-…`) — who takes the message?
4. **Context ingestion.** "Ingest the context and follow up" assumes the context is on
   disk and findable from the message; is the conversation thread enough?
5. **Host FQDN vs IP.** Is the IP ever needed in the address, or only in resolution?

---

## 8. Questions for you

Q1. **Is the two-label (function + instance) model right?** For each of the five
    levels: keep both labels, drop one, or merge? Is anything missing (e.g. a vendor/
    model label, a role-vs-name distinction for agents)?
Q2. **Routing vs display.** Which labels should appear in the wire address used for
    delivery, which only in metadata, which only on display?
Q3. **Fallback order and stop rule.** Propose the exact algorithm, step by step, from
    "full address does not resolve" to "delivered / respawned / bounced". Where must it
    stop, and what does the sender see at each step?
Q4. **Respawn safety.** When may an inbound message cause a new agent or project
    instance to be started? Who pays, who authorizes, what rate limits, what if the
    message is malicious or mistaken?
Q5. **Exactly-once and conflicts.** How are two live instances of one function handled?
Q6. **Lessons from §3.** Which incidents does this model prevent, which does it leave
    open, and does it introduce a new class of the "true at one level, false at the
    level the sender cares about" failure?
Q7. **Prior art.** Name the closest established designs (e.g. Erlang/OTP supervision
    and registered names, actor systems like Akka/Orleans virtual actors, DNS +
    service discovery, SIP/XMPP addressing, email MX fallback) and what each says we
    should copy or avoid.
Q8. **Your recommendation.** Adopt as proposed / adopt with changes (list them) /
    reject — with the single most important reason.

## 9. Output format

```
VERDICT: ADOPT | ADOPT-WITH-CHANGES | REJECT — <one line>

Q1 … Q8: numbered answers, each starting with your position in one line, then the
reasoning. Cite the brief section (§n) or file you rely on.

TOP 3 RISKS: numbered, each with a concrete failure scenario.

WHERE I DISAGREE WITH THE AGENT'S READING (§4.3, §7): bullets, or "none".
```
Keep it under 2,500 words. Write plainly.
