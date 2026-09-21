# T-3396 — Peer-consult sidecar: real always-on listener, cooperative yield-point delivery

## Origin

Filed 2026-09-20 out of a live chat dialogue that started as a Q1/Q2 selection
review of T-2918 ("fw peer subscribe uses event poll <session> which never
observes hub-aggregator events"). T-2918 had surfaced a genuine Sovereign
question — four narrow candidate fixes, none obviously right — and the
operator asked to walk through it conversationally rather than pick from a
forced list.

## Findings

### T-2918's actual problem (recap, full detail in T-2918 Investigation)

`fw peer subscribe` is a cron-driven 30s poll-once against TermLink's
hub-level event aggregator. That aggregator is a pure real-time broadcast
(`tokio::sync::broadcast`) with no cursor/replay capability — confirmed
against TermLink source, not CLI help text (the CLI's `--since` flag is
silently dropped in `--hub` mode, with no warning in `--json` mode). A
poll-once caller against a bus with no memory structurally cannot avoid
missing events emitted between polls.

### Prior art the original T-2918 investigation missed

Two earlier passes at the same underlying problem exist in this repo's own
history, neither cross-referenced by T-2918's same-day investigation:

**T-1135 (2026-04-12, inception, GO the same day).** "Persistent TermLink
agent sessions — always-listening receptionist per project." Designed and
cross-repo-negotiated with the TermLink project (`/opt/termlink`, response at
their T-967): a persistent per-project agent session, tagged
`persistent,receptionist`, exempted from TermLink's PID-based cleanup sweep,
health-checked and respawned via `session.needs_restart`. TermLink's own
estimate: 3 small code changes, ~2 hours. Reached GO. **Never built** — the
only follow-up task (T-1140) was an auto-generated duplicate self-pickup,
correctly DEFERRED as structural noise five months ago (2026-04-20). Nothing
replaced it. The design aged in place, agreed but dormant.

**arc-011 §5 (`docs/architecture/parallel-execution-aef.md`, adversarially
reviewed in `docs/reports/arc-011-grill-me-responses.md`).** Solves the
*delivery* half of a sibling problem — write-collision prevention between
parallel dispatch workers, not peer-consult — but the mechanism is the same
shape. Explicitly proposed and explicitly rejected PTY-injection on an
apparently-idle terminal: an agent mid-turn is single-threaded and
uninterruptible, and no external observer can prove a real yield point exists
merely because the terminal looks quiet — injection risks corrupting the
input stream the agent is actively consuming. Chose instead: a cheap,
deterministic (explicitly *not* `claude -p` / LLM-backed) sidecar process that
holds the transport connection and writes a flag + heartbeat timestamp; the
*agent's own harness* cooperatively polls that flag at a yield point it
controls (leading candidate: before every file-write tool call — chosen for
the write-collision case specifically). A heartbeat-staleness self-check lets
the agent detect its own sidecar has died ("gone deaf") and refuse to act
rather than trust a flag nobody is updating. Several sizing questions were
left explicitly open (heartbeat tick/threshold, flag shape/priority byte).
Only a stripped single-host sliver shipped: `agents/dispatch/yield-point.sh`
— a plain file-flag check, no sidecar process, no heartbeat, no priority
byte, scoped narrowly to file-write refusal.

### Why this matters

The operator, asked to reflect on the four T-2918 candidates, independently
recalled a "sidekick" design from memory — an always-on listener, message
queue, priority, flag-raising, cron-monitors-the-flag, deliver via PTY inject
when the terminal looks idle except for urgent interrupts. That recollection
matches T-1135 + arc-011 §5 closely, with one specific, deliberate divergence:
the built (well, designed) system does NOT use idle-triggered PTY injection —
it was tried, named as the "prior attempt," and rejected for the reason given
above. The correction was surfaced in dialogue rather than silently
substituted.

## Dialogue Log

**Q (implicit, via task selection):** Which of T-2918's four narrow directions
should be taken?

**Operator:** Asked instead for the underlying problem, the architectural
challenge, and the real options to be explained conversationally — "Give me
options... have the interaction with me."

**Claude:** Explained the poll-vs-broadcast mismatch and the four narrow
candidates with their real costs (persistent daemon + supervision burden;
accept silent loss; cross-repo ask on someone else's timeline; re-scope
arc-003's already-GO'd mechanic).

**Operator:** "What we want is the [sidekick] for interactive conversation
that we worked on... a sidekick that's listening all the time... it sets a
flag... the cron job monitors that flag... looks for the active session...
we could have a queue where the queue can be prioritized... a flag is raised
that there are new messages... use PTY inject when the cursor is silent...
with the exception of the urgent message that warrants an interruption."

**Claude:** Searched task corpus and docs (`fw recall`, grep across
`.tasks/`, `docs/reports/`, `docs/architecture/`) and found T-1135 and
arc-011 §5. Reflected back: the sidecar/flag/heartbeat/priority-byte parts
match closely; the PTY-inject-on-idle delivery mechanism does not — that
specific piece was proposed and explicitly rejected in the arc-011 ADR, for
a stated, still-valid reason (uninterruptible single-threaded loop; no
external proof of a safe point). Flagged that neither T-1135 nor arc-011's
sidecar was ever actually built, and that none of T-2918's four candidates
had accounted for this prior art.

**Operator:** "Let's go to the Royal and the Correct Long Term Road. Let's
pack it full out." (Read as: build the real thing — the arc-011-shaped
design, not idle-triggered PTY injection — properly scoped, not a stub.)

