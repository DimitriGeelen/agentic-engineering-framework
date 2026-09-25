# T-3475 — sidecar slice 1: what the API actually is

**Date:** 2026-09-25
**Resolves:** `docs/architecture/sidecar-target-architecture.md` §7, open question 4
(*"Whether the API is HTTP, a unix socket, or a TermLink RPC"*) and touches open
question 5 (*"What happens to the hub"*).
**Status:** recommendation. The ruling is the operator's.

## Why this is the keystone

Slice 1 is *"receiver sidecar process with an API + durable address; store message;
set receiver-side flag"*. Every other slice hangs off it. The gap table in the target
architecture lists eleven elements; **four are marked `inverted`, not `missing`** —
transport, delivery model, injection, and which side the flag sits on. Inverted is
worse than missing: the system works, reports success, and does the opposite of the
design. Slice 1 is where the inversion is corrected, and the transport choice decides
whether that is possible at all.

## The question T-3397 left open, and why it could not answer it

T-3397:81 says the sidecar *"exposes an **API a sending agent calls directly**"* and
does not say what an API is made of. That was the right call at the time — but it
means the design rests on a primitive nobody had checked exists.

So the first question is not "which transport is nicest". It is: **does the substrate
we already run offer push-to-a-durable-receiver at all?**

## Measured: TermLink's addressing model

Run 2026-09-25 against the live install.

| primitive | target | durable? |
|---|---|---|
| `termlink request <TARGET>` | "Session ID or display name" | no — session |
| `termlink remote inject` | session | no |
| `termlink remote send-file` | session | no |
| `termlink remote exec` | session | no |
| `termlink file send` | session ID (already measured, D-645 §3) | no |
| `termlink channel post <topic>` | topic | **yes** — but broadcast + cursor pull |
| `termlink inbox` ("offline inbox") | **deprecated**; T-1166/T-1235 — implemented on `channel.list` underneath | topic again |

**There is no third thing.** TermLink addresses either an ephemeral session or a
durable topic. The "offline file inbox for offline sessions" reads like the durable
service address slice 1 needs, and it is not one: it is the channel bus wearing a
different label, and the verb that exposes it is deprecated.

### What that rules out

**TermLink RPC cannot express slice 1's primitive.** Choosing it collapses to one of
two things:

1. **The sidecar registers as a long-lived named session.** Delivery then depends on
   that session being alive at send time — precisely the failure the design exists to
   remove. CLAUDE.md already records the symptom for the session-targeted path:
   *"ok:true = hub accepted, NOT delivered. Files silently lost to event-only
   sessions."*
2. **Fall back to topics.** That is the architecture being replaced — the row the gap
   table marks `transport: inverted`.

Neither is slice 1. This is the same wall the blob leg hit in D-645 §3, one level up,
with the same root cause: *a session is ephemeral, a circuit address is not.*

## Measured: cross-host is real, and the sidecar has never used it

```
FLEET: 6 hub(s), 5 up, 1 down
  local-hub / local-test / workstation-107-public   136 sessions
  ring20-dashboard   192.168.10.121                   0 sessions
  ring20-management  192.168.10.122                   5 sessions
  laptop-141         192.168.10.141                 DOWN
```

But every sidecar peer shares one circuit — `cacc73ea32b121dd` — which is the local
hub. So **all sidecar traffic to date is same-host, on a fleet that is genuinely
multi-host.**

That is the state Amendment 1 (T-3396) was written about:

> *"Before any cross-host build relies on a same-host-style transcript read, that
> mechanism must be re-verified to work (or not) across a host boundary — it has been
> verified same-host only."*

The generalisation that matters: **a transport validated only same-host looks correct
right up to the first peer that moves.** Nothing in today's evidence distinguishes a
transport that works from one that merely has not been tested.

### What that rules out

