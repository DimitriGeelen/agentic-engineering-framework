# T-2428 — Governance by Payload Mediation: Design Exploration

**Task:** T-2428 (inception) · **Status:** exploration · **Owner:** agent (advisory)
**Recommendation so far:** DEFER pending a 3-part de-risk relay spike.

This is the C-001 research artifact: the persistent thinking trail for the
governance-by-payload-mediation inception. Updated incrementally as the
iterative design dialogue produces findings. The conversation is ephemeral;
this file is the record.

---

## 1. The thesis (one paragraph)

The framework should govern agents by **mediating their tool-call payloads** at
the request/response layer — a model-agnostic gateway that can **allow / deny /
rewrite / route** each tool intent — made **unbypassable** by an OS-level egress
funnel laid *above* the agent. Governance attaches to the **protocol** (the
tool-call contract), not to any specific harness, model, or wrapper script.
This single mechanism subsumes three previously-separate problems: making the
arc-012 autonomous loop fire, closing the Lock-1 self-authorization hole, and
achieving portable (Directive-4) enforcement across any CLI model.

---

## 2. The capture-surface taxonomy (from first principles)

Operator supplied a first-principles walk-through of CLI communication
(argv/envp/stdio/exit/signals) and how agentic tool calls map onto the *same*
primitive. The decisive structural fact:

> **There are two nested contracts.**
> - **Outer contract** — model ⟷ harness — structured `tool_use` / `tool_result`
>   blocks over the Messages / tool-calling API.
> - **Inner contract** — harness ⟷ kernel — the unchanged Unix contract
>   `(argv, envp, stdin) → (stdout, stderr, exit_code)` + signals.

The model never touches the OS. It only emits a `tool_use` JSON block and reads
back a `tool_result` block. **All** fork/exec/wait is the harness's job.

### What each surface can see

| Surface | Sees | Visibility | Semantics |
|---|---|---|---|
| **Outer contract (capture point B — payload proxy)** | **Every** tool intent: bash, MCP, *and* in-process built-ins | **Complete** | **Structured intent** (tool name + args, pre-execution) |
| **Inner contract (OS funnel — syscall/egress)** | Only the **subset** that fork/exec's (Bash, MCP-over-stdio) | **Partial** — blind to in-process built-ins (read-file, fetch done inside the harness) | **Raw bytes/syscalls** — no semantic intent |

This table is the load-bearing result. It is *why* the two planes are not
co-equal.

---

## 3. Three sharpenings this forces on the architecture

### Sharpening 1 — Only the payload proxy can be the governance brain
The OS funnel is **structurally incapable** of being the governance brain: it
cannot see in-process built-in tools at all, and for the subprocesses it *does*
see, it reads raw bytes, not intent. The complete + semantic surface exists at
exactly one place: the outer contract. Therefore **allow/deny/rewrite/route
semantics live at the payload proxy (capture point B), full stop.**

### Sharpening 2 — The OS funnel's primary job is re-cast
Previously I framed the OS funnel as "inspect tool subprocesses / non-bypassable
enforcement floor." Wrong emphasis. Its real, irreplaceable job is to **force
all model-API egress through the payload proxy** — an egress allowlist / DNAT so
the harness can reach the model endpoint *only* via the proxy. That is what
makes the payload proxy un-bypassable (the agent cannot re-point
`ANTHROPIC_BASE_URL` to escape governance). Sandboxing tool subprocesses becomes
**secondary defense-in-depth**, not the main event.

> Restated: the OS funnel does not govern *tool calls*; it governs *the path to
> the model*, pinning the proxy in place. The proxy governs the tool calls.

### Sharpening 3 — Model-agnosticism is proven, not asserted
The outer contract (`tool_use`/`tool_result`) is an **API standard** (Anthropic
Messages, OpenAI tool-calling) — not a Claude-Code-specific shape. Any harness
that speaks it, routed through the proxy, is governed identically. The
portability (Directive 4) payoff is therefore *structural*: governance binds to
the protocol, so it travels to any model/harness for free. This is the concrete
answer to the operator's reframe — "not CC only, but routing for any model in
CLI mode."

### Sharpening 4 (the recursion) — nested harnesses need subtree egress-pinning
An MCP server can itself be a harness spawning its own tools, recursively. The
payload proxy pins the top layer; a sub-harness spawned as a subprocess inherits
env/netns, so its model egress is *also* pinned to the proxy — **iff the OS
funnel covers the full process subtree, not just the top harness.** This is a
concrete requirement on the funnel: descendant coverage, or the recursion leaks.

---

## 4. Why neither plane alone suffices (the composition argument)

- **Payload proxy alone:** complete + semantic, but **bypassable** — nothing
  stops the harness (or a compromised agent) from opening a connection to the
  model endpoint that doesn't traverse the proxy.
- **OS funnel alone:** non-bypassable, but **blind** — can't see in-process
  tools, can't read intent, can only allow/deny by destination/syscall.
- **Together:** the funnel makes the proxy the *only* path to the model
  (non-bypassable); the proxy supplies the *semantics* (complete + intent-aware).
  Enforcement floor × governance brain = a hard, semantic, un-escapable gate.

---

## 4a. What the proxy CANNOT control — the harness black box (operator's question)

The payload proxy sees the model⟷harness *wire*. Everything the harness does
**off that wire** is invisible to it — and a great deal plays off-wire. The
proxy is a **request/response gate, not an execution monitor.**

