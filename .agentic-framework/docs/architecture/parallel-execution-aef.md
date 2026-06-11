---
title: "Architecture — Parallel Execution: AEF Orchestration Layer"
status: design captured, pre-build
source: operator paste during session S-2026-0610-0915 on 2026-06-10
authoritative_owner: this repo (999-Agentic-Engineering-Framework)
companion: docs/architecture/parallel-execution-substrate.md
landing_task: T-2302
landed: 2026-06-10
---

# Architecture — Parallel Execution: AEF Orchestration Layer

Status: design captured, pre-build. Companion: *Architecture — Parallel Execution:
TermLink Substrate Layer*, which owns the collaboration seam and supplies the
primitives this layer depends on.

This is an architecture *decision record*. Each decision carries the alternatives
explored, why the losing options lost, and — where a decision was forced by a concrete
substrate fact rather than chosen — the forcing chain. A reader should be able to
reconstruct *why*, not just *what*, and should not re-litigate settled forks.

## 1. Purpose

Define the AEF-layer design for concurrent task execution over ring20: the
orchestrator, the agent harness (how a running agent notices the world without being
disrupted), and the sidecar listener. This layer sets execution *policy* and consumes
the substrate's *primitives*.

## 2. Unit of parallelism: disjoint write-sets, not shared arcs

**Decision.** The unit of parallelism is **tasks with disjoint write-sets**. Sharing an
arc is neither necessary nor sufficient.

**The path to this.** The starting intuition was "we definitely want multiple agents on
the same arc." That was refined, not rejected: the arc is the shared *intent*; the tasks
are the parallel *units*. Multiple agents on disjoint tasks that share an arc is the
right picture — and it is the *stress case*, because same-arc tasks are simultaneously
the most desirable to run together and the most likely to overlap. A later correction
went further: parallelism does **not** require a shared arc at all. Two tasks in
different arcs touching non-overlapping files are perfectly parallelizable — arguably
*more* safely, since cross-arc tasks are less likely to collide. So "same arc" is struck
as any kind of requirement; disjointness is the only one.

**The reusable insight, and a rejected instinct it validates.** The operator's standing
hesitancy about running two agents on *overlapping* tasks is correct and is now a
principle: when two tasks cannot be given disjoint write-sets, the answer is to **split a
task**, never to run them concurrently and reconcile. The corollary, which recurs at
every level of this design: **high coordination volume between two agents is a
decomposition smell** — it means the boundary was drawn in the wrong place. Safety is a
decomposition property, designed in at task-shaping time, not a merge problem solved
afterward.

## 3. Disjointness policy: conservative at launch (forced)

**Decision.** Before greenlighting two tasks to run concurrently, the orchestrator
requires *provably* disjoint write-sets, derived from declared `artifactsWrites` globs
and `depends_on` ordering; when disjointness cannot be proven, it serializes. This is
the launch policy.

**Alternatives explored.**
- *Optimistic:* parallelize unless overlap is obvious; let merges catch the rest.
- *Conservative:* parallelize only when provably disjoint; err toward serial.

**Why conservative is forced (the CSMA/CD reasoning).** Optimistic is only *safe* with
*physical* collision detection — the property that makes Ethernet CSMA/CD work is that
you cannot fail to notice a collision on the shared medium. The substrate has no
filesystem-write observation, so the only available collision signal is honour-system
announcements, which can be forgotten or read too late, producing undetected collisions
that surface as ugly governance-plane merge conflicts. So optimistic-on-honour-system is
unsafe. The asymmetry seals it: being too conservative wastes some potential concurrency
(a mild, performance-only cost); being too optimistic corrupts machine-maintained state
(severe). Bias to the cheap error.

**The two-step that must not be collapsed.** Conservative remains the launch policy
**even after** the substrate ships filesystem-write observation. That capability only
creates the *option* to move to optimistic — it gives optimistic the physical detection
it needs. Flipping is a *later, gated* decision, owned by the human, against criteria
defined *in advance* (see §6) so the bar is set before anyone is tempted to flip
prematurely. "We built write-observation" and "we are now optimistic" are two different
events, deliberately separated.

## 4. The orchestrator: active dispatcher, not passive queue (forced)

**Decision.** The orchestrator is the sole task creator and ID allocator, the task-graph
authority, and an *active* dispatcher that assigns work explicitly to chosen workers. It
builds its own idle/busy model and serializes integration through the hub.