**A unix socket is disqualified as the transport.** Same-host only by construction, so
it needs a second, different cross-host path. Two paths means the ack states degrade
across the boundary exactly as Amendment 1 describes — and the degradation is
invisible, because the same-host path keeps working. The recurring defect class this
week has been *detection exists, routing does not* (OBS-533, 534, 535). A same-host
fast path plus a cross-host exception is how you manufacture another one.

A unix socket remains legitimate later as a **local binding of the same HTTP server** —
one protocol, two binds, not two transports. That is an optimisation, not a slice 1
decision.

## CORRECTION (2026-09-25, operator challenge) — the question was mis-framed

Everything above is sound about TermLink's primitives and wrong about what slice 1's
decision *is*. The operator asked where the five-part circuit address was in this
analysis. It was nowhere, and it should have been the frame.

### What already exists, ruled and built

**The 5-level taxonomy is ratified twice.** T-3287 (D1–D7, GO 2026-09-07) and D-599
(T-3433, 2026-09-22) both name it: *host / hub / project / session / agent*.

**arc-020 built the whole stack, and all seven slices are `work-completed`:**

| slice | what it is | file |
|---|---|---|
| S1 | V9 address library, with `climb()` / `ladder()` | `lib/aef_address.py` |
| S2 | circuit registry + three-state lifecycle | `lib/aef_circuit.py` |
| **S3** | **regressive resolution + provisioning ladder** | `lib/aef_resolve.py` |
| S4–S7 | election, governor, repo-source, provision audit | `lib/aef_*.py` |

`resolve(target, probe)` climbs 5→1 by dropping the rightmost address token, returning
**tri-state** — `FOUND`, definitive `NOT_FOUND`, or `INDETERMINATE` when a probe
raises. It is ungated and side-effect-free. `provision()` shares the walk, is Tier-3,
and **refuses to stand up a host** — *"the host is the one rung the ladder may ask,
never create."*

### The finding: nothing calls it (OBS-537)

Grep for `aef_address|aef_resolve|aef_circuit` across `lib/sidecar/`, `agents/` and
`bin/fw` returns **one** hit — `aef_provision_log.py` at `bin/fw:8806`. `aef_resolve`
is imported only by sibling `aef_*` modules: an internally consistent island with no
consumers.

And the sidecar built a **second, incompatible grammar** fifteen days later.
`lib/sidecar/circuit.py` (T-3433) emits `<hub>/<project>[/<session>]/<agent>`, and its
Decisions record *"Rejected: host-first 5-segment addresses"* — rejecting the exact V9
form arc-020 had ratified under D3.

Two ruled address grammars for one taxonomy, in one codebase, neither aware of the
other.

**The governance held; the wiring did not.** arc-020 is still `in-progress` with every
slice complete, because G-062 requires its headline mechanic — *"a dropped connection
recovers itself"* — to be demonstrated, and with no caller it has never fired. The arc
could not close, and did not. This is a new variant of the week's pattern: not
*detection exists, routing does not*, but **capability exists, adoption does not.**

### How this changes the transport answer

**The transport is not a free choice between three options. It is the `probe` argument
to a ladder that already exists.** `resolve()` *"calls probe and nothing else"* —
`Callable[[AEFAddress], bool]`, one rung at a time. That is precisely slice 1's seam.

Three consequences:

1. **Slice 1 must not invent addressing.** Its own definition says *"API + durable
   address"*. The durable address is built, tested and ruled. Adopting it is the
   slice; choosing a transport is a detail inside it.
2. **HTTP survives, for a better reason than I gave.** The V9 address carries
   `host=<fqdn>` — the one fact HTTP needs and the one fact T-3433's hub-anchored
   grammar deliberately withholds (*"would assert a fact we do not have"*). My original
   argument had to hand-wave a "TermLink hub discovery" step to bridge that gap. The
   ladder *is* that step, and it was already written.
3. **My proposed HTTP→topics fallback is redundant and should be dropped.** The ladder
   is already a fallback, and a better-shaped one: it degrades by **address
   specificity**, not by transport. Running a transport fallback beside an address
   ladder gives two fallback mechanisms that can disagree about why a message did not
   land — which is how the current `INJECTED_NOW` ambiguity was born.

