# Build T-3526 — the BVP score judge agent

You are a TermLink worker. Build **T-3526** only. Do not build T-3527 (the arc-driver
judge) — it is dispatched separately and you would collide.

**Its acceptance criteria are already written on the task.** They are your contract;
read them first. They were written by the orchestrator, who holds the design context,
so you should not need to invent scope.

## Authority

Operator decision **D-662**, recorded on T-3524 which reached GO. Read both:

- `.tasks/completed/T-3524-separate-the-judge-from-the-producer-a-b.md` — the inception,
  its five answered questions and the scoped slices
- `.context/project/decisions.yaml` — D-661 and D-662

## What already exists — use it, do not reinvent it

| thing | where | your relationship to it |
|---|---|---|
| **the verdict contract** | `lib/judge_verdict.py` (T-3525) | **IMPORT IT.** No local states, no local guidance rule, no local `reviewable()` |
| the proposer | `agents/termlink/bvp-estimator/estimator.py` | writes `bvp_scores_proposed:`; you judge that proposal |
| the sticky guard | `lib/bvp_sticky.py` (T-3523) | operator-adjusted scores are untouchable |
| the worker pattern | `fw reviewer T-XXX --dispatch` (T-1951) | reuse this shape; do not invent a second |
| AGENT.md house style | `agents/termlink/bvp-estimator/AGENT.md` | follow it |

**If you find yourself writing a second definition of green/amber/red, stop.** Arc
membership in this repo reached five implementations of one predicate disagreeing three
ways, and a full day went into consolidating them.

## What the judge does

Reviews a **proposed** BVP score and returns a verdict. It is not the producer of the
work and not the proposer of the score — that separation is the point:
producer-not-judge restored by separating parties rather than by putting the operator
back in the approval path. The operator keeps only an after-the-fact veto (T-3523).

Judges against, per D-662:

1. **Presence** — are acceptance / quality criteria there at all?
2. **Sufficiency** — are they good enough to justify the score claimed?
3. **Goal hierarchy** — map the work to its objective at the right level: the task's
   own goal, the arc's, or the project's.

The operator's answer on (3) is what made this buildable: the yardstick is **the goal
hierarchy, which is written down** — not the estimator's keyword detectors, which report
no-signal on 83% of 3,350 tasks (T-3408) and so cannot be a yardstick. **Do not wait on
T-3410 and do not fix those detectors** — out of scope.

## Hard constraints

- **Open tasks only.** Closed work is never rescored. Use `judge_verdict.reviewable()`.
- **A non-green verdict must carry actionable guidance.** The contract enforces it by
  raising, so a bare rejection is unshippable. Guidance means *what to change*: "D2 is
  claimed at 4 but no reliability criterion is stated — add one or lower it to 1".
- **UNKNOWN, never green, when you cannot judge.** And pin the control: a judgeable
  task must NOT come back UNKNOWN, or the agent has failed safe into uselessness.
- You may propose a score change; you may **not** write `bvp_scores:`.
- Same model as the producer is fine for now. A multi-model panel is OUT of scope.

## Governance — this repo governs its own development

- Verb gates only. No `--force`, `--skip-*`, `FW_ALLOW_*`. **A gate that refuses you is
  a finding to record, not an obstacle to route around.**
- `bin/fw vendor self` for any vendored path you touch (`lib/`, `agents/`) **before**
  `--status work-completed`, never after — after, focus is cleared and there is no task
  to run it under (OBS-250).
- Scope it: `FW_VENDOR_ONLY="<your paths>" bin/fw vendor self`. Never `FW_VENDOR_ALL=1`;
  other workers hold files dirty.
- **Do not certify your own output.** Close on checks that ran, not on your judgement
  that the work is adequate. If a check cannot run, say so and leave the criterion
  unticked — an assertion without its check is an open task, not a closed one.

## Three traps this session paid for, all in your area

1. **A guard that cannot fire.** Twice today a guard was written that no live path
   reached — once keyed on `MERGE_HEAD` during `pre-merge-commit`, absent at that
   moment; once behind a gate that refused agents before the guard ran. **Test the path
   an agent actually takes.** A pass obtained with `--i-am-human` proved nothing.
2. **Unknown read as favourable.** Four instances today. `if verdict:` is truthy for
   every state including red — use `judge_verdict.may_proceed()`.
3. **A verdict with nothing to act on gets routed around.** `[REVIEWER]` reached 7 uses
   against 412 for `[REVIEW]` because it produced verdicts nobody could act on. The
   guidance is the deliverable; the colour is only the routing.

## Deliverable

A working agent, real tests, T-3526 closed through the gates with its ACs ticked by
evidence. Write a short report to `docs/reports/T-3526-bvp-score-judge.md` and **commit
everything, including the report** — a worker earlier today wrote its report and exited
without committing it; it survived only because the orchestrator noticed.

If you cannot finish, park the task with what is done and what is not. Do not leave it
half-closed.
