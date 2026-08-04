# Arc Continuous-Delivery Prompt

Paste this to an agent at session start when the objective is **to drive open arcs to
closure with delivered functionality**, not to do isolated task work.

Written against the T-2715 rulings (IW-5, IW-9, IW-10, IW-18, IW-19, IW-21, IW-23) and
CLAUDE.md §Arc Completion Discipline (G-062). Terminology is AEF's throughout — if a term
below is unfamiliar, read it in CLAUDE.md before starting rather than guessing.

---

## Your objective

Deliver the **headline mechanic** of each open arc — the user-visible thing the arc
promised — and close the arc on evidence. Substrate is not delivery. An arc whose tasks
are all complete but whose mechanic has never fired is **open**.

You are not being asked to work tasks. You are being asked to make mechanics fire.

## Standing constraints

- **Nothing gets done without a task.** `fw work-on` before any edit. No exceptions.
- **Initiative is delegated, authority is not.** You choose what to work on and how. You
  do not close arcs, tick `### Human` ACs, record inception decisions, use `--force`, or
  bypass a gate. When a gate blocks you, the gate wins — surface it, do not route around it.
- **One task = one deliverable. One bug = one task.**
- **Commit, then close.** Closing first leaves component mining no commit of its own, so
  it attributes neighbouring files and misfires P-013 (OBS-141).
- **File and continue** (IW-9). A finding becomes its own task with ACs, RCA and a
  regression test, homed to whichever arc owns it. Do not absorb findings into the task
  you are on.

## The loop

Run this until the arc's HV set is dry, then move to the next arc.

### 1. Orient on the arc, not the backlog

```
bin/fw arc list                      # all arcs (* marks focused); status is draft|in-progress
bin/fw arc show <id>                 # headline_mechanic, scoped_drivers, demo_evidence
bin/fw task review <anchor-task>     # the arc's anchor and its Recommendation
```

State out loud, before working: **what must a user be able to DO when this arc closes?**
That sentence is the `headline_mechanic`. Everything below serves it.

**If the arc is `draft`, it is not running.** A draft arc accrues no work and cannot close.
Transition it first — `bin/fw arc start <id>` (draft → in-progress; refused from any other
state, T-1852). As of 2026-08-04, **4 of 18 arcs are draft**, including three of the four
onboarding arcs. An arc left in draft looks like an arc and delivers like a folder.

### 2. Pick by quadrant, not by convenience

```
bin/fw bvp --quadrant hv-hc --include-proposed    # in scope for arc exit
bin/fw bvp --quadrant hv-lc --include-proposed    # in scope for arc exit
bin/fw bvp arcs                                   # arc-level ranking (slow: ~3 min)
```

**`--include-proposed` is not optional today, and you must know why.** Bare `fw bvp` ranks
only *confirmed* scores. Confirmation is a human sovereignty boundary
(`fw bvp confirm T-<id> --i-am-human`, T-1924) and **0 of 2,584 tasks have ever been
confirmed** — 2,582 carry estimator-proposed scores and none have been ratified. So bare
`fw bvp` returns an empty set, always, and an empty set reads exactly like "no high-value
work remains" — which is the arc-exit condition in step 5. Drop the flag and the gate
passes vacuously.

Treat proposed scores as **advisory**: they order your work, they do not certify an exit.
If you are about to propose closure on the strength of an empty HV set, say in the handoff
which scores it was computed over.

The **HV/HC and HV/LC** quadrants gate arc exit. Anything else does not hold the arc
open (IW-19). The set is **evolving, bounded by quadrant** — newly discovered work is
BVP-estimated on arc assignment and enters scope if it lands high-value, so the set can
grow while you work. That is intended, not scope creep.

Cost orders work *within* the arc. It never decides whether a task is in scope.

### 3. Work the task under normal governance

`fw work-on T-XXX` → real ACs before editing (G-020) → progressive AC ticking as each
piece lands, not retroactively when the gate fires → `## Verification` commands that
actually judge (L-387, T-2738: a captured test run discards its exit code; guard the
pass-marker grep or keep the exit code).

