# T-5224: Optional arc orchestrator

**Status:** inception, exploring. DEFER until 1409's measurements arrive (evidence gap).
Trigger: 1409, sidecar c87d0ee1 (2026-11-18), relaying their operator.

## The need

An arc can have an owner for its whole life who holds the context of what happened in it. When
the owner ends (time limit, long wait, crash, full context), the arc is continued from its own
record, the way a session is continued through handover and resume, possibly by a newer model.
It is optional per arc ("should not be everywhere").

## The trigger (1409, measured)

Each municipality is one arc with 13 step tasks, created from a class and a template arc. Until
13 Nov a per-unit orchestrator carried the unit through. Then K1 changed to "the orchestrator
submits two confirmation judgments to the pool and ends; a deterministic timer continues".
Result: every judgment outcome (judges disagree, no entry found, entry is a topic page) has no
owner. 20 units are parked with steps nobody starts, and the context of what the search tried
lived only in the ended session.

## What AEF has today (2026-11-18)

| Carries | Scope | Arc-level? |
|---|---|---|
| Arc record `.context/arcs/<id>.yaml` (id, name, status, anchor_task, headline_mechanic, description, close decision/evidence, drivers) | arc | yes, but no owner field and no log of what happened |
| `fw arc` create, instantiate (T-5221), start, focus, show, tag, close, review, abandon | arc | no handover, no resume |
| Arc focus (`.context/working/arc-focus.yaml`) | session | one arc per session |
| Handover / resume / compact recovery | session | no |
| Episodic summary | task (at close) | no |
| `fw bus` result ledger | task | no |
| Wake paths: sidecar notices (T-5211/T-5222), cron, TermLink dispatch | project | could carry arc events |

Missing for "arc handover + arc resume": an optional owner field, a per-arc journal enough to
resume from, verbs to write and load it, and a wake on events inside the arc.

## Options (1409's framing)

- **A.** The orchestrator stays and is resumed.
- **B.** The owner is a role: a fresh agent is woken per event, reads a per-arc handover, and writes one back.
- **C.** A timer plus a driver, with no owner.

1409's load test decides between them: can a fresh agent, reading only the arc's records, state
what was tried, what was decided and the next step?

## Pending evidence (from 1409, as text)

1. How many units hit a judgment outcome, and at which steps.
2. Token cost of an orchestrator per unit, and of a reload after a wait.
3. The load test on five real units.

## Dialogue Log

- 2026-11-18: 1409's message c87d0ee1 received; answers (a)-(d) sent with the facts above;
  inception filed DEFER pending their measurements.
