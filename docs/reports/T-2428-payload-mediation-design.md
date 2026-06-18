# T-2428 — Governance by Payload Mediation: Design Exploration

**Task:** T-2428 (inception) · **Status:** exploration · **Owner:** agent (advisory)
**Recommendation so far:** DEFER pending a 3-part de-risk relay spike.
**Arc:** arc-013 (`payload-mediation`) — this file is the arc's **design-of-record**
(`design_status: draft` until T-2428 GO; flips to **final/locked** on GO).
**Build slices:** T-2429 (spike, gate) · T-2430 state-holder · T-2431 relay ·
T-2432 policy emit/install · T-2433 sandbox emit/install · T-2434 Lock-1 demo.

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

## 1a. The same idea, explained simply (plain language)

*(For the GO/NO-GO reader — read this first, then `§4b` for the technical form.)*

Imagine you have a robot helper. It's super smart and super fast, but it can't
see or touch anything by itself — it can only do things by **asking a grown-up
out loud**: "Can I open the cookie jar?" "Can I throw this paper away?"

The problem today: the robot is on the honor system. We *told* it the rules, but
nothing actually **stops** it if it gets confused or sneaky. The rules are just
sticky notes on the wall — and a sticky note can't stop anyone.

Our idea has **two parts that work together:**