**Why sole creator/allocator.** Making the orchestrator the only entity that creates
tasks and allocates IDs eliminates creation races and gives it the full in-flight
picture it needs to make parallel-vs-serial decisions. Agents populate their own task
files (one file per agent, no collision); cross-cutting governance state routes through
the hub (see §5 of the substrate doc).

**Why active dispatch and not pull (forced).** The clean-looking design — post tasks to a
queue topic, let idle agents pull the next eligible one, self-balancing across
heterogeneous hosts — was the initial lean ("pull, for a mixed-hardware homelab").
The substrate findings killed it: TermLink is push-only, has *no* claim/exclusive-
delivery, and topics are *broadcast*, so two agents subscribed to a work topic would
*both* see and grab every task. With no "exactly one consumer takes this" primitive,
a passive pull-queue is unsafe. Therefore the orchestrator must hold the graph and assign
explicitly. It also must build its *own* idle/busy model, because the hub keeps no such
registry (liveness is client-side from heartbeats). This is more work than a pull-queue,
but it is forced, and it is consistent with the orchestrator already being the sole
task-graph authority. (Once the substrate's claim and pull primitives land, pull *becomes*
possible; the orchestrator stays the authority regardless.)

**The "favor parallelization" mode is not a separate machine.** It is merely the
tie-breaker bias the orchestrator applies in the *ambiguous* cases — nothing more. The
hard inputs are already present: `depends_on` gives ordering, `artifactsWrites` gives
write-set overlap; two ready tasks with no dependency and disjoint writes are
parallelizable by construction.

**Integration and the un-partitionable residue.** Completed work is integrated through a
*serialized integration queue at the hub*, not self-merged by agents. (On ring20 this is
also forced rather than chosen: a worker on one host pushes its branch to the hub's
remote and the hub — the only party that sees all incoming branches — integrates.) Files
that cannot be write-set-partitioned regardless of decomposition (`Cargo.lock` being the
canonical case) are handled by **hub-owned regeneration after merge**, because their
correct state is derivable, not authored.

## 5. Agent reactiveness: cooperative polling, not interruption

This is the part that was genuinely under-solved before and got the most scrutiny.

**The real problem, correctly named.** An agent mid-turn is single-threaded and
*uninterruptible* — it is running a reasoning/tool loop with no interrupt handler. The
question is not "how do agents hear" but "where in the loop is the *yield point* at which
an agent can safely notice the world without being derailed."

**Alternatives explored.**
- *PTY injection (the prior attempt).* Inject a message into the agent's active terminal
  session. Rejected: it delivers into the input stream the agent is *currently
  consuming*, so it either corrupts a mid-tool action or jams a buffered keystroke that
  disrupts flow. It is an attempt to make an uninterruptible loop preemptive, and
  preemption is the wrong model for this substrate.
- *Cooperative flag-polling (chosen).* The agent polls an out-of-band flag at its own
  safe yield points and decides when to switch attention. This is the interrupt-vs-poll
  distinction from systems design: for an uninterruptible single-threaded loop,
  cooperative polling is the *only* safe model, because the receiver — the sole party
  that knows it is at a safe point — owns the decision to yield. The analogy that
  anchored it was the token-usage guard: a cheap local read at natural boundaries, a
  cheap signal that flips.

**The doorbell survives as intent, dies as implementation.** The existing doorbell idea
(something local nudges the agent) is kept; its PTY-keystroke implementation is
discarded. A critical sub-point caught during design: the flag must be written
*out-of-band relative to the agent's execution stream*. Writing the flag *via* PTY
injection would rebuild the very disruption it was meant to remove — the keystroke still
lands in the consumed input stream. So the flag is a file / KV entry, not a keystroke.

**The flag-writer is a dedicated sidecar, and it is deterministic — not `claude -p`.**
The clarified design is a separate process per agent whose only job is transport and
signaling: hold the TermLink client connection, receive messages, write the flag. The
choice of a *deterministic* listener over an LLM-backed one is not a cost compromise —
it is correct on three axes at once. Logic: holding a socket and flipping a bit needs no
reasoning. Cost: no per-message dollars. Responsiveness: a free process can poll the hub
aggressively and react in milliseconds, whereas an expensive `claude -p` listener would
be woken infrequently to save money, reintroducing the latency this design exists to
kill. The fact that the LLM version is expensive is the signal that it was overkill.