### The danger the ladder brings with it

RESOLVE is ungated; PROVISION is Tier-3. The design names the hazard itself: *"a
typo'd address could provision a whole hub."* **Slice 1 must bind to `resolve()` only.**
A send that cannot reach a peer must fail, escalate, or dead-letter — never
materialise the peer. That belongs in slice 1's ACs as a refusal test, not as a note.

### What is now the first question, and it is not mine to answer

**Which grammar does the sidecar speak?** `inbox:<hub>/<project>` and
`aef::host=…::@agent::` cannot both be "the address". Three ways out — converge the
sidecar onto V9, keep both with an adapter, or supersede V9 — and each has a different
blast radius across arc-011 and arc-020. Two operator rulings are in tension here, so
this is surfaced, not resolved.

**Slice 1 is blocked on that reconciliation, not on the transport.** The transport
recommendation below stands, conditionally, once the address question is answered.

---

## Recommendation

**HTTP for the API.** The only one of the three that is a single path both same-host
and cross-host, and the only one giving the receiving sidecar a durable address
independent of any session's lifetime. It also matches the framework's own Portability
directive, which names standards (*MCP, LSP, OpenAPI*) as the preference.

**And keep TermLink underneath — it is good at the three things HTTP is not.**

| layer | mechanism | why |
|---|---|---|
| API / push | **HTTP** | durable address, one path, standard |
| discovery (circuit-id → host:port) | **TermLink hub** | the hub already holds the fleet map; the alternative is a second registry to keep in sync |
| blobs | **TermLink file transfer** | already ruled, D-645 |
| fallback carrier | **TermLink topics** | when the HTTP endpoint is unreachable — today's behaviour, preserved |

This answers §7's fifth open question as a by-product: **the hub stays, beneath the
API** — what T-3397's uniform-path amendment implied.

The fallback row is what makes this shippable rather than a flag day. Slice 1 can land
with HTTP preferred and topics as the carrier when HTTP fails, so the system never
regresses below what works now — and the **ratio of HTTP-delivered to topic-delivered
becomes the first honest measurement of whether slice 1 works.**

## The cost, stated plainly

HTTP means a listening port per agent per host, and **this codebase has scar tissue
there**: CLAUDE.md §Watchtower Port exists because `:3000` was hard-coded 371 times
across 277 tasks, and on the origin host `:3000` was *832's* Watchtower — so 224
verification lines returned 200 from the wrong server, including `/tasks/T-152`,
because low task IDs collide across projects. The failure mode was a **false green**.

So the port cannot be assumed, ever. The proven local pattern is the Watchtower
triple-file (`.context/working/watchtower.{pid,port,url}`): write the bound address at
bind time, read it, never guess. Slice 1 should do the same and publish the resolved
endpoint to the hub so cross-host peers resolve it identically.

**Unaddressed on purpose: authentication (IW-3).** An HTTP listener that accepts
injected prompts is a remote-code-execution surface by another name. TermLink solved
this for itself with TOFU + per-hub secrets (`~/.termlink/secrets/*.hex`, scopes
`observe|interact|control|execute`). Slice 1 must not ship a listener without deciding
this, and it is not decided here — it belongs on slice 1's own acceptance criteria,
named before the port is open rather than discovered after.

## What this does not claim

No HTTP sidecar has been built or measured cross-host. The measurements here establish
what TermLink's primitives **are**, which is enough to eliminate two of three options;
they do not establish that the third works.

Per this session's standard — *an assertion that something works, without the check
that demonstrates it, counts as an open task and not a closed one* — slice 1's first
acceptance criterion should be a **cross-host round trip against a second hub**
(`ring20-management`, up with 5 sessions), not a localhost test. A localhost test would
reproduce precisely the blind spot this document exists to name.
