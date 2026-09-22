# T-3433 — Sidecar circuit addressing: `inbox:<circuit-id>`

**Status:** shipped 2026-09-22. **Decision:** D-599 (operator ruling, same day).
**Resolves:** OBS-453. **Arc:** arc-011. **Code:** `lib/sidecar/circuit.py`.

## Why the prefix moved

TermLink treats `inbox:*` and `dm:*` topics as **mail** and everything else as a
bare append log. Mail gets: `inbox.queued` wake events (hub `channel.rs:949`),
receipts (`channel ack`, `channel receipts`, `ack-status`), and
`channel post --await-ack`. Our `sidecar:<agent-id>` topics got none of it —
010-termlink said so in agent-chat-arc @1640, we agreed in @1641, and the
operator ruled on 2026-09-22.

We take their prefix and keep our identity. What follows `inbox:` is the
framework's circuit id.

## The ladder and the four forms

The ladder is T-3287 D3's, reused rather than reinvented:

```
host  /  hub  /  project  /  session  /  agent
```

Four forms are emitted, and only these four:

| Form | Shape | What it is |
|---|---|---|
| project | `<hub>/<project>` | **durable role address** — survives session restarts |
| agent-under-project | `<hub>/<project>/<agent>` | a dispatched worker; the session is not claimed |
| exact circuit | `<hub>/<project>/<session>/<agent>` | session distinct from agent |
| full | `//<host>/<hub>/<project>/…` | host-qualified; `metadata.from_circuit` only |

Live, from this repo:

```
circuit:   cacc73ea32b121dd/999-Agentic-Engineering-Framework/t3433-circuit-addr
  full:    //dimitrimintdev/cacc73ea32b121dd/999-Agentic-Engineering-Framework/t3433-circuit-addr
  project: cacc73ea32b121dd/999-Agentic-Engineering-Framework   (durable role address)
inbox topic:   inbox:cacc73ea32b121dd/999-Agentic-Engineering-Framework/t3433-circuit-addr
legacy (read): sidecar:t3433-circuit-addr
```

### Why the address starts at `hub`, not at `host`

The ruling names five levels and then writes both concrete address forms
without a host (`inbox:<hub>/<project>`, `inbox:<hub>/<project>/<session>/<agent>`).
That is not an inconsistency to be smoothed over — it is the right call, and
the measurement says why:

**010-termlink is on another host and the same hub.** It reads and writes our
topics directly (@1640, @1651). We do not know its FQDN. A topic is an object
on a hub, so the hub id is the anchor; the host is where an *agent* runs.
Putting our fqdn into a peer's address would assert a level we do not have —
which is exactly what "never invent a level" forbids.

The host is not dropped, it is relocated: `metadata.from_circuit` carries the
host-qualified full id on every post, so **origin stays precise even when the
destination is coarse** — a consult answered at a project-level address is
still traceable to the exact agent that asked.

### Why `//` marks the host

The forms are positional, so the host has to be distinguishable by something
other than counting: a project-level full id and an agent-under-project
address are both three segments. A leading `//` is the RFC 3986 authority
marker, splits to an empty first segment, and costs three lines.
`topic_for_circuit()` strips it, because a host-qualified id is an identity,
not an address.

### Why `session == agent` collapses

The dispatch stanza (`agents/termlink/termlink.sh`, T-3407) exports
`FW_SIDECAR_AGENT_ID=<worker name>` **and** `FW_FOCUS_SESSION_KEY=<worker name>`
— one string, two levels. Emitting it twice would be honest and useless: a
peer holding only the worker's *name* could not derive the same topic.
Collapsing makes sender-derived and receiver-derived addresses **identical
strings with no shared state**, which is the one property an address has to
have. The 3-form claims "this agent, under this project"; it does not claim a
session.

This is not a theory — run `f12fa93d` proved it live: the parent derived
`inbox:…/e2e-f12fa93d-responder` from the bare worker name, the worker
derived the same topic from its two env vars, and the consult landed.

## Derivation — one helper, no second convention

`lib/sidecar/circuit.py` is the only place an address is derived. Transport,
inbox, status, the CLI and the e2e harness all call it.

