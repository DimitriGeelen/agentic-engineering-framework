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

## Evidence received: truly fresh-agent load test (1409 sidecar 7a8a3e1c, 2026-11-18 10:40Z)

**Setup:**
- A frozen fixture, with the truth for 20 units committed before any handover was generated.
- A deterministic script wrote one handover per unit, from the unit's own records only.
- 7 rounds, 210 fresh agents: 3 per unit (sonnet, opus, opus). Each got only the handover plus a class excerpt and was asked to NAME the next step, not act.

**Results:**

| Condition | Main set: right next step | Main set: units with a wrong action | Confirmation set: right next step | Confirmation set: units with a wrong action |
|---|---|---|---|---|
| Real records | 7/10 | 3 | 6/10 | 3 |
| With decision lines at the unit, prompt v2 | 10/10 | 0 | 9/10 | 0 |

**Cause of every wrong action:** a decision taken by someone other than the unit's own run (a wave worker deferring a step, or a submission filed centrally) is not recorded at the unit. So every fresh agent re-runs the class's default step.

**Neither fix alone was enough.** Both were needed:
- a "decision" line at the unit, carrying the next step, owner and deadline;
- a prompt that says a recorded decision overrides the class default.

**Other observations:** the three agents agreed on 8-10 of 10 units, so the errors are systematic, not model noise. Read cost was about 18K tokens per unit.

**Limits:**
- The truth was set by the test's builder.
- 7 hand corrections of the scorer, each logged.
- It measured naming the step, not executing it.

**Implication:** the arc journal must be the single place where *any* actor's decision about the unit lands, or resume fails whatever the model. Together with the first measurement, this answers IW-1 toward option B (a fresh agent per event, plus a journal) on evidence. IW-2..IW-4 remain to be answered with the operator.

## Received 2026-11-18 20:51Z (1409, sidecar fb6c390d)

**Load test, repeated after the decision lines were written at the unit:** fresh agents named the right next step in 10/10 and 9/10 units, with 0 wrong actions. Before, it was 7/10 and 6/10, with 3 wrong actions in each set. The independent review found 3 back-filled entries with a wrong time; a repair is running.

**New need 1 — later runs of the same unit.** 167 of 315 units had more than one run. A closed task cannot be reopened: `work-on`, `--status started-work` and `--status issues` all exit 1 on work-completed. 1409's operator decided on 2026-11-18:
- A later run gets NEW instances of every step in the SAME arc, built from the template valid at that time.
- Findings, information and insights carry over. Assumptions carry over marked as assumptions.
- Judgement is formed again, and old check results are not inherited.

AEF today: `fw arc instantiate` (T-5221) always creates a new arc through arc_create. A second instantiation into an existing arc, per-run instances, a predecessor link, and the template version recorded on the instance are all missing. "Arc complete" is defined per arc, not per run.

**Refinement of need 1 (1409 sidecar da96da3b, 21:08Z, operator confirmed): versions are per STEP, not per run.**
- A unit iterates forward. After feedback from step K2 the engine improves, and the unit may redo K2 (a second instance) and go on to K3, or go straight to K3 with the insight. So one unit can hold K1 v1, K2 v2 and K3 v1, each instance recording the template version it ran under.
- Only units that are scanned again get new instances; an engine change alone touches nothing.
- Each engine improvement names the steps it affects and whether their earlier results still hold. "No longer holds" marks that step outdated at every unit that has it, and the step is redone before anything downstream is accepted.

For AEF this means:
- per-step instance versions, with the template version recorded on each instance;
- an "outdated" state that a template change can set across arcs;
- a gate that refuses to accept downstream work over an outdated step.

**New need 2 — scale.** One task per step is about 142,000 task files for one full pass over 10,953 units, and more with each refresh. 1409 is measuring fw command times at 10k, 50k and 142k files in a throwaway copy. AEF's own corpus is about 5,200 task files (915 active, 4,307 completed) and has not been measured at that size. Whether a per-unit step task is the right grain at that size is open.

## Dialogue Log

- 2026-11-18: 1409's message c87d0ee1 received; answers (a)-(d) sent with the facts above;
  inception filed DEFER pending their measurements.
