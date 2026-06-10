---
proposal_id: PROP-T-2303
source_repo: 999-Agentic-Engineering-Framework
source_task: T-2303
source_arc: arc-011 parallel-execution-aef
target_repo: termlink (DimitriGeelen/termlink)
status: draft (NOT YET SENT — operator approval required to dispatch via termlink remote inject)
created: 2026-06-10
mirrors_pattern: T-1804 (docs/proposals/T-1804-cross-agent-conversation-substrate.md)
---

# Proposal: cross-repo coordination — parallel-execution substrate primitives

## Context (read this first)

The Agentic Engineering Framework (AEF) has captured an architecture decision record for moving from single-agent / single-writer execution to multiple agents executing tasks concurrently across ring20, coordinated through TermLink. Two companion ADRs were authored in prior design sessions and landed on disk this session:

- **AEF Orchestration Layer** — `docs/architecture/parallel-execution-aef.md` (999-AEF authoritative). Covers orchestrator-as-active-dispatcher, agent harness with cooperative-poll yield points, sidecar listener, governance-plane centralisation.
- **TermLink Substrate Layer** — `docs/architecture/parallel-execution-substrate.md` (TermLink authoritative; we hold a reference copy). Covers strict-star topology, append-log governance plane, two-plane split, collaboration seam (§9), and the **required-primitive build manifest (§6)**.

A scoping inception (T-2303 / arc-011 `parallel-execution-aef`) is now open AEF-side. **Spike 3** of T-2303 — the load-bearing one — is to establish first-contact with TermLink-side and confirm the §8 substrate-contracts shape *before* AEF-side downstream inceptions (§2-3 disjoint write-sets, §4 active dispatcher, §5 sidecar+harness) begin treating those contracts as fixed.

Per substrate ADR §9 (producer ≠ judge), AEF cannot self-validate; TermLink-side must confirm what it can ship, in what order, with what RPC signatures.

## What we need from TermLink

Per substrate ADR §6 + §9, the **hard dependencies** (contracted up front, built independently after) are:

| # | Primitive (§6 number) | Why AEF needs it |
|---|------------------------|------------------|
| 1 | Exclusive-delivery / claim semantics | Without claim, two subscribers to a "work" topic both grab a task. AEF's active-dispatcher design works around this *today*; pull-queues require it. |
| 2 | Hub-owned idle/busy registry | AEF needs a reliable "who is free" picture to assign work. Heartbeats-via-topic + client-side classification doesn't compose with multi-orchestrator. |
| 3 | Pull/assign verb | RPC for the orchestrator to hand a unit of work to a specific worker as a first-class operation (today's push is sender-picks-recipient). |
| 5 | Client-side reconnect + outbound queue | A worker that finishes during a hub blip and posts "complete" today loses the message. Governance plane cannot silently drop completion. |
| 6 | Symmetric auth across transports | Same-host UDS auth-bypass vs cross-host HMAC-TCP — the sidecar listener AEF §5 wants is a long-lived privileged process that needs one trust model. |
| 7 | Hub-persistent presence + circuit-breaker state | Liveness resets to "everyone unknown" for one heartbeat interval after every hub restart today. AEF's "self-check ears" depends on liveness signal continuity. |
| 8 | Typed agent-launch surface aware of source-tree handoff | `agent.checkout(ref)`, `agent.commit(scope)`, `agent.publish(branch)` — make code-plane vs governance-plane a substrate concept, not a shell convention. |

And the **keystone**:

| # | Primitive | Why AEF needs it |
|---|-----------|------------------|
| 4 | Filesystem-write observation | Physical collision detection. *Without* this, AEF launch policy is conservative (disjoint-write-set proof gate before parallelism). *With* this, AEF gains the *option* to flip to optimistic — a separate later decision per AEF ADR §3. |

**Soft dependencies** (co-discovered, consulted, not pre-contracted, per substrate §9):

- Filesystem-write observation *shape* (4): mechanism (inotify/fanotify/ptrace/wrapper), per-host capability, blind spots
- Un-partitionable-file regeneration mechanism (substrate §5 residual carve-out): for files like `Cargo.lock` whose state is derivable, not authored
- Conservative→optimistic flip criteria (AEF §6 last open question): depends on (4)'s real behaviour

## Three questions for TermLink-side

1. **Substrate ADR ratification.** Does TermLink-side agree the ADR at `docs/architecture/parallel-execution-substrate.md` (your authoritative copy lives in your repo) is the right design? If not, what's contested and what's the revised shape?

2. **Primitive priority + ETA.** §6 lists them in recommended priority order (foundation → resilience → contract → keystone → supporting). Does this ordering hold against TermLink-side build constraints? What's the rough ETA for the foundation triple (1, 2, 3)? Are any of them already in flight?

3. **First-contact mechanism for ongoing coordination.** For the *soft* dependencies (4 shape, un-partitionable regen, flip criteria), §9 expects sustained dialogue. What's the right mechanism going forward — `bin/fw pending register` / `termlink remote inject` per session / a dedicated long-lived TermLink topic? T-1804 used `termlink remote inject termlink-agent --enter '...'` — does that pattern still apply?

## Out of scope for this proposal

- AEF-side downstream inceptions (§2-3 policy, §4 dispatcher, §5 sidecar+harness) — those file *after* the substrate-contracts shape is confirmed
- The conservative→optimistic flip decision — AEF-owned policy per substrate §4, requires the keystone (4) to land first
- Any source-code changes on either side — this is a contract dialogue

## Expected response shape

A reply via the chosen mechanism, addressing the three questions, with:

- **Confirmed / disputed / unclear** per primitive in §6
- Rough ETA per *hard* dependency (or "not committed yet")
- Choice of ongoing-coordination mechanism

A TermLink-side equivalent of T-2303 (a substrate-side scoping or sub-arc) is welcome but not required.

## Proposed send mechanism (operator approval required)

```bash
bin/fw termlink remote inject termlink-agent --enter \
  'cd /opt/termlink && please review docs/proposals/T-2303-cross-repo-parallel-execution-coordination.md (mirrored from /opt/999-Agentic-Engineering-Framework) — three questions, expecting a structured reply per §"Expected response shape"'
```

This mirrors the T-1804 pattern (U-007 in `fw pending list`). The operator is the authorising party for cross-repo first-contact; this proposal is the artifact, the inject is the action.

**Alternative mechanisms:**
- `bin/fw pending register` — slower, durable, async (operator-mediated read-side)
- `bin/fw termlink dispatch` — heavier (spawns a worker rather than delivering a message); wrong shape for first-contact
- Operator-mediated chat — fastest but escapes the audit trail

## Grill Me

This proposal is grillable before send. Primary grill targets:

- Are the three questions the right ones, or is the load-bearing ask buried somewhere else?
- Is the §6 primitive list comprehensive, or has AEF assumed a need TermLink hasn't seen yet?
- Does mirroring the T-1804 pattern make sense, or is there a different mechanism that better fits a cross-arc contract dialogue (as opposed to T-1804's single design question)?

**Entry:** `/grill-with-docs`