**Claude:** Proposed recording the decision on T-2918 and opening this
inception to scope the real build, rather than jumping straight to code
(per this repo's own G-020 / Task Sizing rules — new subsystem, cross-repo,
more than 3 files — build must not start before scoping). Operator confirmed
("yes").

## Outcome

- T-2918 `## Decisions` updated with the chosen direction and rationale
  (2026-09-20).
- This inception (T-3396) filed to resolve the parts that were never decided
  in either prior pass (yield-point granularity for peer-consult specifically,
  heartbeat sizing, flag shape, current cross-repo persistence state,
  sidecar identity model) before any build task is written.
- Recommendation filed as **GO** on *scoping and building* — the open
  questions above are the inception's job to resolve with the operator, they
  are not reasons to defer starting it. See task file `## Recommendation` for
  full rationale and `## Open Questions` for the disposed (deferred,
  evidence-backed) IW-1 through IW-6 items.

## Cross-Host Design Amendments (T-3397, 2026-09-21)

Continuation of this inception's design under T-3397, once cross-host scope
was confirmed real (the fleet genuinely spans multiple hosts, not a
single-host deployment). Full joint-analysis dialogue with TermLink in
`.tasks/active/T-3397-resolve-t-3396-open-questions-iw-1iw-6-a.md`; this
section records the two amendments that change the buildable spec itself.

**Uniform path, not a fast-path-plus-exception.** Correctness cannot be
conditioned on traffic mix — if cross-host delivery must sometimes work, it
must be engineered to work, regardless of what fraction of traffic hits it.
The sidecar's delivery, ack, and liveness mechanisms are ONE path, built
cross-host-capable from the start; same-host is the degenerate case of that
path (same host, same hub), not a separate code path or a later add-on. A
same-host performance optimization (skipping trust-bootstrap/auth overhead
for co-located agents) is explicitly deferred — see the identity amendment
below for why that optimization is more dangerous than it first looks.