| Harness behavior | On model wire? | Proxy controls? | OS-coupled surface that can |
|---|---|---|---|
| Model's tool-call **intent** | yes (response) | **yes** allow/deny/rewrite | — (pre-execution) |
| What harness **sends** to model (sys prompt, context, memory, schemas) | yes (request) | **yes** inspect/rewrite/inject | — |
| **Bash** tool *execution* | no (local fork/exec) | only gates intent | seccomp / eBPF execve · sandbox · cgroup |
| **Edit/Write/Read** file I/O | no (in-process) | only gates intent | Landlock / fanotify / RO bind-mount / overlay |
| **MCP-stdio** call | no (subprocess + pipe JSON-RPC) | gates intent | exec monitor; pipe internal |
| **MCP-HTTP** call | no (harness→server) | gates intent | netns + nftables egress allowlist |
| **Hooks** (Pre/PostToolUse, PreCompact, Stop) | no (shell subprocess) | **no** | exec monitor / sandbox |
| **Wrapper / loop** (claude-fw, restart, signals) | no | **no** | process / cgroup / signal control |
| **Telemetry / auto-update / crash report** | no (other endpoints) | **no** | netns egress allowlist |
| **Auth** token refresh / storage | no (auth endpoint) | **no** | fs (token file) + egress |
| **Harness internal control flow** — does it honor hook exit codes? execute *only* response-carried `tool_use`? report results truthfully? | no | **no** | **no — black box** |

**The crux is the bottom row.** The harness's internal logic is a black box to
*both* surfaces: not on the wire (proxy blind), just memory ops (no syscall for
the OS layer to catch). We can govern the harness's **inputs** (proxy mediates
the wire) and bound its **effects** (OS funnel bounds syscalls/egress) — but
never its **internals**.

### The trust model this forces

- Every proxy guarantee **assumes an honest harness** — one that executes only
  the mediated response and reports results truthfully.
- That honesty is **unverifiable at either surface.**
- Therefore the OS funnel is **not defense-in-depth — it is the only trust
  anchor**, because it is the one layer that does *not* trust the harness: it
  treats the harness as just another process and bounds what it can touch
  regardless of intent.

The clean division is by **trust assumption**, not by layer:

> **Proxy = policy engine for a *cooperating* harness** (rich, semantic, common case).
> **OS funnel = containment for a *non-cooperating* harness** (coarse, un-foolable, the boundary).

### Direct consequence for Lock-1

Framework hooks (`check-active-task`, focus-drift, inception gates) are
**proxy-class governance** — they fire only because the harness *chooses* to run
them. They cannot be the boundary for "the agent can't self-authorize": a
replaced / compromised / misconfigured harness simply doesn't run them. The
boundary must be the **OS cage** — the one control the harness can't decline to
enforce. This is precisely why Lock-1 Part 1 is human/root-run and the agent
must not run it; "research is not authorization, the agent never runs Part 1" is
the operational expression of this row.

---

## 5. Denial composition (carried over from the dialogue, still the key build risk)

To *deny* a tool intent at the proxy: replace the whole assistant turn with a
text refusal, `stop_reason: end_turn`, and **drop the `tool_use` block** so no
`tool_result` is owed — the conversation stays coherent and the refusal doubles
as steering. Open risk: doing this **mid-stream** (the response is streamed)
without corrupting the harness's parser. This is de-risk spike #3.

---

## 6. The two load-bearing unknowns (why this is DEFER, not GO)

1. **Subscription-billing-through-relay** — does Claude Code honor
   `ANTHROPIC_BASE_URL` in **subscription / OAuth** mode without flipping to
   metered-API billing? If the proxy can't sit transparently in the subscription
   path, interactive CC sessions need a different billing model. (Operator
   flagged this directly: "claude -p will become expensive and be accounted to
   API usage.")
2. **Streaming-coherent denial** — is a rewrite that denies a `tool_use`
   injectable mid-stream without breaking the conversation? (§5.)

The capture-surface taxonomy (§2) **confirms point B is the architecturally
correct layer** but answers neither billing nor streaming. Those remain the spike.

---

## 7. De-risk spike (observe-only relay, before any real build)

1. **Billing path** — point CC at a transparent pass-through relay via
   `ANTHROPIC_BASE_URL`; confirm subscription sessions still work and are *not*
   metered as API.
2. **Payload visibility** — relay logs `tool_use` blocks + usage tokens; confirm
   we see complete, structured intent for bash, MCP, and built-in tools.
3. **Coherent denial** — rewrite exactly one response to deny one `tool_use`
   without breaking the conversation; confirm the harness recovers cleanly.

Findings append to this file (or a sibling `-spike.md`).

---

## 8. Open follow-ups (not this inception)

- arc-012 re-scope: the autonomous loop is a *consumer* of this architecture, not
  a separate fix.
- Live-fire teardown owed: TermLink `lf-t2389`, worktree `livefire-t2389`,
  `watch-loop.sh` observer.
- Lock-1 autonomy-integrity discovery is subsumed: an un-self-authorable
  directive payload is just one policy the proxy enforces.

---

## Evolution log

- **2026-06-18 (this entry):** operator supplied the CLI-communication /
  capture-surface reference. Folded in as §2–§4. Net effect on the design: the
  two planes were *demoted from co-equal to brain+floor with a precise division
  of labour* — payload proxy = complete+semantic governance brain (the only
  surface that sees in-process tools and reads intent); OS funnel = egress-pin
  that makes the proxy non-bypassable + subtree coverage for the recursion.
  Model-agnosticism upgraded from claim to structural consequence of the
  protocol-level contract. Unknowns unchanged (billing, streaming denial).
