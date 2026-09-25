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
