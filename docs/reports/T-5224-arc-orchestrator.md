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

## Evidence received: 1409 first measurement (sidecar a2123b8f, 2026-11-18 09:20Z)

**Sample:** 129 municipality arcs from four waves, each one arc with 13 step tasks.

**Entry-step outcome:**

| Outcome | Units |
|---|---|
| Continued by the timer | 101 |
| Needs a proposal to the operator | 15 |
| Needs an arbitration round | 4 |
| Red continuation | 3 |
| Halted without a record | 4 |
| Portal | 1 |
| Not started | 1 |

**End points:**
- 53 units reach the step before the final check and are carried on centrally.
- **56 units (43%) stand at a step that needs judgment and that nobody starts.** Breakdown:
  - 17 paused at K3;
  - 15 proposals whose researcher step never ran;
  - 7 agent states at the entry step;
  - 6 hanging;
  - 4 halts without a record;
  - 4 red mid steps without a final check;
  - 3 missing a page reader.
- 18 more have red mid steps that were never repaired; only partial results went on.

**Orchestrator cost per unit:** one start per unit (128/128); median 18 turns, 335 s, about 98K tokens of context at the end, 1.12M cache-read tokens and 3.8K output tokens.

**Reload cost:** the core records needed to resume are about 6.5K tokens median (max 13K), plus the brief (about 9K), so a resume is about 16K tokens. A unit's 13 task files are 378 KB, of which only 5 KB are run notes; the rest is template text.

**Load test** (5 units, reading only the arc records):

| Result | Units |
|---|---|
| Right next step, with owner | 1 |
| Right step, but owner and deadline missing | 1 |
| A fresh agent would do the WRONG step | 2 |
| No next step recorded at all | 1 |

- The two wrong-step cases: a stale "next" field, and a deferral decided in a wave report but never written into the arc.
- The no-next-step case: a final check was red 25 times without consequence.
- **Limit:** the worker who ran the test knew the queue reports. A truly fresh agent has not been tested yet; that is 1409's next step.

**1409's reading:**
1. The missing piece is a per-arc journal, not the orchestrator process. Option A (resume the same session) would hide that the record is not resumable.
2. The journal must carry what was tried, what was decided with the reason, and the next step with its owner and deadline. Decisions taken outside the arc (in a wave) must be written back into it.
3. A stale "next" is worse than none, so there should be one writer per event and a check.
4. A resume (~16K tokens) fits a fresh window easily, so a fresh agent per event (option B) is affordable.

**AEF note:** this points toward B plus a journal. Two things are still open before it is a recommendation:
- a truly fresh-agent test;
- the operator dialogue on IW-2..IW-4 (who writes the journal, the plug-in points, governance).

## Dialogue Log

- 2026-11-18: 1409's message c87d0ee1 received; answers (a)-(d) sent with the facts above;
  inception filed DEFER pending their measurements.