**The agent checks its own ears (chosen over spawner-supervision).** A sidecar introduces
a new failure mode that did not exist with a single agent: if the listener dies while the
agent lives, the agent polls a flag nobody updates and goes *silently deaf* — worse than
having no listener, because it believes it can hear. Two handlings were weighed:
- *Spawner supervises the pair as a unit.* An outside parent watches both pids and
  kills/restarts together. Clean separation, but safety then depends on the spawner being
  alive and reliable — the liveness problem moves up a level.
- *Agent self-checks its ears at each yield point (chosen).* The sidecar regularly writes
  a **heartbeat timestamp**; at each yield point the agent reads the flag *and* computes
  `now − last_heartbeat`. Over threshold ⇒ listener dead ⇒ the agent is deaf ⇒ it
  **stops before acting** (re-spawns the listener or refuses to proceed). Chosen because
  it degrades safely: safety depends only on the agent itself — the one thing certainly
  running when an agent is about to act — and deafness is discovered at the moment it
  matters most, immediately before a write a collision warning might have prevented.
  "flag = 0" is no longer trusted alone; it is trusted only when "and my listener is
  provably alive" also holds. Staleness-of-timestamp is a liveness *proof* (it also
  catches a hung-but-alive listener that `kill(pid,0)` would call alive). Its cost is
  honesty about scope: "verify listener alive" becomes a mandatory part of every agent
  harness's poll contract.

**Sender-side detection is the symmetric backstop.** A dead recipient listener produces
no acknowledgment, so the *sender* detects the same failure independently and retries —
two independent detectors of the one dangerous mode (receiver via stale timestamp, sender
via missing ack). (The ack-with-retry is substrate build-work; TermLink receipts are
advisory today.)

## 6. Open questions (AEF side)

- **Yield-point granularity.** Where the agent checks flag and ears — between tool calls,
  only at task boundaries, or before every file write — sets the *whole system's*
  responsiveness and lives in the harness. Too coarse and a collision warning arrives
  after the conflicting write; too fine and it thrums. Leading candidate: **before every
  file-write tool call**, a natural, cheap, semantically meaningful point — exactly when
  a "do not write there" message matters most, and the granularity a collision-prevention
  goal demands. Unresolved.
- **Heartbeat tick vs. death-threshold gap.** The gap between how often the sidecar writes
  its timestamp and the staleness threshold *is* the maximum window during which an agent
  may act while deaf. It must be sized against the cost of one wrong write. Lean: 5 s
  tick / 30 s threshold (six missed beats) as a start; tighten if collision-prevention
  needs faster. Unresolved number.
- **Flag shape.** Single dirty-bit ("something waiting, go look") vs inline
  priority/sender. Lean: dirty-bit + a single highest-priority byte — enough to decide
  *whether* to yield without a fetch, cheap enough not to bloat the sidecar's hot loop;
  details fetched on yield. Unresolved.
- **Scale ceiling.** Ring20's agent ceiling and the tolerable hub-restart pause are a
  human input that also drives the substrate's federation decision. Until answered, a
  single supervised durable hub is assumed (durable logs mean a restart loses nothing,
  only delays).
- **Optimistic flip criteria.** What evidence about write-observation's real behaviour
  would justify moving conservative→optimistic — defined now, co-discovered with the
  substrate layer, so the bar precedes the temptation.

## 7. Coordination model: persistent hub topics, never direct channels

**Decision.** Agents coordinate through **persistent hub topics**, never through
negotiated agent-to-agent channels.

