# Arc Delivery Session

> **Purpose:** drive every open arc to a **closed** state by delivering the
> functionality it promised — not by declaring substrate done. This is the
> counterpart to `bvp-driver-session.md`: that bundle decides *what is worth*
> doing, this one gets it *shipped*.
>
> **Status (2026-08-05):** 18 arcs exist. 14 `in-progress`, 4 `draft`,
> **0 ever closed.** That number is the problem this prompt is for. Read it as a
> standing measurement, not trivia — an arc population that only grows is a
> system that starts work and never finishes it.

You are running an **arc delivery session** for the Agentic Engineering
Framework. Your objective is not "make progress on arcs". It is:

> **For one arc, produce a captured instance of its `headline_mechanic` firing,
> and hand the closure decision to the operator.**

Everything below serves that sentence.

---

## 1. What an arc is, in delivery terms

An **arc** (`.context/arcs/<slug>.yaml`) is a named capability with:

- `headline_mechanic:` — `<who> <does what> <observes what user-visible result>`.
  This is the arc's definition of done. `fw arc create` refuses substrate-only
  phrasing, so it is already a *deliverable* statement, not a plumbing statement.
- `status:` — `draft` | `in-progress` | `closed` | `abandoned`
- `scoped_drivers:` — up to 3 approved local drivers, weight ≤6 (see
  `bvp-driver-session.md`)
- constituent tasks — every task carrying `arc_id: <slug>` or `arc_id: arc-NNN`

**Closure is gated (G-062, §ACD).** `fw arc close <id>` requires
`--demo <path|url|none>` — a wire-level artefact traceable to the arc — and it
**refuses under `$CLAUDECODE=1`**. You cannot close an arc. You can only make it
closeable and hand it over. Treat that as the shape of the job, not an obstacle.

---

## 2. Picking the arc — one at a time

**Do not fan out across arcs.** A population of 18 with 0 closures is already
evidence that breadth is not the constraint. Pick one, take it to a demoable
increment, hand it over, then pick the next.

Selection order:

1. **Closeable now** — an arc whose `headline_mechanic` is already satisfiable
   with what exists. Check first: `fw arc show <id>`, then ask whether you could
   capture the demo *today*. If yes, that is the arc. Closing one arc is worth
   more than advancing three.
2. **Blocked on one slice** — an arc whose mechanic needs exactly one deliverable
   that nobody has built. Bounded, so it fits a session.
3. **Highest BVP** among the rest, scoped drivers included.
4. **`draft` arcs last.** A draft arc has never been committed to. Promoting one
   while 14 are in-progress adds to the number this prompt exists to reduce.

**Do not create a new arc** unless the operator asks. Starting is the easy half.

---

## 3. The delivery loop

Run this per arc. Every step has an output; if a step produces nothing, say so
rather than proceeding as if it did.

### Step 1 — Read the anchor, state the mechanic

Read the arc YAML **and its anchor task body in full** (Problem Statement, Scope
Fence, Risks, Decisions). Then write, in your own words:

> The mechanic is: `<who> <does what> <observes what>`.
> Today, that fires / does not fire, because …

If you cannot state why it does not fire, you have not read enough. Do not
proceed from the arc's name.

### Step 2 — Name the gap as a deliverable, not as substrate

The §ACD failure mode is answering "what is missing?" with a *component*
("the seam isn't wired", "tests aren't green") when the mechanic asks for an
*observable result*. Convert:

| Substrate framing (wrong) | Deliverable framing (right) |
|---|---|
| "the overlay API is in place" | "an operator opens `/designer` and sees live task state on the map" |
| "dispatch envelopes are captured" | "an operator replays a failed dispatch and gets the same outcome" |
| "the gate refuses correctly" | "an agent trips the gate and unblocks itself without asking" |

If your gap statement names no observer and no observed result, rewrite it.

### Step 3 — Slice it

One slice = one deliverable that moves the mechanic measurably closer, sized to
**one session** (CLAUDE.md §Task Sizing Rules). File it with
`fw work-on "<name>" --type build`, and set `arc_id:` so the arc's population and
the stale-arc audit (`FW_STALE_ARC_DAYS`, default 30) can see it.

Arc-tagged build tasks carry a mandatory **`## Evolution`** section (T-1717).
Fill it at every slice boundary — what you learned that wasn't known at filing,
what in the plan no longer fits, what that triggered. The close gate blocks on an
empty one, and it is the record that stops spec-vs-build divergence becoming
folklore.

### Step 4 — Build, with the gates doing their job

Standard framework discipline applies and is not optional here:

- Real ACs before editing source (G-020). Tick each `[x]` **as the work lands**,
  not when the gate fires (T-1831 C-4).
- `## Verification` lines that assert the *deliverable*, not its proxy. A line
  that curls a URL and checks only for HTTP 200 asserts almost nothing — on a
  multi-project host it may not even be your server (T-2802). Assert content.
- Commit every meaningful unit (P-009). Push.
- **Never tick a `### Human` AC.**

### Step 5 — Capture the demo

This is the step that has never happened for any arc, and it is the whole point.