**Part 1 — The Listener at the door.** Every time the robot wants to do
something, it has to say it out loud first. We put a grown-up — the Listener —
right where the robot's words come out. The Listener hears *every* request and
can say "Yes," "No, not that one," or "Do it this *safer* way instead." Because
the robot can only ever *ask* (it can't act on its own), controlling the asking
controls everything. And it works for *any* robot — a different brand still has
to ask out loud, so the same Listener still works.

**Part 2 — The playpen.** But what if the robot stops asking nicely and just
tries to grab something? A sticky note won't stop that. So we also put the robot
in a playpen — a room with **walls** (it can only reach the one phone that calls
the Listener, no sneaking out another way), a **locked cabinet** holding the
rulebook (so it can't erase its own rules), and a **"you're just a kid"
wristband** (so it can't do grown-up things like unlock doors). The robot didn't
build the playpen and can't unlock it — **a real grown-up built it from the
outside.** That's the part that actually *stops* things.

**Why both?** The Listener is *smart but trickable* — it understands what the
robot wants and can give a thoughtful "no," but a clever robot might look for
another door. The playpen is *dumb but unbreakable* — it understands nothing,
but the robot truly cannot get past the walls. Smart-but-trickable +
dumb-but-unbreakable = a helper that's genuinely safe. The Listener decides what
is *allowed to be asked*; the playpen decides what is *physically possible*.

**The most important rule:** the robot is never allowed to build or change its
own playpen. Only a grown-up does that.

> Mapping back to the technical design: the **Listener** = the payload proxy
> (S2). The **playpen** = the OS sandbox above the agent (S3 net-pin + S4
> read-only rulebook + S5 kid-wristband uid). "The robot never builds its own
> playpen" = Lock-1 Part 1 is human/root-run; the agent must not run it.

---

## 1b. The whole thing, kid version (the design we converged on)

*(Read after §1a. This is the full picture once the sandbox is treated as a
control surface in its own right, not a wall.)*

**Give the robot its own playhouse, and only let it touch the world through doors
we built.**

1. **The playhouse.** The robot thinks and plays inside as fast as it likes — we
   *don't* watch every thought (silly and slow). But the playhouse has **no
   windows and no secret exits**. The only way to do anything that touches the
   real world — grab a thing, send a letter, make a call — is through **doors we
   built**.
2. **We stand at every door.** Each thing that tries to go through, we check:
   allowed → it goes; not allowed → we stop it.
3. **It still asks first — and must use the proper tools.** Before it picks up a
   tool it asks the grown-up at the door (the Listener). And we make it use the
   **family's labeled toolbox**, not its own messy shortcuts — even when a
   shortcut "would've worked" — because the proper tools have the safety rules
   built in.
4. **No secret copies of itself.** The robot loves whispering to secret clones of
   itself in its head (we can't see those). So: **no secret clones.** Helpers must
   be *real* helpers in their *own* playhouses using the *same* doors — so we can
   watch them too.
5. **It didn't build any of this and can't change it.** A grown-up built the
   playhouse, doors, and rulebook **from outside**; the robot can't repaint the
   walls, pick the locks, or take off its "you're a kid" wristband.

**Why this delivers the control objective.** There are only ever **two things the
robot can do, and we control both**: *ask* (we hear every ask — the Listener /
proxy) and *act through our doors* (we watch every door — the playhouse /
sandbox). There is **no third way out**, and it holds because it's *real*, not a
sticky note: can't dig a tunnel (walls are built-in, not a rule it can ignore),
can't erase the rules (locked cabinet), can't pretend to be a grown-up (kid
wristband), can't sneak helpers (they use the doors too). So control is **total
and not trust-based**. Bonus: it works for **any robot** (the doors + grown-up are
ours, not the robot's), and it's **fast** (we watch the doors, not the thinking).

> Mapping: **doors we built + watch** = the VM/hypervisor boundary — the harness
> runs at native speed inside; every externally-effecting operation funnels
> through virtio device backends we own (§7a). **Ask the grown-up + proper
> toolbox** = the proxy governing *choices/mechanism* (§4b). **No secret clones**
> = forcing in-process sub-agents out into distinct, observable principals
> (TermLink-style) so neither surface goes blind on attribution. **Can't touch the
> locks** = uid demotion + RO substrate laid by root (Lock-1 Part 1).

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

## 4b. The right control surface (ranked) — the pivot

Candidate surfaces, top of the stack to the kernel:

| # | Surface | Sees / controls | Bypassable? | Portable? | Verdict |
|---|---|---|---|---|---|
| **S1** | In-harness hooks / permission system (`.claude/settings.json`, PreToolUse) | every tool intent; allow/deny/ask | **yes — declinable** (fires only if harness cooperates; config agent-writable) | **no** — CC-specific | where the framework lives today, and why it is *not enough*. Keep as convenience; never a boundary |
| **S2** | **Payload proxy at the model-API protocol** (`ANTHROPIC_BASE_URL`) | whole wire — every tool *intent* (semantic, complete) + every request | yes **unless pinned by S3** | **HIGH** — protocol-bound, any model/harness | **the choice / mechanism surface** — governs *what the agent reaches for*; allow/deny/rewrite/route |
| **S3** | OS network — netns + nftables egress allowlist (eBPF/DNS variants) | actual egress of harness **+ all children** (tools, MCP-HTTP, telemetry) | **very hard** (no other route out of the netns) | HIGH | **the pin + exfil containment** — forces the model path through S2 |
| **S4** | OS filesystem — Landlock / mount-ns / RO bind-mounts / overlay | what the agent uid may read/write; make hooks, settings, directive files, `.git` **read-only** | very hard (kernel-enforced) | HIGH (Landlock mainline) | **the Lock-1 cage** — the un-declinable boundary the proxy can't give |
| **S5** | OS process — uid demotion + cgroup/pid-ns (seccomp/eBPF execve) | what spawns; resource bounds; bounds wrapper/loop/hooks | hard | HIGH | **packaging + execution containment** for a non-cooperating harness |
| **S6** | Userspace interposition — LD_PRELOAD / FUSE | syscalls in principle | **defeatable** (static binaries, direct syscalls) | medium | **reject as a boundary** — speed-bump class (same reason `chattr +i` was rejected) |

### Recommendation: two CO-ESSENTIAL surfaces, split by *what they govern*

> **[CORRECTION 2026-06-18]** An earlier draft framed this as "proxy = governance
> *brain*, sandbox = enforcement *floor*" — which wrongly subordinated the
> sandbox to the proxy. Operator refuted it (see §4a-followup / Evolution log).
> The corrected framing splits the two surfaces by **what they govern**, not by
> trust-tier. Neither is primary; both are load-bearing.

**① Payload proxy (S2) — the CHOICE / mechanism surface.** Governs *what the
agent reaches for*: which tool, which subsystem, which mechanism. Crucially,
**mechanism-mandating lives here and only here** — forcing `TaskCreate`→`fw task
create`, in-process-subagent→TermLink, etc. Those are decided in the `tool_use`
*before any effect exists*; the effect boundary can never express "you used the
wrong mechanism" because by then the choice already happened. Model-agnostic.

**② OS sandbox (S3+S4+S5) — the EFFECT surface.** Governs *what actually
happens*: the real file writes, the real egress, the real spawns. The harness
runs *inside* it as a demoted uid; the deciders run *outside* it. (Mechanism in
§7a — realized as a VM/hypervisor boundary, not hand-picked syscall interception.)

**Why neither subsumes the other:** choices are decided *before* effects, and the
effect boundary sees only anonymous bytes-to-a-path, not "which mechanism / which
actor." A `TaskCreate` and an `fw task create` can have near-identical *effects*;
the difference that matters is the *choice*, which only the proxy sees. So the
proxy is **not** demoted to "make the sandbox non-bypassable" — it carries an
entire governance axis the sandbox structurally cannot.

**③ The residual — distinct principals.** In-process sub-agents are the case both
surfaces go partly blind on: the *choice* to spawn is on the wire (proxy can
deny), but once running, the sub-agent's actions hit the effect boundary as
**anonymous effects — attribution is lost**. So a third requirement: force
sub-agents out into **distinct, observable principals** (TermLink-style separate
processes), so they are attributable on both surfaces. The VM *helps* (it at
least *sees* in-process sub-agent I/O, which today's PTY-based view cannot — that
is G-015 / T-1061) but cannot restore attribution alone.

**Two secondary payoffs** from running the deciders outside the cage with the real
credentials: the harness never sees the API token (closes a credential-exfil
hole), and the proxy is the natural place to terminate subscription/OAuth —
exactly where unknown #1 must be answered.

**Reject as primary boundaries:** S1 (declinable) and S6 (defeatable). S1 remains
the everyday cooperating-harness convenience; nothing load-bearing depends on it.
(Note: FUSE appears in S6 as a *boundary* — rejected — but reappears in §7a as a
*mediation* surface, a different and legitimate role.)

**One-line answer:** *choices at the proxy (S2), effects at the sandbox boundary
(S3+S4+S5, §7a), sub-agents forced into distinct principals, and nothing
load-bearing in S1/S6.*

---

## 4c. Shaping the two surfaces — the control plane

How does the framework *drive* the proxy policy and the sandbox profile? One trap
governs the whole design.

### The trap: shape by *proposing*, never by *activating*

If the agent can configure its own proxy policy or sandbox profile, the cage is
theatre (self-authorization, one level up). The split follows the Authority Model:

- **Authoring / proposing** (what the rules should be) → **Initiative** — agent +
  framework may generate, suggest, diff.
- **Activating / installing** (making rules live) → **Authority/Sovereignty** —
  crosses the boundary the agent can't reach (root / outside the cage).

This is the **emit/install pattern the framework already runs three times** (cron
`registry→generate→install`, MCP `tool-set→emit-manifest`, vendor sync):

```
fw policy emit         / fw sandbox emit-profile     ← agent-runnable (produces a spec)
sudo fw policy install / sudo fw sandbox install     ← human/root only (activates)  ← BOUNDARY
```

Generation is agent-safe (just text); installation is the Lock-1 Part-1 step. The
daily audit gains a drift class for free: *emitted-but-not-installed*.

### Proxy control plane — two inputs, different trust

1. **Static policy** — the invariants (sovereign verbs, Tier-0 categories,
   governance-substrate paths). Most of the existing gates re-expressed as a
   policy the proxy evaluates — but now at a surface the agent **can't decline**
   (vs. today's S1 hooks). Compiled at install, lives **RO inside the cage**,
   changed only by the human.
2. **Trusted dynamic state** — focus, active-task status, approval tokens, budget
   level. **Sharp consequence:** today this lives in *agent-writable* files
   (`focus.yaml`, approvals queue, bypass log) — literally the A5 hole. For the
   proxy to trust them, this state must move **behind a privileged setter** the
   agent uid can't write. The verbs split (agent keeps *initiative*, loses
   *forge-the-committed-state*):

   | Today (agent writes state) | Becomes |
   |---|---|
   | `fw context focus T-X` | agent `request-focus` → privileged setter commits |
   | `fw inception decide` | $CLAUDECODE-blocked today; now *enforced* not just refused |
   | `fw dispatch approve` | agent proposes; privileged path approves (closes D7) |
   | `fw tier0 approve` | same |

   Per-request loop: parse streaming response → extract `tool_use` → classify →
   evaluate (static policy + trusted state) → **allow / deny-with-refusal /
   rewrite-to-safer / route-elsewhere / pause-for-human** → log every intent
   (richest observation surface we've had). To stay DRY, delegate *rich*
   decisions to a framework oracle (`fw policy decide …`) while the proxy keeps a
   small hard-coded deny-list for invariants even if the oracle is down.

### Sandbox control plane — emit from known substrate

The framework already knows which paths are governance-substrate, so it can emit
the profile (RO list, RW list = working tree minus substrate, single allowed
egress = the proxy address, demoted uid) → `fw sandbox emit-profile`. Root
installs. Agent never runs install.

### The unifying insight — one source, two surfaces

Both planes compile from the **same governance model**. A rule like *"the agent
may not modify hooks"* projects onto both: proxy denies a `Write` tool_use at a
hook path (semantic, early, self-explaining); sandbox makes hook paths RO to the
agent uid (un-declinable, late, absolute). Same rule, two surfaces, two trust
assumptions — defense in depth with **no shared failure mode**.

### Bootstrap / who-watches-the-watcher

The **proxy runs outside the cage** (non-agent uid / sibling namespace), started
by root, reading RO policy. The agent can reach it but can't kill, replace, or
reconfigure it. The harness's role flips: from *enforcer* (today's declinable
hooks) to *cooperating UX inside the cage* (fast friendly feedback, proposes
work) — while proxy + sandbox are the *authoritative* layer it can't talk past.

> **Highest-leverage build piece:** the privileged state-holder. It is the A5
> fix and the proxy's dynamic-state trust root in one — without it, the proxy
> reads agent-forgeable state and the whole edifice is back to honor-system.

---

## 4d. Building-block reality check (do we have the parts?)

Operator's grounding question: do we have a good proxy (is LiteLLM ok), and a good
harness sandbox? Repo-grounded answer.

### Proxy — LiteLLM: ok as a component, not as the answer

- **Already wired** — `lib/ollama_loop.py:6` points CC at LiteLLM via
  `ANTHROPIC_BASE_URL=http://localhost:4000`, `ANTHROPIC_API_KEY=sk-litellm-local-dev`
  (T-1700 build; T-1691 proxy comparison). So the base-URL redirect **provably
  works with CC**, and LiteLLM **provably sits at point B today**.
- **But wired for the wrong path** — it terminates with a *local dev API key* for
  the ollama/metered route. LiteLLM is fundamentally a **key-terminating**
  gateway → the *least* likely substrate to pass a subscription/OAuth session
  through transparently. Unknown #1 is **not** softened by LiteLLM; LiteLLM is the
  part most likely to break it.
- **And the wrong job** — LiteLLM does routing / key-mgmt / logging / fallbacks /
  cost-tracking. It does **not** parse `tool_use`, evaluate per-intent policy, or
  compose a streaming denial. **The governance brain is our code regardless.**
- **Verdict:** keep LiteLLM for multi-model routing + the metered/local path. The
  governance mediator wants to be a **thin, fully-owned relay** (or LiteLLM's
  Anthropic-passthrough mode *iff* the spike proves OAuth survives).

### Sandbox — we have nothing, and the repo says *why* (and why it's now unblocked)

No OS cage today; everything is S1 hooks (declinable). The framework **tried
twice and parked it:**

- **T-1482** disqualified `unshare --mount` *"at the constraint level: Linux-only
  → loses macOS portability"* (Portability directive).
- **T-1660** found `unshare(CLONE_NEWUSER)` *"interacts badly with Claude Code's
  session model"* (per-session, mid-session unshare).

**Our architecture dissolves both walls:**

1. **Portability wall gone** — portability now lives at the **proxy** (protocol,
   OS-agnostic), not the sandbox. The sandbox is the *deployment-environment* cage
   (Linux servers / containers — where autonomous/headless agents actually run).
   macOS dev box → proxy governance; Linux host → proxy + cage. T-1482 rejected
   the sandbox for failing to be the *portable* layer; it no longer has to be.
2. **CC-session wall likely gone** — we don't unshare mid-session. The launcher
   applies the cage **before exec'ing the harness** (systemd-unit hardening /
   rootless podman / `bwrap` at launch); the whole harness is born inside it.
   T-1660's failure was per-session in-process unsharing — a different move.

Assembled from mature parts: systemd `ReadOnlyPaths`/`PrivateNetwork`/`DynamicUser`/
`IPAddressAllow`, bubblewrap, rootless podman, nftables egress. **Lower technical
risk than the proxy.** (Read T-1482 + T-1660 in full before building.)

### Re-ranked risk (answers "are we focusing on the right thing?")

| Surface | Completeness today | Technical risk | Action |
|---|---|---|---|
| **Proxy** | partial (LiteLLM = plumbing, wrong path) | **HIGH** — subscription-OAuth transparency unproven, LiteLLM doesn't solve it | **de-risk FIRST** (spike #1 is the true gate) |
| **Sandbox** | **zero** | **LOW** — mature parts; our architecture removes the two parked reasons | **build-decision**, not a research spike (systemd vs bwrap vs container) |

The gate is the proxy's subscription-billing unknown. The sandbox is an assembly
job that this architecture just unblocked.

---


## 4e. The privileged state-holder as AUTHORITY BROKER (the keystone build, T-2430)

§4c named the privileged state-holder the highest-leverage build piece (A5 fix +
the proxy's dynamic-state trust root). This section is its design — sharpened by
the operator turn that rejected the first, too-coarse framing.

### From a binary gate to a policy-driven broker

The first cut was binary: *agent proposes / sovereign commits*. The operator
refuted it — **some decisions should be agent-committable** (a low-blast inception
GO, a focus change). The holder is therefore not a gate but a **policy-driven
authority broker** that implements the full tier ladder (0/1/2/3). Per decision it
asks: *given this decision's type and parameters, who may commit, and at what
audit tier?*

| Tier | Who commits | Example | Logged |
|---|---|---|---|
| **0** consequential | sovereign only, ALWAYS (hard ceiling, never delegable) | force-push, `rm -rf`, directive payload | — |
| **1** standard | agent, within the task gate | normal edits | normal |
| **2** situational | agent commits, prominently logged | focus-drift override, bypass | Tier-2 audit |
| **3** pre-approved | agent commits autonomously, **within the envelope** | low-blast inception GO | Tier-3 audit |

### The trust partition is a sovereign-authored ENVELOPE — global ceiling + per-type overrides

The line between "agent may commit" and "queue to human" is **not hard-coded** — it
is a sovereign-authored envelope living in RO substrate (the agent can't edit it).
Decision (operator turn): **both** a global risk ceiling **and** per-type overrides.

```yaml
authority_envelope:            # sovereign-authored, RO substrate (S4)
  global:                      # default bound, all decision types
    max_blast_radius: 2        # BVP cost_estimate.blast_radius
    min_voi_score: 0.5
    scope: internal            # internal | cross-project | external
  overrides:                   # per-type; tighten / loosen / hard-deny
    inception_go:     { max_blast_radius: 2, min_voi_score: 0.5 }
    dispatch_approve: { max_blast_radius: 1, require_disjoint_write_set: true, max_tier: 1 }
    tier0_approve:    { delegable: false }   # hard ceiling
    directive_author: { delegable: false }   # D1/D3 — sovereign only
    focus_change:     { delegable: true }    # initiative — auto-commit + record
    bypass_log_append:{ delegable: true }    # append-only
```

**Evaluation:** resolve the effective rule as `overrides[type] ?? global` (per-type
wins over global); Tier-0 and directive-authorship are a **hard floor no override
can loosen**. Check the decision's params against the effective rule → *within* →
agent commits + logs at the matching tier; *exceeded* → queue to the human.
Append to the audit log regardless of outcome.

### The invariant that keeps it safe

> **The agent commits WITHIN the envelope; the agent cannot change the envelope.**

The envelope is sovereign-authored and lives in RO substrate (S4). Autonomy is
real but bounded, and the bound is **un-self-modifiable**. This is the stable
middle between the two failure modes — *everything-sovereign-gated* (kills the
arc-012 autonomous loop) versus *agent-fully-authoritative* (the A5/D7 hole). It
is the same bounded-autonomy ceiling already shipped for one decision class
(T-2367, arc-012), generalized into the holder for **every** decision class.

**Worked example (reuses BVP fields already on these tasks):**

- exploration with `target_blast_radius: 1` → `fw inception decide … go` → within
  envelope → agent commits, Tier-3 logged. **No human round-trip.**
- **T-2428 itself**, `target_blast_radius: 7` → beyond the ceiling → holder queues
  to the human. (Correct — high-blast work stays sovereign.)

### The inversion principle — files become projections

Authoritative governance state = the **holder's record**; files become **read-only
projections** of it. Writing a file no longer *means* anything to governance —
only a holder-recorded event does. This is *why* task files, focus choice, and
captures can stay agent-RW: they no longer carry authority, so forging them is
inert. It dissolves A5 at the root rather than guarding each writable file.

### Antifragile feedback loop — the envelope is a dial

Every in-envelope commit is logged append-only (agent-can't-erase). The sovereign
reviews the agent's autonomous decisions and **tunes the envelope** — tighten on a
bad call, widen as trust builds. The envelope is a dial the sovereign turns on
observed judgment (Antifragility: the system's autonomy boundary strengthens from
the record of its own use).

### Shape — keep the TCB small

A small daemon `aef-govd` (uid `aef-gov`), in the **trusted zone outside the cage**
alongside the proxy. The state store is **RO-bind-mounted into the cage** (free
reads, no forging). The agent submits proposals over a **unix socket**; commit is
**sovereign-principal only**; the audit log is **append-only**. Keep it small — it
is the TCB; every line is attack surface.

### Why it's the keystone (three-in-one)

The holder is simultaneously (1) the **A5 fix** (trusted state leaves agent
scratch), (2) the proxy's **dynamic-state trust root** (the proxy reads
holder-committed state, not agent-forgeable files), and (3) the **sandbox
fs-boundary enabler** — the RO/RW partition is only clean once trusted state is
relocated, which is why **T-2430 precedes T-2433**. It is the structural home for
D7 (dispatch self-approve), D1/D3 (directive authorship), and bypass-log integrity.

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

## 7a. Sandbox design deep-dive (arc-013 T-2433) — host-grounded

> **[REFRAME 2026-06-18]** An earlier draft of this section picked
> **systemd+namespaces as "primary"** and argued the sandbox is a *static cage*
> whose job is to make the proxy non-bypassable. Two operator corrections
> superseded that: (a) the sandbox is the **effect control surface in its own
> right**, doing **active per-operation mediation** — not a passive wall; (b)
> systemd+namespaces is the *weakest* containment tier. The hypervisor model is
> the right one. This section now reflects that. *(Note: the sandbox mediates
> **effects**; it does **not** capture **choices/mechanism** — that is the proxy,
> §4b. The earlier "VM boundary = the complete mediation boundary" claim was
> wrong: it is the complete **effect** boundary only.)*

Host probe (2026-06-18, the actual deployment host): **agent runs as `root`
(uid=0)** — confirms Lock-1 §0, this is the hole the cage closes. Kernel **6.8**
(Landlock ≥5.13 ✓, **landlock active**). **systemd 255** is pid 1. **`/dev/kvm`
present, CPU `svm` (AMD-V)** → hardware virtualization is live. Tools present:
`bwrap`, `unshare`, `nsenter`, `docker` (rootful; runc only), `nft`, `iptables`,
`setpriv`. **Absent:** any VMM (`qemu`/`firecracker`/`cloud-hypervisor`), gVisor
(`runsc`), kata. So the VM/microVM path is *available* (KVM) but needs a VMM
installed — a tooling step, not an architecture gap.

### The reframe: active per-operation mediation at a hardware boundary

The sandbox is the **effect surface**, doing **active per-operation mediation** —
the off-wire twin of the proxy. A hypervisor is the cleanest realization, and not
because it "traps everything": hardware virtualization runs guest **CPU + memory
natively at full speed** and only takes control on **boundary crossings**
(virtio I/O, hypercalls, nested-page-faults). That *is* the static-floor /
live-mediation split — but the floor is hardware (faster, harder, no TOCTOU) and
the mediated subset is the **device boundary**, which we own in host userspace.

**The VMM's virtio backends ARE the effects decider** (twin of the proxy):
virtio-fs/virtio-blk = every file op at the fs-protocol layer (FUSE-like, no
TOCTOU); virtio-net = every non-model connection. Compute runs native; only
externally-effecting ops cross the boundary — which is exactly the set we want to
mediate. (Caveat from §4b: this covers **effects**; in-guest `execve` semantics
and *mechanism choice* are not visible at the device boundary — those are the
proxy's and the distinct-principals job.)

### Mechanism decision — three tiers (host-grounded)

| Tier | Mediation granularity | Compute cost | Boundary strength | On this host |
|---|---|---|---|---|
| Namespaces + seccomp + Landlock (the earlier, now-superseded pick) | hand-picked syscalls (seccomp-unotify) | low; slow if over-used | **weakest** (shared host kernel) | ready now |
| **gVisor (`runsc`)** | **every syscall**, semantic (incl. `execve`) | moderate (~10–50% syscall-heavy) | strong (guest kernel in userspace) | needs install |
| **microVM / VM** (Firecracker / QEMU / cloud-hypervisor) | I/O + net at virtio backends; native compute | low compute; heavier boot/setup | **strongest (hardware)** | KVM present, needs a VMM |

**Fork RESOLVED (2026-06-18, operator-confirmed): microVM is the target; gVisor
is the documented fallback.**

Why microVM wins the axes that carry the most risk:
- **Compatibility** — a real guest kernel means the full CC + Node + TermLink +
  git + MCP stack just runs; gVisor's incomplete ABI is a real feasibility risk
  for a complex, frequently-updating workload.
- **Mediation-surface fit** — the **virtio device backends *are* the
  effects-decider** by construction (virtio-fs daemon = file mediator, userspace
  virtio-net backend = egress mediator). We own the backend without patching
  internals. gVisor's Gofer/netstack are hookable but bespoke.
- **Boundary strength** — hardware-enforced (strongest); escape = governance
  bypass, so this matters.
- **Steady-state perf** — native compute for a long-lived session; only virtio
  I/O overhead.

The one thing gVisor uniquely offers — a **first-class semantic `execve` event**
— is a *forensic nicety, not a control necessity* here: the command **choice** is
a Bash `tool_use` the **proxy** already sees and can deny (mechanism/choice rule,
§4b), the spawned process's **effects** cross virtio-fs/virtio-net (mediated), and
even the binary load is a virtio-fs **read** (observable, just not a clean
event). **Flip condition (documented):** if "which binaries may run" must become a
*first-class semantic policy axis* enforced on the actual spawn — independent of
proxy command-parsing and virtio-fs read-traces — that earns gVisor's
compatibility risk. Absent that requirement, microVM.

**Target build path:** **kata-containers** wrapping **Cloud-Hypervisor** or
**Firecracker** (OCI drop-in over a real VMM) + a **custom virtio-fs backend** as
the file-effects mediator + a **userspace virtio-net backend** as the egress
mediator (model traffic → the proxy; all else allow/deny). **Fallback:** `runsc`
(gVisor) as a docker runtime — faster to stand up if microVM setup or virtio-fs
perf proves painful.

`Landlock` (active on 6.8) + `nftables` remain useful as a **static floor inside
whichever tier** (cheap kernel-enforced invariants: RO substrate, egress-deny),
with the chosen tier supplying the **active** mediation on top. Linux-only is
fine — portability lives at the proxy (§4d); the sandbox is the deployment-host
layer.

### Profile content (tier-independent)

- **uid (S5):** dedicated `aef-agent` non-root user. (Today root → this demotion
  *is* the boundary.)
- **fs (S4) — RO to agent uid:** framework code (`bin/fw`, `lib/`, `agents/*`
  hooks), `.claude/settings.json` + hooks, `.git/`, policy + sandbox-profile +
  proxy config, the trusted-state store. **RW:** working tree, `.tasks/`,
  `docs/`, scratch `.context/`.
- **net (S3):** one route out — the proxy. No direct model endpoint, no
  telemetry, no arbitrary egress.

### Two findings that fall out

1. **T-2430 must precede T-2433.** The fs boundary is not clean today because
   `.context/working/` mixes agent scratch with governance-trusted state (focus,
   approvals, bypass log). Only after the privileged state-holder (T-2430)
   relocates the trusted subset does the RO/RW partition become tractable. Build
   order: **state-holder → sandbox.**
2. **The cage improves the loop terminator.** A cgroup kills the whole process
   subtree reliably — strictly better than the sleep-sibling terminator (T-2373)
   and the wrong-process-binding problem from the live-fire. The cage *helps*
   arc-012.

### The deciding validation (build-check, not research)

Does CC + TermLink + the wrapper run correctly inside the chosen tier (gVisor
guest, or a microVM) with the substrate RO, egress pinned to the proxy, and the
virtio/gofer backends mediating I/O+net? T-1660's failure was *mid-session
userns*; launching the whole harness inside the tier from the start is a different
move and should hold — but must be validated. A build check, not an
approach-killing unknown. (This is the sandbox's equivalent of the T-2429 proxy
spike, and like it, needs **no GO** — pure feasibility.)

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

- **2026-06-18 (§4b/§7a correction — SUPERSEDES the "brain+floor" framing above):**
  operator refuted the brain+floor demotion. The proxy and sandbox are **two
  co-essential surfaces split by *what they govern***: proxy = choices/mechanism
  (what the agent reaches for — tool_use intent, incl. mechanism-mandating like
  forcing TermLink over in-process subagents); sandbox = effects (what the harness
  actually does — I/O, network, spawns). Neither subsumes the other. §4b verdict
  rewritten; §7a reframed from a static namespaces cage to **active per-operation
  mediation at a hardware boundary** (hypervisor model — native compute, only
  boundary crossings trap at virtio backends).

- **2026-06-18 (sandbox tier fork RESOLVED):** three-tier choice (namespaces+seccomp
  / gVisor / microVM) resolved to **microVM target, gVisor fallback** (kata +
  Cloud-Hypervisor/Firecracker + custom virtio-fs/virtio-net backends as the
  effects-decider). Host probe confirmed `/dev/kvm` + AMD-V present. NB: §4d's
  re-ranked risk table ("Sandbox: LOW — assembly job, systemd vs bwrap vs
  container") predates this reframe and is superseded by §7a — the sandbox is now
  active mediation, not a static-cage assembly job.

- **2026-06-18 (§4e added — the holder as authority broker):** folded the
  privileged state-holder capture into **§4e**. Key sharpening (operator turn):
  the holder is not a binary propose/commit gate but a **policy-driven authority
  broker** with a sovereign-authored **envelope (global risk ceiling + per-type
  overrides)**. Invariant: agent commits *within* the envelope, cannot *change*
  it. Generalizes the T-2367 bounded-autonomy ceiling to every decision class —
  keeps the arc-012 loop alive while closing A5/D7. Inversion principle: holder's
  record is authoritative, files become RO projections.
