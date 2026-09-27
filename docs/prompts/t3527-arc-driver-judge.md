# Build T-3527 — the arc-scoped-driver judge agent

You are a TermLink worker. Build **T-3527** only. T-3526 (the BVP score judge) is
already built and closed — read it, reuse it, do not rebuild it.

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
| **the sibling judge** | `lib/bvp_judge.py` + `lib/bvp_judge_cli.py` (T-3526) | your shape reference — mirror its structure, its CLI wiring, its test layout |
| **the static checks you WRAP** | `lib/arc-driver-review.sh` (T-3429) | scorable / distinct / distinguishes. They stay, untouched. You add the judgement they cannot make |
| the shared placeholder predicate | `lib/ac_placeholder.py` (T-3528) | if you need "is this text an unfilled template stub", import this. Do not write a fourth one |
| the sticky guard | `lib/bvp_sticky.py` (T-3523) | operator-adjusted scoped drivers are untouchable |
| the worker pattern | `fw reviewer T-XXX --dispatch` (T-1951) | reuse this shape; do not invent a second |

**If you find yourself writing a second definition of anything, stop.** Arc membership
in this repo reached five implementations of one predicate disagreeing three ways, and a
full day went into consolidating them.

## What the judge does

Reviews a **proposed or approved arc-scoped driver** and returns a verdict. It is not the
proposer of the driver — that separation is the point: producer-not-judge restored by
separating parties rather than by putting the operator back in the approval path. The
operator keeps only an after-the-fact veto (T-3523).

The yardstick is **the arc's goal and objective** — D-662's goal-hierarchy criterion
applied at arc level rather than task level. `.context/arcs/<slug>.yaml` and the arc's
anchor task carry it. The case to catch is a driver that distinguishes nothing the arc
actually pursues — §Arc-Scoped Driver Suggestion Workflow's D6 criterion ("rationale must
explain what each driver distinguishes that globals don't") made checkable.

**Do not wait on T-3410 and do not fix the estimator's keyword detectors** — out of scope.
They report no-signal on 83% of 3,350 tasks (T-3408), which is exactly why the written-down
arc goal is the yardstick instead of them.

## The specific defect you must fix: OBS-559

`lib/arc-driver-review.sh` currently reports a **tooling failure** — the estimator being
unimportable — as a **driver-quality failure**. That is the session's most-repeated defect
class, hit six times in one day:

> **A check that cannot run must not answer as a check that ran and judged.**

When the scorer is unavailable, your judge emits `UNKNOWN` **with guidance**, never a fail.
Pin it with a test that makes the scorer genuinely unavailable — not a mock that returns an
error, an actual unimportable state.

## Read this before you write a single test — it is the trap you are walking into

T-3526, your sibling slice, closed **9/9 ACs with 34 passing tests** and shipped a **false
green**. `fw bvp judge T-3471` returned GREEN on a task whose entire Acceptance Criteria
section was the unfilled template, because the sufficiency check was a 15-character length
floor and the template's first stub is 17 characters.

**Why 34 green tests could not see it:** the suite had a fixture named `PLACEHOLDER_ACS`
containing `TBD` / `fix it` — short *authored* text, which exercises only the length leg.
**No test used a real placeholder-AC task as a fixture.** A fixture named after the class it
does not contain is worse than a missing fixture, because the coverage gap reads as covered.
That is L-678; read it.

Applied to you, concretely:

1. **Your fixtures must be real inputs, not inputs shaped like what you expect to find.**
   Use an actual arc YAML with an actual weak driver on it. If you write a fixture called
   `BAD_DRIVER`, make sure it is bad in the way the corpus is actually bad, not in a way
   you invented.
2. **Point the finished agent at live data before you close.** T-3526's defect took one
   command against one real task to find, and no amount of unit-green would have surfaced
   it. Run your judge against every scoped driver on every in-progress arc and read the
   verdicts. The audit currently WARNs that six live drivers have neither a handler nor a
   scoring spec — those are your real-world cases.
3. **When you fix a proxy-measurement bug, pin the fixture that distinguishes the two
   implementations**: a test that restores the pre-fix predicate and asserts the same
   fixture flips verdict. See `tests/unit/test_bvp_judge.py::test_length_only_substantiveness_is_the_mutant_this_fixture_kills`.

## Hard constraints

- **A non-green verdict must carry actionable guidance.** The contract enforces it by
  raising, so a bare rejection is unshippable. Guidance means *what to change about the
  driver*: "the rationale restates D2 (Reliability) rather than naming what this arc
  tracks that D2 does not — say what it distinguishes, or withdraw the driver".
- **UNKNOWN, never green, when you cannot judge.** And pin the control: a judgeable driver
  must NOT come back UNKNOWN, or the agent has failed safe into uselessness.
- **`--none` stays human-only.** A negative ruling (this arc has no scoped drivers worth
  tracking) is sovereign; an addition is not. Do not touch that gate.
- `fw arc close` / `fw arc abandon` are closure decisions and remain human-gated (T-1671,
  earned over four incidents). Out of scope, confirm by diff.
- Same model as the producer is fine for now. A multi-model panel is OUT of scope (D-662 IW-5).

## Reachability — the AC most likely to be faked

**Verify the live agent path with NO override flags.** T-3523 opened
`fw arc set-scoped-weight` to agents behind the reviewer, so this is load-bearing now.

Hours before this dispatch, a guard was written on this exact verb, tested with
`--i-am-human`, and passed — while being **structurally unreachable**, because §ACD refused
agents before the guard ran. The pass proved nothing. That is L-573: *a gate can be green,
tested, and structurally unreachable at the same time.* A second instance the same day was
a `pre-merge-commit` hook keyed on `MERGE_HEAD`, which does not exist at that moment.

So: invoke the way an agent invokes. No `--i-am-human`, no `--from-watchtower`, no
`FW_ALLOW_*`. If the path refuses you, that is a finding to record, not an obstacle to
route around.

## Governance — this repo governs its own development

- Verb gates only. No `--force`, `--skip-*`, `FW_ALLOW_*`. **A gate that refuses you is
  a finding to record, not an obstacle to route around.**
- `bin/fw vendor self` for any vendored path you touch (`lib/`, `agents/`) **before**
  `--status work-completed`, never after — after, focus is cleared and there is no task
  to run it under (OBS-250).
- Scope it: `FW_VENDOR_ONLY="<your paths>" bin/fw vendor self`. Never `FW_VENDOR_ALL=1`;
  other workers hold files dirty.
- Stage files by name. Never `git add -A` or `git add -u`.
- **Register first, fix second.** A structural flaw you find goes in
  `.context/concerns.yaml` — the register, not the inbox — before or alongside the fix.
- **Do not certify your own output.** Close on checks that ran, not on your judgement
  that the work is adequate. If a check cannot run, say so and leave the criterion
  unticked — an assertion without its check is an open task, not a closed one.

## Deliverable

A working agent, real tests, T-3527 closed through the gates with its ACs ticked by
evidence. Write a short report to `docs/reports/T-3527-arc-driver-judge.md` and **commit
everything, including the report** — a worker earlier in this arc wrote its report and
exited without committing it; it survived only because the orchestrator noticed.

Include in the report: the verdicts your judge returned against the live in-progress arcs,
and whether any surprised you.

If you cannot finish, park the task with what is done and what is not. Do not leave it
half-closed.