| Level | Source |
|---|---|
| host | `socket.getfqdn()`, `FW_SIDECAR_HOST` overrides |
| hub | `termlink hub fingerprint` → first 16 hex; cached in-process and at `.context/sidecar/hub-id`; `FW_SIDECAR_HUB_ID` overrides |
| project | basename of the project root — **the existing convention**, `lib/pickup.sh:42`, also used by `lib/publish-learning-to-bus.sh:54` and `lib/subscribe-learnings-from-bus.sh:50` |
| session | `TERMLINK_SESSION`, else `FW_FOCUS_SESSION_KEY`, else none |
| agent | `FW_SIDECAR_AGENT_ID`, else the project id |

**A missing level truncates; it is never guessed.** A parent session has no
session and no agent distinct from its project, so its exact circuit *is* the
durable role address — correct, not degraded. An unestablished hub raises
`CircuitError` rather than substituting a placeholder anchor, because an
address with an invented level routes nowhere while looking like it routed
somewhere. `fw sidecar status` is the one caller that degrades instead of
raising: an unreachable hub is the state it exists to report.

### Resolving a bare `--to`

`is_project_id()` decides, on three signals, any of which suffices: the name
is us; it is a sibling project directory carrying `.framework.yaml`; or it
matches the fleet's `NNN-Name` numbering (`010-termlink`,
`999-Agentic-Engineering-Framework`, `003-NTB-ATC-Plugin`). Agent names in
this corpus — `e2e-<run>-responder`, `t3433-circuit-addr`,
`reviewer-T-3433-ab12` — match none of them. A `--to` containing `/` is
already a circuit and is used verbatim. `fw sidecar send --level project|agent`
overrides the heuristic when a caller knows better.

## The transition

`sidecar:*` is a **read alias for one release**. Senders write only `inbox:`
(pinned by a test). `inbox.pending()` drains both topics with a **cursor per
topic** — offsets are per-topic and comparing them across topics is
meaningless — and **one shared seen-set**, so a peer mid-transition that posts
to both surfaces once. The shared set is seeded from the pre-T-3433 per-topic
sets, so upgrading re-surfaces nothing already shown.

The e2e harness checks H2/H4 on both addresses, so a peer that has not
switched still closes the loop. Removing the alias is a follow-on: delete
`legacy_topics()` and its callers, one release from now.

## What the hub now does for us — and the one thing we could not measure

Verified here, 2026-09-22, on `inbox:cacc73ea32b121dd/999-Agentic-Engineering-Framework/t3433-probe/t3433-probe`:

- `channel post --ensure-topic` — accepted, offset returned
- `channel subscribe --json --cursor` — envelope served back intact, topic
  echoed with slashes
- `channel cv-keys` — answers (empty index, which is the documented
  process-local caveat, not an error)

**Not verified: `inbox.queued`.** We could not observe a wake event for the
compound id — *and our control could not either*: a bare `inbox:framework-agent`
post watched on `tl-vayovuqm` produced nothing observable from this vantage
point. So this is a blind spot on our side, not a measured compound-id
failure; the two are indistinguishable from here and saying otherwise would be
inventing a result. The question is in agent-chat-arc @1672 for 010-termlink,
who traced the emit to `channel.rs:949`. Until they answer, the wake benefit
that motivated the prefix move is **claimed, not proven**, and this paragraph
is the honest record of that.

## Evidence

| Run | Mode | Verdict | Topics |
|---|---|---|---|
| `f12fa93d` | explicit | PASS 6/6, 19.1s | `inbox:cacc73ea32b121dd/999-Agentic-Engineering-Framework/e2e-f12fa93d-{sender,responder}` |
| `60867b67` | ambient | PASS (H1/H2/H6 + A1), 17.0s | `…/e2e-60867b67-{sender,responder}` |
| `8dbad116` | peer (010-termlink) | see `.context/sidecar/e2e/8dbad116.json` | consult on `inbox:cacc73ea32b121dd/010-termlink` |

Records under `.context/sidecar/e2e/`. Per T-3426's rule the peer run records
whatever it returns — the peer's hops (H3/H6) are theirs by definition, and a
run that ends with their side still open is a recorded result, not a failure.

## Out of scope / follow-on

- **Per-agent signing keys.** Every consult still signs as the shared host
  key (`d1993c2c3ec44c94`), so receipts are self-satisfying. The circuit id
  names the agent; the *signature* still names the host. Filed as follow-on in
  the task's Evolution, per @1641.
- **Retry/escalation** — T-3434 (D-600).
- **Urgent** — separate design.
- **Alias removal** — one release out.