**Amendment 1 — the three-state ack must name its cross-host blind spot
explicitly.** The design's delivered / undelivered / stuck-but-unconfirmed
ack was originally specified as inferred from local evidence (the sender or
a supervisor can tell "the message landed but nobody acted on it" from "the
message never arrived") by reading the receiving agent's own session
transcript on local disk. That evidence source does not exist across a host
boundary — there is no remote-transcript primitive, and a wedged receiver
cannot be expected to self-report (a wedged receiver is precisely what
"stuck-but-unconfirmed" is trying to detect). Left unamended, the two states
collapse into each other cross-host and the ack silently degrades from
three-state to two-state without ever saying so — reconstructing exactly the
"declared broken while actually just busy" misdiagnosis class this design
exists to avoid.

**Spec change:** the third ack state is `UNKNOWN` when the evidence source
that would distinguish delivered-but-idle from actually-stuck is unavailable
(i.e. whenever sender and receiver are not co-located and no remote
equivalent has been verified to exist). `UNKNOWN` is a valid, expected,
non-error terminal state cross-host — never silently promoted to `DELIVERED`
or demoted to `UNDELIVERED`. Before any cross-host build relies on a
same-host-style transcript read, that mechanism must be re-verified to work
(or not) across a host boundary — it has been verified same-host only.

Message offsets are hub-scoped (TermLink hubs do not federate — a topic's
offset on hub A and hub B are unrelated numbering). Any ack that references
"offset N" must therefore key on `conversation_id` or an explicitly
hub-qualified offset, never a bare integer, once the message can cross a
hub boundary.

**Amendment 2 — same-host is the WEAKER identity case, not the stronger
one, and the deferred optimization must reflect that.** TermLink confirmed
against their own source that co-resident agents on a shared host today all
sign with one host-wide key — so TermLink's own sender-identity check, which
does catch a cross-host impostor, is structurally unable to distinguish two
same-host agents claiming each other's identity. Consequence for this
design: the same-host fast-path optimization named above (skip
trust-bootstrap/auth for co-located agents) was pointed at exactly the case
that currently has the *weakest* identity guarantee, not the strongest.

**Spec change:** that optimization stays deferred (still correctly out of
scope for the initial build — it is a Q2 performance item, not a
correctness gate), but when it is revisited the framing must be "what
per-agent identity do we add for the same-host case", never "what
authentication can we skip because the agents are co-located." Recorded now,
before any build, because it is a cheap doc note today and a wire-format
change if discovered after the fact.

**Amendment 3 — G-060 resolved: direct cross-post, and the credential
precondition that decision does not remove.** TermLink hubs do not
federate — a topic named X on hub A and hub B are unrelated logs with
independent offsets, so "post to a topic and the peer sees it" is false
across a hub boundary. Two shapes were weighed: a routing layer, or direct
client-driven cross-posting via the existing `channel post --hub <addr>`
primitive. Decided **direct cross-post, no routing layer**, on two
independent grounds: (1) AEF's own address grammar already carries `hub=`
explicitly, so "where to send it" is already solved without new
infrastructure; (2) a routing layer is not neutral to the identity plane —
it either forwards the signed envelope verbatim (a transport hop that buys
nothing) or re-originates it, and re-origination makes `sender_id` the
relay's, which either fails TermLink's own sender-binding check (`-32014`,
`channel.rs:787`) or launders attribution if it doesn't. Direct cross-post
is the only shape that keeps the signature end-to-end.

**Spec change — credential precondition must be explicit, not implied.**
"The address names the hub" reads as though reachability follows from
addressing; it does not. `channel post --hub <addr>` resolves the target
hub's HMAC secret from a matching profile in `~/.termlink/hubs.toml` and
hard-bails with no match. Every sending agent therefore needs a
**profile + secret + TOFU pin for every hub it may address** — an N×M
credential-distribution cost, not a one-time setup step, since it scales
with both the number of senders and the number of hubs. The spec must
name this explicitly as a deployment precondition (credentials provisioned
per sender per addressable hub, refused loudly when absent — the CLI
already refuses; AEF's own layer must not paper over that refusal with a
retry or a silent skip).

**Amendment 4 — a cross-hub post either succeeds or fails loudly; the
sidecar owns its own retry.** An earlier finding (relayed, then corrected,
then retracted across three passes — see T-3397 task history for the full
audit trail) initially suggested TCP cross-hub posts could silently
misdeliver via TermLink's offline queue. Reproduced against the shipping
binary, this does not hold: TCP cross-hub posts bypass the offline queue
entirely (`termlink-cli/src/commands/channel.rs:1096` — "BusClient is
Unix-only at the wire level. Direct authed RPC; no queueing on failure").
Measured: posting to an unreachable address returns `Connection refused`;
posting to a real, down `hubs.toml` address returns `No route to host`;
in both cases the queue stayed empty (`pending=0, dead_letters=0`) — no
silent misdelivery to spec around.

**Spec change.** The contract is simpler and stronger than a
buffered-queue model would have been, but it supplies no free
retry-on-blip: a transient network failure is a loud, synchronous,
non-zero-exit failure with a named cause, full stop. **The sidecar's own
retry/backoff policy for a failed cross-hub post is therefore part of this
design, not TermLink's responsibility** — undesigned as of this writing,
tracked as an open item on T-3397. One residual, not tested either
direction and irrelevant to AEF's TCP-only cross-host design: two *local*
hubs addressed by different Unix socket paths on one host would still
share TermLink's one queue with no destination column, since the queueing
branch is taken for any non-TCP `--hub`.

**Amendment 5 — IW-2 (liveness) and IW-3 (ack shape + flag-file format)
resolved: concrete specs, drawing on TermLink's frozen-husk and
delivery-obligation primitives rather than reinventing either.**

**IW-2 — liveness must be a capability canary, not a timestamp.** TermLink's
own frozen-husk incident (their words: "a long-lived process can freeze with
every surface green — live PID, heartbeat stale forever") took them 3 tasks
plus a canary that distinguishes REGRESSION from pre-fix to actually catch.
A bare "last write timestamp" heartbeat has the identical blind spot here: a
sidecar wedged on a blocked network call still has a recent PID and a stale
timestamp that *looks* like healthy idle, because "idle" and "hung" both
present as "not writing right now."

**Spec:** the sidecar's liveness signal is two fields, not one —
(1) a monotonic sequence counter incremented once per event-loop tick
(proves the loop is scheduling at all), and (2) the timestamp and outcome of
the most recent **self-probe** — a synthetic round-trip through the sidecar's
own inject path (write a loopback message to itself, confirm it was
processed) run on the same cadence as the cron fallback tick (default 30s).
A monotonic counter alone catches a fully-stopped loop; the self-probe
additionally catches a loop that is scheduling but whose actual delivery
capability is broken — the two failure modes TermLink's incident showed do
not imply each other. State file: `.context/sidecar/liveness.yaml` —
`{identity, seq, last_probe_at, last_probe_ok, last_probe_latency_ms}`.
Stale/hung is `seq` not advancing across two expected ticks, OR
`last_probe_ok: false` — either alone is sufficient to declare not-live; a
recent `seq` advance with `last_probe_ok: false` is exactly the frozen-husk
shape TermLink hit (scheduling fine, delivery broken) and must not be
masked by only checking one field.

**Cross-host extension (not a later add-on — required from the first build,
per the uniform-path decision above):** for every hub the sidecar addresses,
liveness additionally requires a per-hub capability probe + version floor
check before that hub is treated as a valid send target — reusing TermLink's
own `arc-live-probe`/fleet capability-canary machinery rather than building
a parallel one. TermLink's own measurement (~1000-commit fleet staleness,
T-2415: reachable + authenticating + version-floor-exempt + structurally
incapable, all at once) is why this is an acceptance gate and not a
follow-up: a hub can pass every other check and still not serve the RPC the
sidecar needs.

**IW-3 — ack shape and flag-file format, reusing TermLink's dedupe/
delivery-obligation pattern rather than reinventing exactly-once.**

*Message identity:* every outbound message carries a caller-generated
`client_msg_id` (UUID), mirroring TermLink's own `client_msg_id`+LRU-dedupe
primitive. This makes the sidecar's own retry (Amendment 4 — TermLink
supplies no retry-on-blip) naturally idempotent: a retried send with the
same `client_msg_id` is a duplicate to be deduped on the receiving side, not
a new message, regardless of how many times the caller retries after a loud
synchronous failure.

*Wire/file shapes:*
- **Message file** — `.context/sidecar/outbox/<client_msg_id>.json`:
  `{client_msg_id, from, to, hub, conversation_id, urgent, body, created_at}`.
  `hub: null` means same-host (degenerate case of the uniform path, per the
  traffic-mix resolution above). `conversation_id` is mandatory, never a
  bare offset — offsets are hub-scoped (G-060, no federation) and only
  meaningful within the log that produced them.
- **Flag file (dirty-bit)** — `.context/sidecar/outbox/<client_msg_id>.flag`,
  written by a separate atomic `touch` *after* the message file's write
  completes, so the flag's existence is itself the durability signal: if the
  flag exists, the message file is guaranteed fully written (partial writes
  can only ever produce an orphaned message file with no flag, never a flag
  pointing at incomplete content).
- **Delivery-obligation ledger** — `.context/sidecar/awaiting-ack.jsonl`
  (append-only, one row per state transition — mirrors TermLink's
  `awaiting_ack.sqlite` role without taking a SQLite dependency AEF doesn't
  otherwise have): `{client_msg_id, target, hub, state, deadline, ts}`.

*Three-state ack, with the explicit deadline TermLink's own incident
showed is load-bearing:* `STORED` (message+flag durably on disk — the
sender's confirmation the moment the API call returns, never contingent on
anything downstream succeeding) → `INJECTED_NOW` (fast-path fired before
the caller's return) or `INJECTED_LATER` (cron delivered after a wait) →
terminal. Cross-host, per Amendment 1, the delivered/stuck distinction
collapses to `UNKNOWN` when the local-transcript evidence source is
unavailable. TermLink's own live incident this session (`channel post`
returning `delivered-unconfirmed`, confirmed only by reading the topic back)
is the concrete argument for the deadline requirement: **`INJECTED_LATER`
without an explicit deadline is indistinguishable from hung forever** — the
husk class wearing a success label. Spec: every `awaiting-ack.jsonl` row
carries a `deadline`; a row past its deadline with no terminal state
transitions to `UNKNOWN` (not silently dropped, not silently promoted),
exactly mirroring the cross-host ack rule from Amendment 1 rather than
introducing a second timeout semantics alongside it.

**Exit note:** this closes the design-level content of IW-2/IW-3 per
T-3396's Scope Fence (design only — no sidecar code under either task ID).
Build task(s) implementing this spec are filed separately once T-3397's own
Agent ACs are complete.

## Cross-references

- T-2918 — fw peer subscribe uses event poll <session>, the task that
  surfaced this inception.
- T-1135 — original receptionist design, GO 2026-04-12, never built.
- T-1140 — duplicate self-pickup of T-1135, DEFERRED 2026-04-20.
- `docs/architecture/parallel-execution-aef.md` §5, §6 — the sidecar/flag/
  heartbeat ADR, arc-011.
- `docs/reports/arc-011-grill-me-responses.md` — adversarial review of same.
- T-2323 — AEF-IC-1, write-collision yield-point granularity, sibling
  open question, still `captured`.
- T-1820, T-1818, T-1819, T-1804 — peer-consult framework-side history.