A demo is a **wire-level artefact traceable to the arc**: a `meta.json`, a
stream-json capture, a screencast, a live URL, a saved terminal transcript.
Capture it **while the mechanic is firing**, not afterwards from memory.

Write it to a stable path — `docs/reports/` or alongside the arc — and reference
it from the arc's anchor task. `fw arc close --demo <path>` will want exactly
this.

**`--demo none` exists and requires `--justification` (≥30 chars), logged for
audit.** Do not reach for it because capture was awkward. If the mechanic
genuinely cannot be captured, that is a finding *about the mechanic*, and it
belongs in the arc — not in a bypass log.

### Step 6 — Hand the closure decision over

Write `## Recommendation` into the **anchor task** (GO / NO-GO / DEFER, rationale,
evidence). Then surface it as a **Watchtower URL, not a CLI command** (T-2347):

- Arc detail: `{watchtower_url}/arcs/<slug>`
- Close form: `{watchtower_url}/arcs/<slug>/close`
- Anchor review: run `fw task review <anchor-id>` and quote the URL it emits
  **verbatim** — the route is class-dependent and must not be typed from memory
  (T-2125).

For 2+ tasks, paste the verbatim output of `fw task review-batch T-A T-B …`.
Never hand-type a link table.

---

## 4. Exit conditions

Stop the loop and report when **any** of these is true:

- **Demo captured, recommendation filed, URL surfaced.** Success. Say which arc
  and what the demo shows.
- **The mechanic turns out to be wrong.** The arc promises something nobody
  wants, or something already delivered elsewhere. Say so — a mechanic
  correction is a real outcome. Propose `fw arc abandon` and let the operator
  decide.
- **The slice exceeds one session.** File what you learned, commit, hand over.
- **Budget.** 225K warn → small bounded slices only. 255K urgent → finish and
  commit. 285K critical → wrap-up only (the gate enforces it).

---

## 5. Failure modes — the ones this prompt exists to prevent

Each of these has cost the project a closure.

**Substrate-vs-deliverable conflation (§ACD, G-062).** The phrases
*"forward work, not a closure blocker"* and *"substrate is in place"* are §ACD
violations in plain text. If you find yourself writing either, you have
substituted the component for the result.

**Default-to-OPEN.** If ≥2 operator pushbacks on the same arc have not been
resolved by a captured headline-mechanic instance, the arc is **OPEN** regardless
of evidence filed since. The pattern is the signal. Origin: T-1626, T-1633,
T-1641, T-1667, T-1670 — four incidents, the fourth an agent auto-closing an arc,
which is why `fw arc close` now refuses under `$CLAUDECODE=1`.

**Shipped-but-unclosed slice leak (L-434).** 35 arc-007 child slices sat in
`started-work` with all Agent ACs ticked and code rendering live — never run
through `--status work-completed`, so none entered the review queue and none were
visible to `/approvals`, handover, or audit. The arc read as further from done
than it was. Close your slices as you finish them.

**False green.** A verification line that asserts nothing is indistinguishable
from one that asserts everything — which is why 371 of them accumulated before
anyone noticed (T-2732/T-2734). A red line gets looked at; a vacuous green never
prompts anybody. Assert content, and verify on the **live user surface**: commit
≠ visible ≠ done.

**DEFER as a hedge (T-2144).** `DEFER` is for evidence gaps, not confidence gaps.
If the artefact is complete and you still don't want to commit, recommend GO or
NO-GO with the rationale you actually have. The static-scan detector
`defer-as-hedge` will flag it anyway.

**Breadth as progress.** Advancing five arcs by one slice each produces five arcs
that are still open. One closed arc changes the number.

---

## 6. What you may not do

- Close an arc (`fw arc close` — operator only, structurally enforced)
- Approve a scoped driver (`fw arc approve-driver` — operator only)
- Tick a `### Human` AC
- `--force` past any gate, or suggest the operator do so, without first listing
  each unchecked Human AC
- Change a task's ownership away from `human`
- Treat a system or task notification as operator approval

A broad directive ("proceed as you see fit", "deliver the arcs") delegates
**initiative**, not **authority**. When a gate blocks you, that gate exists
precisely for the moment you are in. Ask.

---

## 7. Session opening

Start every arc delivery session with:

```
fw context init
fw arc list          # or Watchtower /arcs
fw metrics
```

Then state, before touching anything:

1. Which arc you picked, and which of the four selection rules applied
2. Its `headline_mechanic`, quoted
3. Whether it fires today, and why not
4. The one deliverable you intend to produce this session
5. What artefact will serve as the demo

If you cannot fill all five, you are not ready to start — read the anchor again.

---

## See also

- CLAUDE.md §Arc Completion Discipline (G-062) — the gates, verbatim
- CLAUDE.md §Arc Action Handoffs (T-2347) — URL-not-CLI, with the route table
- CLAUDE.md §Arc-Scoped Driver Suggestion Workflow (T-1925) — what happens at arc
  creation, the *other* end of this lifecycle
- `policy/prompts/bvp-driver-session.md` — ranking and driver vocabulary
- `policy/prompts/artefact-template.md` — research-artefact shape (C-001)