**Why (the same fork as the substrate's topology decision, from the AEF side).** A direct
channel was proposed for efficiency, bottleneck, delay, and fragility reasons. A
persistent shared topic gives the permanence and near-direct-channel efficiency
(append-and-tail) while remaining durable, ordered, hub-visible, and resilient to either
party dying — and it preserves the star and the *independence* that makes parallelism
work, because spokes that share nothing stay parallel and the moment two hold a private
channel they couple and serialize. Direct channels would also multiply fragility (many
links, no central replay, silent partial-partition divergence). The single-point-of-
failure worry about the hub is answered by making the hub durable, restartable, and (only
if scale demands) replicated/federated — never by dissolving it into a mesh. If two
agents ever appear to need such high-frequency coordination that even a topic feels too
slow, that is the decomposition smell again: split the task, do not build a faster
channel.

## 8. Dependency on the substrate

This layer builds against the *contracts* published by the substrate (claim/exclusive
delivery, idle/busy registry, pull/assign verb, reconnect/outbound queue, symmetric auth,
persistent presence, typed git surface) and against the substrate's append-log for all
governance-plane writes. Per the substrate document's collaboration seam, it does not
guess the shape of these primitives or wait on their implementation — it builds to the
contract — and it **signs off** each delivered primitive as actually usable for dispatch
before accepting it (producer ≠ judge: the consumer that can see the need validates the
producer's output). The soft items are co-discovered: write-observation shape,
un-partitionable-file regeneration mechanism, and the optimistic-flip criteria. Rising
consultation volume on a hard dependency means re-contract, not grind.

## 9. Invariants (must not be violated)

Strict star; coordination via persistent hub topics, never direct channels. Spokes never
write the governance ledger directly. Conservative launch; landing write-observation does
not by itself enable optimistic — the flip is a separate gated decision. Deterministic
sidecar with no language-model call; no terminal injection for delivery; safe-degrade on
deafness (a deaf agent stops before acting, never proceeds on an unverified "all clear").
High coordination volume between two agents is treated as a decomposition smell.

## 10. Grill Me

This ADR is grillable against the project's domain language and any downstream design
work that cites it. Use to drill load-bearing decisions *before* a downstream inception
treats them as settled.

**Entry point:** `/grill-with-docs` (skill: `.claude/skills/grill-with-docs/SKILL.md`)

**Primary grill targets** — flag any answer that cannot be defended in one sentence:

- **§2-3 disjoint write-set decision.** Is "split a task, never reconcile" actually
  achievable for the task classes we ship today, or is it aspirational? Drill: name three
  recent tasks that would have had to be split.
- **§3 conservative-launch forcing chain.** Reads load-bearing. Drill the asymmetry
  argument: if both errors were equally cheap, would conservative still win? If yes,
  why? If no, the case rests entirely on cost asymmetry — verify that.
- **§4 active-dispatch forcing chain.** Does it still hold once a claim primitive lands?
  The ADR claims it does (the orchestrator stays the authority regardless). Drill: what
  exactly stops a pull-queue from re-emerging the moment exclusive delivery exists?
- **§5 cooperative-poll yield point.** "Before every file-write tool call" is the
  *leading* candidate, not the chosen answer. Drill: is that empirically the right
  granularity, or is it a guess wearing 5 paragraphs of justification? What's the
  experimental setup that picks the actual number?
- **§5 self-check-ears.** Heartbeat staleness as liveness proof. Drill: 5s tick / 30s
  threshold gives a 6-beat window during which an agent may act while deaf. What's the
  cost of one wrong write inside that window, and does the math still favour this design
  at homelab-typical write rates?
- **§7 persistent-topic-not-direct-channel.** The "topic IS the channel" claim. Drill:
  what's the largest concrete coordination need that would actually feel slow over a
  topic? Name it. If you can't, the claim survives unchallenged.
- **§8 substrate contracts.** Which contracts are *currently* underspecified beyond
  "name + intent"? Those are the ones rising consultation volume will betray (§9 smell
  in the substrate doc).

**Companion ADR:** [`parallel-execution-substrate.md`](parallel-execution-substrate.md)
(TermLink-authoritative reference copy in this repo; grill the substrate side there).

**Scoping inception that consumes this ADR:**
[`T-2303`](../../.tasks/completed/T-2303-scoping-inception--parallel-execution-ar.md)
(the IW-1..IW-5 spikes operated over the decisions in §2-§9 here; operator GO'd
2026-06-10 commit `989fc1e6e`, the cluster of downstream inceptions began with
[`T-2323`](../../.tasks/active/T-2323-aef-ic-1-yield-point-granularity-substra.md)
(AEF-IC-1, yield-point granularity, §6.1) and
[`T-2324`](../../.tasks/active/T-2324-aef-ic-2-disjoint-write-set-policy.md)
(AEF-IC-2, disjoint write-set policy, §6.2 + §3); both currently operator-parked
captured/later awaiting spike dialogue per their `## Recommendation` blocks).