**Route ACs by audience, not by how subjective they sound.** Grep-able Expected →
`[REVIEWER]` in `### Agent`. Human taste → `[REVIEW]`. Subject is *agent* experience →
`### Agent` self-eval, never a Human prefix (T-2143).

### 4. Capture demo evidence MID-FLIGHT

**This is the ruling most likely to be skipped, and skipping it is what keeps arcs open.**

The moment the headline mechanic actually fires during your work — the page renders, the
worker completes, the gate refuses the thing it exists to refuse — **capture the artefact
then** (IW-18). A screencast, a stream-json, a meta.json, a live URL.

Do not assemble a demo at closing time. By then the work feels finished and the artefact
feels like paperwork, which is exactly when it gets waived. Mid-flight it is just
recording that something worked.

Evidence this works: 3 of 14 arcs already hold populated `demo_evidence` while
in-progress. Evidence for the failure mode: **0 arcs have ever closed.**

### 5. On completing any arc task — recalc, then pick

```
bin/fw bvp --quadrant hv-hc --include-proposed
bin/fw bvp --quadrant hv-lc --include-proposed
```

An **empty result is the exit condition** — which is precisely why the `--include-proposed`
warning in step 2 is load-bearing rather than pedantic. An empty set from a mechanism with
no data is indistinguishable from an empty set from finished work. There is no separate close-readiness
heuristic and no polling. If the recalc returns tasks you thought were done with,
**report which tasks re-surfaced and why** — which driver moved them, and from what. An
unexplained bounce-back from closure trains `--force`, which defeats the mechanism.

### 6. Exit is a GATE, not a formality

Before proposing closure:

1. Recalc the arc's scores.
2. Any task still in HV/HC or HV/LC → **return to the arc. Do not close.**
3. HV set dry → is there a `demo_evidence` artefact, captured mid-flight, that shows the
   **headline mechanic** firing?

HV-complete is the **trigger** (when it is time to close). The demo is the
**permission** (whether you may). HV-complete never substitutes for the demo — completing
every HV task can be entirely substrate, and substrate-vs-deliverable conflation is the
named §ACD failure.

Then hand the closure decision to the operator:

```
bin/fw arc review <id>               # emits the /arcs/<id>/close URL + QR code
```

Paste **the URL that command emits, verbatim.** Do not synthesise it from memory — the
class of slip where an agent types a plausible-looking handoff path is T-2125, and it cost
four consecutive mis-routed handoffs in one thread. `fw arc review` mirrors
`fw task review T-XXX` and exists for exactly this hand-off (T-1962).

**You do not run `fw arc close`.** It refuses under `$CLAUDECODE=1` (T-1671), and
surfacing CLI instead of the Watchtower URL for arc actions is the T-2347 slip. The
`fw arc close --demo …` form is a headless fallback for cron/SSH only.

## Sentences that mean you have already violated §ACD

If you find yourself writing any of these, stop and re-read step 6:

- "substrate is in place"
- "forward work, not a closure blocker"
- "the remaining items are follow-ups"
- "the mechanic will fire once X lands"

The framework pre-wrote these because it has watched them happen four times.

## Default-to-OPEN

If **≥2 operator pushbacks** on the same arc have not been resolved by a captured
headline-mechanic instance, the arc is **OPEN** regardless of what has shipped since. The
pattern is the signal.

## Reporting cadence

Per arc, report: mechanic (one sentence) · HV set remaining (count + names) ·
demo artefact captured (path or "none yet, and why") · what a user can do today that they
could not before.

That last line is the arc. If you cannot write it, you have not delivered yet.

## Session hygiene

- Commit every meaningful unit (P-009). Push both refs.
- Watch the budget ladder: 225K warn · 255K urgent (small bounded work only) ·
  **285K critical — Write/Edit/Bash are BLOCKED, only commit/push/handover/read**.
  Do not plan work you cannot finish inside the remaining window.
- `fw handover --commit` before ending. Never end with unpushed commits.
