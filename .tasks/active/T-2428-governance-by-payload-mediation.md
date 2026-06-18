---
id: T-2428
name: "Governance by payload mediation: model-agnostic LLM gateway"
description: >
  Inception. Should the framework adopt governance-by-payload-mediation — a
  model-agnostic LLM gateway that intercepts agent tool-call PAYLOADS at the
  request/response layer (allow / deny / rewrite / route), made unbypassable by
  an OS funnel laid ABOVE the agent — as its portable enforcement architecture?
  Emerged from the arc-012 continuous-mode live-fire (loop never fires under CC
  2.1 multi-session) + the Lock-1 autonomy-integrity discovery.
status: started-work
workflow_type: inception
owner: agent
horizon: now
target_blast_radius: 7
voi_score: 0.85
tags: [governance, proxy, payload-mediation, portability, livefire, lock-1, autonomy]
related_tasks: [T-2389]
created: 2026-06-18T19:50:00Z
last_update: 2026-06-18T19:50:00Z
date_finished:
---

# T-2428: Governance by payload mediation — model-agnostic LLM gateway

## Context

This inception captures an iterative design conversation (2026-06-18) that
started as "make the arc-012 autonomous loop fire" and converged on a much
larger architectural reframe. The thinking trail is preserved here (C-001):
the conversation is ephemeral, this file is permanent.

**Inputs feeding this inception:**
- `docs/reports/DISCOVERY-autonomous-mode-2026-06-16.md` (Lock-1 autonomy holes:
  A5 writable surface, A6 sovereign-verb gaps, D1-D3 directive channel, D7
  dispatch self-approve).
- The Lock-1 instruction ("make the payload un-self-authorable" via OS privilege
  separation). §0 finding: the loop runs as **root** — no boundary exists above
  the agent without demoting it to a non-root uid (human/root-run, Part 1).
- T-2389 live-fire (this session): drove a real `claude-fw` via TermLink. The
  observed first failure is **not** an interior loop bug.

## The journey (how understanding evolved)

1. **"Make the loop fire" was premature.** The arc-012 continuous loop has never
   fired end-to-end. Wired-in-code ≠ executable. A dozen prior fixes
   (T-2372/73/75/76/77/78/79/89/92/2403) repaired the loop's *interior*; each was
   unit-tested green and never run E2E.

2. **Live-fire found the actual wall (observed, not inferred).** Under CC 2.1.181,
   `claude-fw` wraps `claude`, which opens the **"claude agents" multi-session
   picker**, not a work session. Work sessions spawn in a separate
   `claude daemon` / bg-pty process tree **outside** the wrapper. So the budget
   gauge, `.restart-requested`, and the terminator all bind to the wrong process;
   the wrapper's core assumption ("claude-fw wraps the work session") silently
   stopped being true when CC shipped multi-session. Confirmed in the operator's
   own real terminal (screenshot: picker, "12 awaiting input · 0 working"). The
   gauge fix (Bug B) actually landed — and the loop still can't fire, because the
   exterior moved. Process evidence: `claude-fw(2268222) → claude(2268262)=picker`;
   the "Live-fire worker" ran under `claude daemon run(2296097) → bg-pty(2296171)`.

3. **`claude -p` is the wrong fix (operator).** Headless print-mode tends to bill
   metered API usage; an autonomous loop multiplies it. Scratch it. The cheaper
   path keeps interactive (subscription) billing — `claude -c` resume of a single
   session — but the deeper question is the *layer*, not the launch flag.

4. **Layer reframe (operator).** Stop owning the process lifecycle. There is a
   PROXY. Capture at the request layer, not the process layer.

5. **Payload insight (operator — the crux).** At some level every agent action is
   a **payload**. A tool call is a `tool_use` block (name + args, as text) inside
   the model's response. The harness is a *faithful executor of payloads* — it
   only runs what the response told it to. So a proxy that **parses and rewrites
   the payload** is a HARD gate, not just an observer: strip/deny/rewrite the
   `tool_use` and the harness has nothing to execute. (This corrects an earlier
   claim in the dialogue that "the proxy can't block execution" — true only for a
   dumb pass-through; a mediating proxy enforces.)

6. **OS routing = the unbypassable funnel (operator challenge).** You *can* route
   at the OS layer — iptables/nftables DNAT/REDIRECT, TPROXY, netns, DNS — to
   force any agent's traffic through the proxy regardless of binary or config.
   But the OS layer routes *bytes/syscalls, not semantics*: to read/inject/route
   by content you still terminate TLS and parse HTTP at the app proxy. So OS
   layer = non-bypassable funnel; app proxy = semantics. They compose. And it
   only holds if laid by a principal ABOVE the agent (root agent can flush its own
   iptables) — same finding as Lock-1 §0.

