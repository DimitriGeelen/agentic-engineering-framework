# External review brief — agent-to-agent addressing, identity and trust

**For:** three independent reviewer models. **From:** the Agentic Engineering
Framework (AEF), task T-3558, 2026-09-29. **Requested by:** the human operator.

You are reviewing a design question, not code. Please read the whole brief. It is
self-contained, and nothing in it is secret: the fingerprints are public-key
fingerprints and the paths are illustrative.

---

## 1. What the two systems are for

### The Agentic Engineering Framework (AEF)

A governance framework for AI coding agents working inside real software projects.
It is not a library. It is a set of structural rules enforced by hooks and gates:

- **Nothing gets done without a task.** Every edit traces to a task file with
  acceptance criteria and verification commands that must pass before it can close.
- **Authority model.** The human is sovereign and accountable. The framework enforces
  rules and logs everything. The agent has initiative but never decides.
  Irreversible or consequential actions ("Tier 0") need human approval.
- **Memory.** Working, project and episodic memory persist across sessions, so an
  agent that starts cold can resume.
- **Constitutional directives,** in priority order: Antifragility, Reliability (no
  silent failures), Usability, Portability.

Many projects on the same machines run AEF, each with their own agents (called
"co-resident" projects when they share a host). The operator's goal, and the lens
for this review:

> **agents working together efficiently, effectively and securely, with interactive
> communication between them. That still has not worked.**

### TermLink

A machine-wide Rust binary for cross-terminal, cross-session and cross-host
communication between agent sessions. It provides session discovery (Unix sockets at
system paths, which is why it is deliberately machine-wide rather than per-project),
command injection, dispatched worker processes, and a **hub** of named topics.

TermLink treats two topic prefixes as **mail**, with wake events, delivery receipts
and `--await-ack`. Every other topic is a plain append-only log.

- `dm:<a>:<b>` — a direct-message topic named by the two parties' keys
- `inbox:<name>` — a mailbox; what follows the colon is the owner's to define

TermLink has **one cryptographic identity per machine user**
(`~/.termlink/identity.key`). On the host in question every project shares the
fingerprint `d1993c2c3ec44c94`.

**The division of labour:** AEF decides *what, whether and who*; TermLink carries the
messages.

---

## 2. AEF's addressing model: the circuit

The operator ratified a five-level address, the **circuit id**, in rulings D-599 and
T-3433:

```
host  /  hub  /  project  /  session  /  agent
```

It is meant to be **one-to-one at agent or session level**, with a fallback ladder.
When the exact circuit is unknown, drop the rightmost level:
agent → session → project → hub → host. Consult topics are `inbox:<circuit-id>`, for
example `inbox:cacc73ea32b121dd/999-Agentic-Engineering-Framework` (hub/project).

AEF also has a **per-project signing key** (`.context/rail-identity.key`, fingerprint
`bdd184bd89f318e4`), introduced so that posts carry a project-owned identity rather
than the machine's.

---

## 3. What is going wrong: measured, not hypothesised

**F-1. DMs between co-resident projects are not private.** DM topics are named by
TermLink's identity, which is per machine. Two AEF projects on one host therefore
share `dm:d1993c2c3ec44c94:d1993c2c3ec44c94`. That topic already holds 7 messages
from at least 3 projects, each prefixed with a hand-typed project name because
nothing else distinguishes them. The per-project key signs posts but is never used
to *address* them.

**F-2. The ruling's text and the code disagree, and a peer followed the text.** A
later ruling (D-660) adopted TermLink's prefixes and was worded
`dm:<fp>:<fp> / inbox:<agent-id>`: *agent-id*, where the earlier ruling said
*circuit-id*. AEF's code kept the circuit id. A peer project read the text and wrote:
*"we were reasoning about a scheme you have already committed to replace.
Withdrawing the five-level framing; we take D-660."* The operator never intended to
drop the circuit model.

**F-3. Delivery works, consumption does not.** The messages themselves are durable
and arrive. What fails is noticing them:

- One peer's notification rail watched only `dm:` topics. After AEF moved to
  `inbox:` topics, every AEF message to that peer was invisible for about a week, and
  49 unread messages accumulated there. A round trip was measured at 73h05m. The
  peer's own verdict: *"Delivery was never the problem … Consumption is the gap."*
- AEF itself had 7 unread peer messages sitting for about 24 hours, including an
  explicit request for a status readout. Nothing reported them until an alarm was
  built that same day.

**F-4. "Who am I?" has no answer from an ordinary process.** `termlink whoami`, run
from an agent process that is not itself a registered TermLink session, returns
`ambiguous: true` with 173 candidate sessions and no identity. The code treats that as
"no mailboxes" rather than as an error.

**F-5. A circuit id is a name, not a credential.** Anyone who can post to the hub can
put any value in `metadata.from_circuit`. The peer's open question: *is
`from_circuit` load-bearing for trust, or for routing only?*

---

## 4. AEF's current proposal (please challenge it)

Split the problem in two.

**Routing (where a message goes): no TermLink change.** `inbox:` already has full mail
semantics, and its suffix is AEF's to define. So: all agent-to-agent traffic uses
`inbox:<circuit-id>` with the fallback ladder. `dm:<fp>:<fp>` is demoted to a
TermLink transport, valid only between machines whose keys genuinely differ. D-660 is
amended to say so, and peers are told the five-level model stands.

**Trust (who actually sent it): propose a TermLink change.** For a circuit to be
*trusted*, not merely routed, a key has to exist at circuit level (at least per
project), and the recipient or the hub has to verify that the signing key belongs to
the claimed `from_circuit`. That belongs in TermLink's identity layer:

- multiple named identities managed by `termlink identity`, not one per machine user;
- `whoami` resolving to the calling project's identity instead of being ambiguous;
- optionally, hub-side verification of the signer against `from_circuit`.

---

## 5. Questions for you

Please answer each in turn, then give an overall verdict.

1. **Is the routing/trust split right?** Or is it a false separation that will
   produce two partial systems where one was needed?
2. **Where should identity live?** Per machine (today), per project, per session, or
   per agent. Which rung of the five-level ladder should carry a key, and why?
3. **Should `dm:` be demoted,** or should TermLink's `dm:` be re-keyed per project or
   circuit so that one mechanism serves both?
4. **Security.** What are the concrete threats in F-1 and F-5 on a multi-project,
   multi-host setup: spoofed senders, cross-project reading of a shared mailbox,
   replay? Which ones does the proposal close, and which does it leave open?
5. **The real failure is consumption (F-3), not addressing.** Does anything in the
   proposal make agents actually *notice and act on* messages? If not, what is the
   smallest mechanism that would make interactive agent-to-agent communication work
   (wake-up, acknowledgement, escalation when unanswered)?
6. **What is missing** that would make this not work in practice, however clean it
   looks on paper?

## 6. Required answer format

End with a verdict block in exactly this shape:

```
VERDICT: green | amber | red | unknown
  green   = the proposal is sound as written
  amber   = sound direction, but it needs the changes listed below
  red     = do not proceed as proposed
  unknown = cannot judge from this brief (say what is missing)
GUIDANCE: required for anything other than green. Concrete and actionable:
  what to change, and why.
TOP RISK: the single most important thing this proposal gets wrong or leaves open.
```

A non-green verdict with no guidance is not useful. The guidance is the deliverable,
not the colour.
