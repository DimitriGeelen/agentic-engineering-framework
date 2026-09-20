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