## The architecture (candidate)

**Governance by payload mediation, on two composed planes:**

- **Payload proxy = the governance brain.** Sits on the LLM HTTP boundary. Sees
  every tool call and message as text. Allows / denies / rewrites / routes.
  Model-agnostic (Anthropic `tool_use` ≈ OpenAI `tool_calls`). Carries: task
  gate, sovereign-verb gate (Lock-1), un-self-authorable directive injection,
  budget (real wire tokens — kills the T-2377/2392/2389 reconstruction bug class),
  model routing.
- **OS funnel + above-the-agent boundary = the enforcement floor.** netns/iptables
  force traffic through the proxy; a non-root uid / sudo / container laid by
  init-or-launcher makes the brain impossible to unwire. (Lock-1 Part 1.)

**Trust boundary moves** from "the harness runs our hooks" (Claude-Code-only) to
"the harness executes only the payloads we approved" (universal). That is the
Portability directive (D4) realized.

### The request/response sequence (where interception lives)

One tool-call cycle, Anthropic Messages API (OpenAI isomorphic):

- **① Harness → Model** `POST /v1/messages` {system, tools[], messages[], stream}.
  **Capture A (request):** inject governance into `system`, route model, count
  input tokens.
- **② Model → Harness** streamed SSE; assistant content includes
  `tool_use{id, name, input}` + `usage`. **Capture B (response) = the PREVENTION
  chokepoint:** the intent exists as text BEFORE execution → strip/deny/rewrite.
- **③ Harness executes locally** (syscalls, file writes). **Capture C (action
  plane):** proxy is BLIND here — but if B stripped the tool_use, ③ never happens.
- **④ Harness → Model** `POST` with `tool_result{tool_use_id, content}`.
  **Capture A again:** observe the result (too late to prevent).
- **⑤** loop until `stop_reason: end_turn`.

Summary: **prevention lives at ② (the response stream); the proxy controls
actions only by controlling the intent payload that authorizes them.** Total
coverage for a model-driven agent; the gap (non-model side effects, or an agent
not routed through the proxy) is what the OS funnel backstops.

### Denial composition at ② (turning observability into enforcement)

Protocol invariant: every assistant `tool_use` MUST be answered by a matching
`tool_result` in the next user message — so you cannot leave a dangling
reference. Proxy-only, model-agnostic enforcement:

- **Replace the whole assistant turn.** When a `tool_use` is denied, substitute a
  plain-text assistant message ("⛔ blocked: no active task — run `fw work-on`")
  with `stop_reason: end_turn`, dropping the `tool_use` entirely. The harness
  receives a normal text turn → executes nothing → no `tool_result` owed →
  conversation stays well-formed. Next turn, the model sees its prior turn as that
  text (mildly revisionist but coherent) and self-corrects.
- **Partial (multi-block) responses:** if ANY block is denied, replace the whole
  turn rather than forward some `tool_use`s and rewrite others (mixing forwarded
  tool_uses with a rewrite breaks the pairing the harness expects). Conservative
  but always coherent; the model retries the safe action next round.
- **Streaming:** buffer the response until the `tool_use.input` JSON is complete,
  classify, then emit either the original stream (pass) or a synthetic SSE stream
  for the text denial. ~hundreds of ms held per gated call.
- **Denial = steering:** phrase the substitute as actionable feedback so
  enforcement becomes a governance dialogue, not a dead end.

Engineering line: *observe-only* relay is ~trivial; the *mediating* gate (stream
parsing, tool_use/tool_result coherence, per-protocol normalization) is
"LLM-gateway-with-guardrails" territory — a real build.

## Acceptance Criteria

### Agent
- [ ] De-risk spike #1 — **subscription billing through a relay**: point Claude
  Code at a local observe-only relay via `ANTHROPIC_BASE_URL`; confirm (a)
  requests actually arrive at the relay and (b) billing stays on the
  subscription (OAuth bearer forwarded unchanged), NOT metered API.
- [ ] De-risk spike #2 — **payload visibility**: the relay logs each `tool_use`
  block (name + input) and `usage.{input,output}_tokens` from the live stream —
  proving the tool-call intent + real budget are capturable at the wire.
- [ ] De-risk spike #3 — **coherent denial**: demonstrate a single rewritten
  response (deny one `tool_use`, substitute text turn) that the harness accepts
  without breaking the conversation.
- [ ] Findings written to `docs/reports/T-2428-payload-mediation-spike.md`
  (deferred from this file due to budget-gate; do in a fresh session).

