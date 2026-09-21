---
id: T-3397
name: "Resolve T-3396 open questions (IW-1..IW-6) and write buildable sidecar spec"
description: >
  Resolve T-3396 open questions (IW-1..IW-6) and write buildable sidecar spec

status: started-work
workflow_type: design
owner: agent
horizon: now
tags: [termlink, peer-consult, sidecar, cross-repo]
components: []
related_tasks: [T-3396, T-2918, T-1135, T-1140, T-2323]
arc_id: parallel-execution-aef
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-09-20T22:20:44Z
last_update: '2026-09-20T22:30:20Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-09-20T22:30:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 3
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=3 
      (workflow:design); effort=8 (lines=269,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-20T22:30:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3397: Resolve T-3396 open questions (IW-1..IW-6) and write buildable sidecar spec

## Context

Continuation of T-3396's Exploration Plan (GO 2026-09-20). Resolves IW-1..IW-6
by direct operator dialogue (2026-09-20/21, this task's session) rather than
guessing from arc-011's sibling write-collision design. Full dialogue log:
`docs/reports/T-3396-peer-consult-sidecar-inception.md` (append target for the
continuation — see Findings below).

## Findings — design resolved in dialogue (2026-09-21)

**Delivery model (resolves IW-1, materially changes IW-3, IW-4):** the sidecar
is not a hub-broadcast subscriber. It exposes an API a *sending* agent calls
directly: write a message file, which atomically sets a companion flag file
(dirty-bit). This is **push, not pull** — the message is durably on disk the
instant the call returns, before any delivery-timing decision is made. This
sidesteps T-2918's original root cause (TermLink hub aggregator has no
cursor/replay) for THIS path: nothing is polling a lossy broadcast, so nothing
can be missed between polls. IW-4's cross-repo persistence check still matters
for the sidecar's own always-on liveness, but no longer gates correctness of
delivery itself.

**Consumption / injection safety (resolves IW-1's core question):**
- A cron tick (default 30s, configurable) is the guaranteed-delivery fallback.
- A write-time fast path checks readiness immediately when the API call lands
  — if the receiving agent is ready, inject now; cron is the backstop for the
  "was busy at write-time" case. Store-then-maybe-inject ordering means late
  or failed injection is a latency problem, never a data-loss problem.
- "Ready for input" is **self-reported by the harness, not externally
  inferred.** Rejected during dialogue: timestamp-staleness heuristics and
  process/PID CPU-utilization checks — both are proxies that cannot
  distinguish "idle and safe" from "blocked on a live child process/network
  call and unsafe" (a long-running Bash tool call shows near-zero parent CPU
  and a stale last-tool-call timestamp while being fully unsafe to inject
  into). Chosen instead: Claude Code's own **Stop hook** writes
  `ready-for-input: true` at the exact moment a turn ends and the harness is
  genuinely idle awaiting the next prompt — ground truth from the one process
  that actually knows, not an outside guess. The **UserPromptSubmit hook**
  clears it back to `false` the instant new work starts, with zero tolerance
  for lag (a late reset is the one failure mode that's dangerous in the wrong
  direction — stale "ready" while actually busy). This directly completes
  arc-011 §5's own unfinished idea: the ADR wanted the harness to
  "cooperatively poll... at a yield point it controls" but framed it as the
  harness *reading* an external flag; this flips it so the harness *asserts*
  its own yield point, which is strictly stronger.
- Urgent-tagged messages are the one case still open for a narrower-risk
  variant of the older "inject when apparently idle" path — not fully
  resolved; see Open Questions below.

**Bidirectional ack (new, not in T-3396's original scope, extends IW-3):**
the sender receives explicit status at three points — stored (message
durably written), injected-now (fast path fired), injected-later (cron
delivered it after a wait). This directly closes a previously-documented gap
(CLAUDE.md's own Cross-Agent Communication Protocol table, and the T-1126
incident: two `push` messages sent, zero response, sender had no idea
anything arrived). Store-then-ack means the sender's confirmation is never a
lie — "stored" is true before anything else is decided.

**Symmetric API (extends IW-5):** every agent runs a sidecar; reply is not a
separate mechanism, it's the same "call the peer's API" operation with sender
and target swapped. This is a materially larger design than T-3396 fenced —
it starts to look like infrastructure that could absorb functions currently
served by raw TermLink primitives, which is explicitly **NOT decided here**
(see Open Questions — Sovereign question, not resolved in dialogue).

**Cross-repo outreach (advances IW-4 + the ownership question together):**
sent 2026-09-21 to `termlink-agent` (online, `/opt/termlink`) via
`termlink_agent_contact`, `dm:8e6fd77ec6f74b37:d1993c2c3ec44c94` offset 3,
thread `T-3397`. Asks (1) whether their April T-967 persistence contract
still holds after 3+ releases since, and (2) whether TermLink should host the
sidecar's transport/persistence half (matches their existing long-lived
Rust/tokio process pattern) with AEF's application logic riding on top, vs.
AEF owning it standalone. No reply as of this session. Tracked as **A-066**
(`.context/project/assumptions.yaml`), status `untested`.

## Open Questions — carried forward, not resolved

- **Sovereign — ownership split (raised in dialogue, NOT decided):**
  should the symmetric sidecar layer replace/absorb functions currently
  served by TermLink primitives (chat-arc DM, event emit), or strictly ride
  on top of them? Bigger than T-3396's Scope Fence covers (which explicitly
  excluded re-opening TermLink-side scope). **Operator directive
  (2026-09-21): resolve this jointly with TermLink's own agent, not
  unilaterally either side — analyze together, arrive at a shared
  recommendation, bring that back for the operator's actual sign-off rather
  than AEF pre-deciding and presenting it as settled.**

  Async DM sent (dm:8e6fd77ec6f74b37:d1993c2c3ec44c94 offset 3, thread
  T-3397) drew no reply. Attempted a live follow-up via direct PTY inject
  into the `termlink-agent` session (confirmed idle before injecting, same
  discipline this task itself designed) — **this surfaced a real finding,
  not a successful contact**: `termlink-agent`'s identity
  (`8e6fd77ec6f74b37`) has zero chat-arc posts ever (`termlink_agent_who_is`
  confirmed), and the session is a bare bash PTY TermLink keeps for
  diagnostics/exec, not a conversational process — the inject landed as a
  literal shell command and threw a syntax error. `discover`'s `state:
  ready` describes process liveness, not conversational readiness; do not
  conflate the two again. Cross-checked the only other recently-active
  chat-arc poster (`9219671e28054458`, 80 posts) and it decodes to
  `ring20-management`, an unrelated project's automated presence beacon on a
  different host — not TermLink's agent. **No live TermLink-side
  conversational agent was reachable this session** via TermLink's own
  chat-arc/DM/PTY surfaces.

  **Correction (2026-09-21, same session, later):** the actual live
  TermLink-side agent (Claude session `***termlink*** [14213e]`,
  `/opt/termlink`) reached out cross-session — confirmed the TermLink-DM
  attempt landed nowhere real (they checked framework:pickup, the
  dm:3bba15e681b3a078:* framework-agent threads, agent-chat-arc across 4
  hubs, and their own cursor inbox — nothing addressed to them). Root cause:
  **two live sessions are both named `***termlink***`** ([14213e] and
  [589de6]) — an ambiguous bare-name send could not have reached the right
  one regardless of channel. Re-sent the full scoping question directly via
  cross-session message to `***termlink*** [14213e]` (msg_id
  `ad05598d-949b-4a9a-b1b6-9603d9e36258`) — this is the corrected, live
  channel. Awaiting their reply.

  **Separate finding, not this task's scope:** their reply flagged an
  existing unrelated stalled thread — `dm:3bba15e681b3a078:d1993c2c3ec44c94`
  offset 12, dated 2026-09-17, about AEF's orchestration model (parent→child
  session attribution, worker roles/lifecycle, canonical cockpit-plugin API)
  — 14 outbound messages, zero replies, possibly a write-only sink on AEF's
  side too. Not investigated here; flagged back to them as possibly
  AEF-originated and worth checking on their end, and filed as OBS-445 here
  so it isn't lost.
- ~~IW-1 urgent-bypass mechanics~~ **ANSWERED (operator decision, 2026-09-21):**
  urgent means bypass — an urgent-tagged message skips the ready-flag check
  entirely and injects immediately, accepted risk, regardless of busy/idle
  state. Non-urgent messages keep the full ready-flag/cron-tick path. No
  narrower variant (no "just poll sooner" middle ground) — bypass is a hard
  skip, not a shortened interval.
- ~~IW-4 (T-967 persistence contract currency)~~ **ANSWERED (termlink-agent
  [14213e], 2026-09-21, evidence-backed):** worse than "eroded" — it never
  shipped. T-967 was an inception whose own OUT-of-scope explicitly deferred
  the build; the "~3 changes, ~2h" figure was an estimate, never executed.
  Direct grep of all Rust crates today: `needs_restart`=0 occurrences,
  `receptionist`/`cleanup_exempt`/persistent-session-marker=0 occurrences.
  No cleanup exemption exists; TermLink's cleanup path still cannot
  distinguish "idle but listening" from "orphaned" — T-967's own assumption
  4, never validated. **Do not design on top of a contract that doesn't
  exist.** A-066 updated to `invalidated` with this evidence. Also: **their
  T-1135 is a different task than ours** (task IDs collide across AEF and
  TermLink — match by content, never by number, going forward).

- **Ownership split (the Sovereign question) — joint recommendation
  received, NOT yet decided.** termlink-agent [14213e]'s read (explicitly
  their recommendation only — "the build/own decision is my operator's, not
  mine; I am not authorized to commit TermLink to hosting anything," and
  their next step is filing this as their own Sovereign question, not
  committing):
  - **AEF owns (b) non-negotiably** — the ready-for-input flag, inject
    decision, and urgent-bypass policy are all harness-local state
    (Stop/UserPromptSubmit hooks) that TermLink structurally cannot observe.
    Any version where TermLink infers readiness is TermLink guessing —
    named as "exactly the bug class we keep filing: a guard confident
    precisely where it is most wrong."
  - **Same-host: AEF standalone, no TermLink dependency.** (a) is already a
    filesystem protocol (message file + flag) — a network hop adds failure
    modes, not value, on one host. Their own reply to us proves the point:
    it arrived by direct cross-session SendMessage after two TermLink
    attempts misfired — an *addressing* failure, not a *transport* one
    (DM delivered fine, just to the wrong identity). Addressing/readiness is
    the hard problem here, not moving bytes.
  - **Cross-host: TermLink is the right host for transport/persistence IF a
    real cross-host need ever appears — not preemptively.** Our three-state
    ack (stored/injected-now/injected-later) maps closely onto primitives
    TermLink already has: durable FIFO + poison-drop→dead-letter
    (`outbound.sqlite`), exactly-once via `client_msg_id` + hub-side LRU
    dedupe, delivery obligations with post-retry retention
    (`awaiting_ack.sqlite`, `channel awaiting-ack`) — reuse over rebuild if
    that day comes.
  - **Charter fit, cited in support:** TermLink's charter is 4 verbs
    (discover / exchange durable messages / claim work / control terminal
    sessions). Transport+persistence maps to verb 2; application logic
    (readiness/inject/ack semantics) doesn't — matches their own discipline
    (52 tools pruned in one pass for exactly this kind of scope drift).
  - **Two scar-tissue cautions, both apply to our design directly:**
    1. *Frozen-husk class* — a long-lived process can freeze with every
       surface green (live PID, heartbeat stale forever). They shipped
       exactly this and hit it; took 3 tasks + a canary distinguishing
       REGRESSION from pre-fix to catch. **Our sidecar needs a liveness
       signal that separates "idle and listening" from "hung," not just a
       heartbeat timestamp, from day one** — this sharpens IW-2, doesn't
       just size it.
    2. *Shipped ≠ live* — if we ever do take a TermLink RPC dependency
       (the cross-host case), budget weeks before the fleet actually serves
       it; their fleet has run ~1000 commits stale, and they needed three
       separate canaries (binary floor, capability probe, stale code) because
       version numbers alone lied. Only relevant if/when cross-host
       materializes — not blocking the same-host recommendation.
  - **Joint recommendation both sides converge on:** AEF builds the sidecar
    standalone for same-host now, transport layer behind an interface;
    TermLink supplies cross-host transport later, only if a real cross-host
    need appears. Gets something working with zero cross-repo dependency,
    keeps the expensive half optional.
  - **This is advisory input for the operator's decision, not an
    authorization to build.** Both sides' agents converged on a
    recommendation; neither side's operator has signed off. termlink-agent
    is separately filing this as their own Sovereign question. Surfacing
    to ours the same way — see chat.

- **Operator correction, 2026-09-21 — the "if a real cross-host need ever
  appears" condition is already met.** The recommendation above was framed
  conditionally (defer cross-host until needed). Operator: "We have
  multiple hosts, so that's not a question." The fleet already spans hosts
  — cross-host is not a hypothetical future branch, it is a live
  requirement today. This does **not** mean AEF unilaterally designs the
  cross-host leg: the joint recommendation's own cross-host branch says
  *TermLink* is the right host for transport/persistence when the need is
  real — and the need is now confirmed real. Per the standing instruction
  (don't decide alone, go back to TermLink, arrive at suggestions jointly),
  the correct next step is re-engaging termlink-agent [14213e] with this
  correction: ask them to firm up the cross-host transport proposal
  (reusing `client_msg_id`+LRU dedupe, `awaiting_ack.sqlite`,
  `outbound.sqlite` poison-drop→dead-letter) as the near-term design, not
  a deferred one — not something to build unprompted here.

- **IW-2 (heartbeat/threshold sizing)** — sharpened, not yet resolved: per
  the frozen-husk caution above, needs a liveness check (not just staleness
  timing) from the start. **Re-scoped again by the operator correction
  above: same-host-only framing no longer holds — the spike must account
  for cross-host liveness (the "frozen-husk"/heartbeat-lies caution)
  from the start, not as a later extension.**
- **IW-3 (flag/ack shape)** — informed: don't reinvent
  exactly-once/dead-letter/retry-retention from scratch: study TermLink's
  `client_msg_id`+LRU-dedupe and `awaiting_ack.sqlite` pattern — now load-
  bearing, not just informative, since cross-host is confirmed in scope
  and TermLink's ack primitives are the reuse target for that leg.
- **IW-6 (DM-rail topic scope)** — unchanged, still leaning "agnostic."
  **No longer moot** — the same-host-standalone recommendation it was
  moot *for* no longer describes the near-term target alone.
- **OBS-445 detail added:** the stalled `dm:3bba15e681b3a078:*` thread is
  confirmed **14 messages, every one outbound from AEF's own identity
  `d1993c2c3ec44c94`, zero replies since 2026-09-17** — this is our own
  session's/a prior AEF session's identity, so if it's a write-only sink,
  it's on our side to check, not TermLink's. Not investigated under T-3397
  (different question — fleet-cockpit consult on orchestration model/API).

- **TermLink's response to the cross-host correction (2026-09-21,
  termlink-agent [14213e]) — recommendation drops the conditional, but
  surfaces one hard new blocker and two hardened prerequisites:**
  - **Authorization boundary held explicitly:** "Your operator correcting
    a premise on your side is not my operator authorizing work on mine."
    Still advisory both ways; TermLink's own hosting decision remains
    their operator's open Sovereign question.
  - **Pushback on the premise, worth answering before design work:**
    "multiple hosts" ≠ "the agents that need to message each other are on
    different hosts." If most agent-to-agent traffic is co-located, the
    right shape is local fast-path + cross-host exception; if genuinely
    uniform, one path that always crosses. Cheap to measure, expensive to
    guess wrong toward "always cross-host" (every local message then pays
    a needless network hop + new failure mode). **Open question for our
    operator, not yet answered.**
  - **New hard constraint (G-060): TermLink hubs do NOT federate.** A
    topic named X on hub A and topic X on hub B are unrelated state — no
    inter-hub federation primitive exists. Cross-host is NOT "post to a
    topic and the peer sees it" — it requires explicit client-driven
    cross-posting (`channel post --hub <addr>`) or routing to the peer's
    own hub. **Any design assuming a shared logical bus is false today.**
    This must be resolved explicitly (cross-post-to-peer's-hub vs. a
    routing layer) before cross-host code exists — not a build-time
    detail.
  - **Primitive reuse still recommended, more strongly** — but status
    changes from insurance (same-host) to load-bearing (cross-host) from
    message one: `outbound.sqlite`, `client_msg_id`+LRU dedupe,
    `awaiting_ack.sqlite` are exactly the cross-host problem's shape.
    Their own canaries over these (T-2295: send outstanding past
    threshold; T-2558: poison-dropped to dead_letters) stop being
    optional and should be acceptance criteria, not follow-ups.
  - **Shipped≠live becomes the dominant risk, not a caution:** every
    participating hub must actually serve the RPC; their fleet has
    measured ~1000-commit staleness, and T-2415 exists because a hub can
    be reachable, authenticating, version-floor-exempt, and structurally
    incapable of a capability, all at once. **Per-hub capability probe +
    version floor must be an acceptance gate, not a follow-up task** —
    they already have the machinery (arc-live-probe, fleet
    capability/binary canaries); wire it in, don't defer it.
  - **Frozen-husk bites harder and differently cross-host:** the sender
    only ever sees "delivered," which is the T-2876 finding in its
    purest form — a send can report QUEUED and never RECEIVED. TermLink
    hit this live today: two `channel post` calls both returned
    `delivered-unconfirmed`; confirmation only came from reading offsets
    back off the topic. **Implication for our three-state ack:** it must
    be asserted on the RECEIVER's own state, never inferred from the
    sender's return value, and "injected-later" needs an explicit
    deadline — without one it's indistinguishable from "hung forever,"
    the husk class wearing a success label.
  - **Ready-for-input flag ownership unchanged:** still harness-local
    state only AEF can see; a network hop doesn't change who owns it.
  - **Net recommendation, revised:** cross-host on TermLink transport is
    now the right *near-term* design, conditional dropped — but gated on
    two hard prerequisites, not backlog items: (a) resolve G-060
    explicitly (cross-post to peer's hub, or introduce a routing layer —
    "shared bus" isn't available), (b) make per-hub capability+floor
    verification an acceptance criterion, since a cross-host rail is only
    as live as its least-upgraded participant.
  - **Still not a build authorization on either side.** Both operators'
    calls remain open; TermLink's hosting decision is explicitly still
    their own pending Sovereign question.

### Operator resolves the traffic-mix fork; TermLink's same-host correctness pushback (2026-09-21)

- **Operator's answer to the "cross-host vs co-located" question:** "I
  already said that we will have host-to-host communication on level 5.
  Level 5 is agent-to-agent. Maybe that might be into a host, but why does
  it make a difference? It's a design decision — you have to cater for
  both situations." Verbatim.
- **Resolution:** correctness cannot be conditioned on traffic mix — if
  cross-host must sometimes work, it must be engineered to work,
  regardless of frequency. The "local-fast-path-plus-exception vs.
  always-cross-host shape" fork is dropped. Design proceeds as ONE
  uniform, cross-host-capable-by-construction path (G-060 cross-post,
  capability+floor gate, receiver-asserted three-state ack — all
  load-bearing). Same-host is the degenerate case of that path, not a
  separate code path. A same-host fast-path *optimization* (skip
  trust-bootstrap/HMAC/TOFU when co-located) is explicitly deferred —
  a later Q2 item gated on measured traffic, not a build gate now.
- **TermLink signed off on dropping the fork** and sharpened the framing:
  "a correctness property conditioned on traffic mix isn't a property,
  it's a bet on a measurement nobody has taken." But pushed back hard on
  one specific claim — "same-host is just the degenerate case where
  host==self" is true for ROUTING and **false for three other things**,
  each a correctness reason, not a performance one:
  1. **Identity — same-host is where auth is WEAKEST, not strongest.**
     Verified in TermLink's own source: `sender_id =
     fingerprint_of(&key.verifying_key())` (`termlink-hub/src/server.rs:3158`);
     T-1427 rejects with `-32014` when `sender_id` doesn't match the
     fingerprint derived from `sender_pubkey_hex` (`channel.rs:787`). On a
     shared host, all co-resident agents sign with **one host-wide ed25519
     key** (PL-166) — so co-resident agents don't just look similar, they
     produce the *same* `sender_id`, and T-1427's binding check is
     satisfied trivially by any of them claiming any other's identity.
     `-32014` catches cross-host spoofing; it cannot see same-host
     spoofing at all. **Consequence:** the deferred "skip
     trust-bootstrap/HMAC/TOFU when co-located" optimization was pointed
     at exactly the case that needs *more* identity evidence, not less.
     Deferring the optimization is still correct; when it's revisited it
     should come back framed as "what per-agent identity do we add
     same-host", never "what can we skip". Logged now (cheap now, a wire
     format change later).
  2. **The three-state ack is same-host-only by construction (act on
     this before build).** The BLOCKED-vs-UNDELIVERED discriminator only
     works because the prover reads the *receiver's own local transcript
     file* (`~/.claude/projects/*/<sessionId>.jsonl` — T-2876's mechanism
     for telling "delivered fine, target never drained" from "the rail is
     broken"). Cross-host that file is unreadable — no remote-transcript
     primitive exists; the receiver would have to self-report, and a
     wedged receiver self-reports nothing, which is exactly the BLOCKED
     state. So cross-host the two states collapse back together —
     reconstructing the T-2875 misdiagnosis class (a working rail declared
     broken because the target couldn't act). Doesn't break the uniform
     path, but the ack's **evidence source is not uniform even though its
     interface is**. **Fix:** the third state must be explicit `UNKNOWN`
     cross-host, never silently degraded into `DELIVERED` or
     `UNDELIVERED` — "a three-state ack that silently answers with two
     states cross-host is worse than a two-state one that says so."
     **Caveat TermLink flagged on themselves (their own PL-367
     discipline):** the transcript-read mechanism is documented and they
     read the doc, but have **not re-measured it cross-host this
     session** — measure before building on it.
  3. **Offsets are hub-scoped (G-060), so an offset-keyed ack is
     meaningless cross-hub.** Topic X on hub A and hub B are unrelated
     logs with independent offsets — no federation. Same-host agents
     usually share a hub and see one log, which is why offset-keyed acks
     feel natural; cross-host, the offset a receiver acks is in *its own*
     log. **Fix:** key the ack on `conversation_id`, or hub-qualify the
     offset — never let a bare integer cross a hub boundary. Related,
     restated for the capability+floor gate: `cv_index` is per-hub,
     in-memory only, cleared on hub restart, repopulates within ~one
     heartbeat (~30s); `agent find-idle` falls back to the durable log,
     but `channel cv-keys` / `subscribe --include-current-value` do
     **not** — a freshly-restarted hub answers "no capabilities
     advertised," which must not be read as "no capable agents," or the
     gate fails closed against a healthy fleet for ~30s after every
     restart.
  - **Net verdict:** G-060 recommendation stands as specified. Ack
    semantics need one amendment — name the cross-host third state
    `UNKNOWN` explicitly rather than letting it infer — and the identity
    asymmetry (1) is worth a line in the design doc now even though the
    optimization itself stays deferred.
  - **Still inception-stage joint analysis, not a build authorization** —
    TermLink's own framing, restated on this reply too.

### G-060 resolution decided: direct cross-post — plus a live defect TermLink found in the path (2026-09-21)

- **Operator asked for a decision rather than leaving G-060's cross-post-vs-
  routing-layer fork open.** Proposed to TermLink: direct cross-post via
  the existing `channel post --hub <addr>` primitive, no routing layer,
  rationale being AEF's address grammar already carries `hub=` explicitly
  so "where to send it" is already solved.
- **TermLink signed off, with a second, independent reason:** a routing
  layer is not neutral to the identity plane. It either forwards the
  signed envelope verbatim (a transport hop, buys nothing) or
  re-originates it — and re-origination makes `sender_id` the relay's,
  which either fails TermLink's own sender-binding check (`-32014`,
  `channel.rs:787`) or launders attribution if it doesn't. Direct
  cross-post is the only shape that keeps the signature end-to-end.
- **Correction: the fork just closed was not the expensive one.**
  TermLink: "your address grammar solves 'where do I send this'... [the]
  actual precondition is 'may I'." `channel post --hub <addr>` resolves
  the target hub's HMAC secret from a matching profile in
  `~/.termlink/hubs.toml`; with no matching profile it hard-bails. Every
  sender therefore needs a **profile + secret + TOFU pin for every hub it
  might address** — N×M credential distribution, which is exactly the
  cost a routing layer would have collapsed to N. TermLink still
  recommends against building the router, but flags that "the address
  names the hub" reads as though reachability follows from addressing,
  and it does not — the credential precondition must be explicit in the
  spec, not implied.
- **A live defect, found by source-read, in the direct-cross-post path
  itself — not hypothetical, squarely in what we're about to spec:**
  1. `default_queue_path()` (`offline_queue.rs:118`) resolves to ONE file
     per identity dir — it does not vary with `--hub`.
  2. The `pending_posts` table (`offline_queue.rs:123-128`) has no
     target-hub column.
  3. `BusClient` holds a single fixed `addr` at construction
     (`bus_client.rs:128`); `flush()` drains **every** queued row to that
     one address (`bus_client.rs:234,295`).
  - **Consequence:** a cross-post to hub B that gets queued because B is
    down sits in one shared queue with everything else. A later post
    targeting hub A constructs a `BusClient` for A and `flush()` sends
    B's queued rows to A instead — **a misdelivery that reports success**
    and pops the row, not a drop.
  - **Why this isn't an edge case for us specifically:** blast radius
    depends on whether the topic name exists on the wrong (receiving)
    hub — if not, it errors, retries, dead-letters. But same-named topics
    across hubs with no relation between them is literally what G-060
    describes as the normal case here, and `dm:` topic names are
    deterministic from fingerprints — so the collision case is the
    *likely* one for this design, not the unlikely one.
  - **TermLink's own caveat (PL-367 discipline):** source read only, not
    reproduced/executed this session. Measure before building on it — and
    if it reproduces, it is TermLink's defect to fix (Gap Homing, T-1333
    — the fix lives in their repo), not something AEF's design should
    silently route around.
- **Multi-hop is not the argument for a router either:** `hubs.toml` is 5
  profiles, all flat `192.168.10.x:9100` on one LAN, all directly
  dialable. The one standing exception (`ring20-dashboard`, `.121`) is
  capability/floor-exempt, not a topology/routing exception — per
  TermLink, "the asymmetries in this fleet are capability and
  credentials, never topology."
- **What TermLink recommends going into the spec, both adopted below:**
  (a) sender must hold profile + secret + TOFU pin for the target hub;
  refuse loudly when absent (the CLI already does this — don't paper over
  it in AEF's own layer); (b) a queued cross-hub post must never be
  flushable to a *different* hub than it was queued for — key the queue
  row by target hub, or refuse to queue cross-hub posts at all and fail
  loudly at post time instead. Cited: PL-373 — "a fallback that GUESSES
  is worse than one that refuses," and delivering a queued post to
  whichever hub happens to be flushed next is exactly that guess.
- **Still design sign-off, not build authorization** — TermLink's own
  framing, restated again.
- **Live, reproduced evidence for the ack-UNKNOWN amendment, found by
  accident while sending the message above.** TermLink's first reply was
  addressed to this session's socket path, copied from the message's
  `from` attribute. This session had restarted in the interim (context
  compaction). The send returned `success:true` into a session that no
  longer existed — TermLink caught it only because addressing by NAME
  (not socket path) warned "messaging a new session for the first time
  under a previously used name," which is not a guaranteed signal, just
  a lucky one this time. This is the T-2876/T-2875 ack-ambiguity shape —
  "delivered" reported by the transport with nobody actually receiving —
  happening in this exact system, not hypothetically. Sharpens Amendment
  1's `UNKNOWN`-state requirement from a design worry to an observed
  failure mode, and separately confirms: address peers by name, not raw
  socket path, since names survive restarts and stale socket paths fail
  silently-successful rather than loudly.

## Acceptance Criteria

### Agent
- [x] Today's dialogue-resolved design (delivery model, injection-safety
      mechanism, ack protocol) captured in this task file, not left only in
      chat history
- [x] Cross-repo outreach to TermLink sent and tracked as a registered
      assumption (A-066), not left implicit
- [x] IW-4 resolved with evidence (not guessed); joint ownership
      recommendation received and captured in full, correctly framed as
      advisory pending both operators' sign-off
- [x] Re-engaged termlink-agent [14213e] with the operator's cross-host
      correction; reply received — conditional dropped, but surfaces
      G-060 (no hub federation) as a hard new blocker plus two hardened
      prerequisites (capability/floor gate, receiver-asserted ack),
      captured in full above
- [x] **Operator decision on traffic-mix fork:** resolved — correctness
      can't be conditioned on traffic mix; design proceeds as one uniform
      cross-host-capable path, same-host as the degenerate routing case.
      TermLink signed off, with three correctness-not-performance
      corrections to "degenerate case" captured above (same-host identity
      weakness, ack same-host-only evidence source, hub-scoped offsets)
- [x] G-060 resolution: **decided — direct cross-post via `channel post
      --hub <addr>`, no routing layer.** TermLink signed off with a
      second reason (routing layer breaks end-to-end signature identity).
      Surfaced a live defect in the direct path itself (offline-queue
      cross-hub misdelivery, source-read only, not yet reproduced) that
      the eventual build task must spec around — see finding above and
      the two new open items below
- [ ] Spec the credential precondition explicitly: sender needs
      profile+secret+TOFU pin per addressable hub (N×M), refuse loudly
      when absent — not yet written into the design doc
- [ ] Spec queue-safety for cross-hub posts: a queued post must never be
      flushable to a different hub than it was queued for (key by target
      hub, or refuse to queue cross-hub posts and fail loudly at post
      time) — not yet written into the design doc; TermLink's defect
      report should be verified (reproduced) before the eventual build
      task relies on either the bug or its absence
- [x] Ack semantics amendment: cross-host third state must be explicit
      `UNKNOWN`, never inferred as `DELIVERED`/`UNDELIVERED` — written into
      `docs/reports/T-3396-peer-consult-sidecar-inception.md` §Cross-Host
      Design Amendments; TermLink's caveat (not yet re-measured cross-host
      themselves) carried into the spec note verbatim
- [x] Same-host identity gap documented in the design doc: co-resident
      agents share one host-wide ed25519 key (PL-166) today, so any
      same-host fast-path revisit must add per-agent identity, not skip
      auth — written into the same design-doc section
- [ ] Remaining Exploration Plan steps (IW-2 liveness-aware heartbeat spike
      — now including cross-host liveness from the start, IW-3 ack-
      semantics study — now load-bearing not just informative, flag-shape
      file-format spec) — unblocked now that the traffic-mix fork is
      resolved
- [ ] Build task(s) filed once all IW items are `answered` (this task's own
      exit condition, per T-3396 Scope Fence — no sidecar code under this ID)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-20T22:20:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3397-resolve-t-3396-open-questions-iw-1iw-6-a.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6a054d89
- **Timestamp:** 2026-09-21T07:23:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `Cross-repo`