### Human
- [ ] [REVIEW] GO / NO-GO on adopting payload mediation as the portable
  governance architecture, given the spike evidence.
  **Steps:** read this task + the spike report; weigh the billing result (spike
  #1) and the build cost of the mediating gateway against the portability win.
  **Expected:** a decision recorded via `fw inception decide T-2428 ...` from
  Watchtower `/inception/T-2428`.
  **If not:** note which unknown still blocks and what evidence would resolve it.

## Verification
# (no compileable artifacts yet — spike code lands under its own build task post-GO)

## Recommendation
- **Recommendation:** DEFER
- **Rationale:** The architecture is directionally strong and unifies four threads
  (loop-firing, Lock-1 autonomy integrity, model-agnostic governance, portability)
  into one mechanism: mediate the agent's payloads at a proxy it cannot bypass.
  But a GO/NO-GO genuinely lacks evidence on two load-bearing unknowns: (1) does
  Claude Code honor `ANTHROPIC_BASE_URL` in subscription/OAuth mode WITHOUT
  shifting to metered API billing (the operator's explicit cost constraint), and
  (2) is a streaming-coherent denial injectable at the response layer. These are
  evidence gaps, not a confidence hedge — a cheap observe-only relay spike answers
  both. DEFER until spike #1-#3 land.
- **Evidence:**
  - Live-fire observation: `claude-fw` wraps the CC 2.1 picker; work runs in a
    daemon-pool tree outside the wrapper (process PIDs in journey §2). The
    process-layer approach is a dead end → motivates the request-layer approach.
  - Existing LiteLLM proxy (T-1700/T-1691) is an API-key-terminating gateway for
    ollama-loop workers only; logs no tokens; can't pass OAuth → NOT reusable
    as-is, needs a thin new transparent relay (Explore agent verdict).
  - Payload-layer enforcement is sound in principle (the harness executes only
    what the response carries) — see denial-composition section.

## Decision
<!-- fw inception decide T-2428 go|no-go|defer --rationale "..." (human, via Watchtower) -->

## Dialogue Log

- **Operator → "map this against framework directives, steelman/strawman it"**:
  Reliability (#2, served) outranks Portability (#4, violated) → favors the
  approach *iff* a real boundary exists. Strawman: building the lock without the
  cage (Lock-1 Parts 2-4 without Part 1) ships theatre; "un-self-authorable files"
  ≠ "un-self-authorizable behavior".
- **Operator → "autonomous resume is still not working / the loop is not fired at
  all"**: corrected my parroting of the DISCOVERY "wired" verdict. Drove to the
  live-fire.
- **Operator → "claude -p will become expensive / API usage"**: cost constraint
  killed headless; redirected to the proxy layer + subscription preservation.
- **Operator → "we have a proxy implemented, that should be the capture surface"**:
  LiteLLM exists but is ollama-routing; the *layer* is right.
- **Operator → "why can't we route with OS/syscall control?"**: corrected my glib
  ✗ — you can (netns/iptables/ptrace/LD_PRELOAD), but it routes the pipe not the
  meaning; composes with the app proxy; must be laid above the agent.
- **Operator → "payload is produced, a tool call is character payload"**: the
  crux. Reframed the proxy from observer to hard gate.
- **Operator → "go to inception / document this"**: this file (C-001/C-002).
- **Operator → [CLI-communication / capture-surface reference]** (commit limit
  raised 2→15 to allow incremental capture): supplied first-principles taxonomy
  of CLI comms + how tool calls map onto fork/exec/wait. Decisive result — **two
  nested contracts**: outer (model⟷harness, structured `tool_use`/`tool_result`)
  sees *every* tool intent semantically; inner (harness⟷kernel, argv/stdio/exit)
  sees only the fork/exec *subset* as raw bytes. Folded into research artifact
  `docs/reports/T-2428-payload-mediation-design.md` §2–§4. Net design shift: the
  two planes go from co-equal to **brain + floor with precise division of
  labour** — payload proxy = the only complete+semantic surface (governs tool
  calls); OS funnel = egress-pin making the proxy non-bypassable + subtree
  coverage for the harness-recursion case. Model-agnosticism upgraded from claim
  to structural consequence (governance binds to the protocol). Unknowns
  unchanged: subscription-billing-through-relay + streaming-coherent denial.

## Open follow-ups (not this inception)
- arc-012 continuous-mode: re-scope around the picker/launch-model reality (the
  loop can't fire as built under CC 2.1) — separate from this architecture.
- Live-fire teardown owed: TermLink session `lf-t2389`, worktree
  `.claude/worktrees/livefire-t2389`, and the watcher process
  (`/root/.claude/jobs/f527f807/tmp/watch-loop.sh`) are still up.
