# T-2863 — Reworking the inception workflow

**Task:** T-2863 (inception) · **Opened:** 2026-08-07
**Status:** exploration in progress — S-1 partially done, awaiting operator dialogue

C-001 artifact. Written before the research, updated incrementally.

---

## Prior (stated so it can be falsified)

Filed at creation time because the T-2204 gate requires one:

> **GO.** Five instances in two weeks. The root is that the framework asks for
> the conclusion before the evidence, then records the answer as the finding.

This task is its own worked example: the gate made me write a GO before I had
opened the map. Whether the prior survives is recorded below.

---

## F-1 — The map already exists, and it already shows the root cause

`aef-inception-flow` is in the corpus (v1, 10 nodes / 9 flows, arc-014 T-2558).
Its second node reads, verbatim:

> `[service] file inception — fw work-on --type inception` **(T-2204:
> recommendation + rationale required at filing)**

and the only other decision-bearing node is the `decision?` gateway after the
collapsed exploration subProcess. **There is no node anywhere in the flow that
revises the recommendation after exploration.** The map is a faithful drawing of
the defect: a conclusion enters at filing, travels untouched through exploration,
and is read out at the gateway.

So the first correction to my prior: this is not undocumented. It is documented
accurately and was read as a happy path.

## F-2 — All five failures live in a lane the map does not have

The framework's Authority Model is three-tier:

```
Human     → SOVEREIGNTY
Framework → AUTHORITY
Agent     → INITIATIVE
```

Lane structure across the corpus:

| Map | Framework · Authority | Agent · Initiative | Human · Sovereignty |
|-----|:---:|:---:|:---:|
| `aef-tier0-escalation` | ✅ | ✅ | ✅ |
| `draft-trigger-handling` | ✅ | ✅ | ✅ |
| **`aef-inception-flow`** | **❌** | ✅ | ✅ |
| `aef-task-lifecycle` | **❌** | ✅ | ✅ |

Now place the five instances:

| # | Instance | Actor |
|---|----------|-------|
| 1 | T-2862 — decide preflight deadlocks on a self-referential AC | **Framework** |
| 2 | T-2442 — inception schema deadlock | **Framework** |
| 3 | T-2857 — `--skip-sovereignty` + `@auto-tick-on-decide` ticking a Human AC | **Framework** |
| 4 | T-2861 — C-001 artifact-first vs the background write guard | **Framework** |
| 5 | Root — T-2204 requires a recommendation before evidence exists | **Framework** |

**Five for five.** Every failure is a Framework-Authority action, and the
inception map has no Framework-Authority lane. The gates are currently encoded as
*parenthetical notes on Agent nodes*, which renders them as things the agent does
rather than as gates with their own preconditions, states and failure edges.

That is why the root was legible on the map and still invisible: read as an Agent
node, "recommendation + rationale required at filing" says *the agent supplies a
recommendation*. Read as a Framework node, the same words say *the framework
demands a conclusion before any evidence exists*. Same text, and only the second
reading is actionable.

**This answers IW-5**, and it reframes S-1: the job is not to draw a new map. It
is to add the missing lane to the existing one and re-home every gate into it —
at which point the failure edges have somewhere to attach.

## F-3 — What the missing lane needs to carry

Gates that currently have no node of their own:

- **T-2204 recommendation-completeness** — refuses filing without GO/NO-GO/DEFER.
  Four producer legs + consumer + hourly cron backstop.
- **G-067 Open-Questions readiness** — refuses source edits until ≥1 IW-N exists.
  (Fired on this very task, correctly.)
- **Decide preflight AC check** — refuses `decide` while any agent AC is
  unchecked. **This is the T-2862 deadlock.**
- **`@auto-tick-on-decide`** — ticks marked ACs on decide, including, as T-2857
  showed, `### Human` ones.
- **Agent-decide block** (`$CLAUDECODE=1`) plus its `--i-am-human` /
  `--from-watchtower` / `--skip-sovereignty` bypass edges. T-2857's decision
  arrived through one of these and the map shows none of them.
- **C-001 artifact-first**, and its collision with a write guard (T-2861).

## Prior: partially refuted

- **Wrong:** "the workflow is undocumented / needs mapping." It is mapped, and
  the map is accurate.
- **Wrong in emphasis:** I framed the root as purely *timing* (recommendation too
  early). Timing is the mechanism; the reason it went unseen for so long is
  *representation* — the actor was never drawn.
- **Survives:** the GO, and instance 5 as the root defect.

<!-- S-2 (walk the instances across the revised map) and S-3 (conformance rail)
     pending operator dialogue on IW-1..IW-4. -->

---

## Dialogue Log

**2026-08-07 — operator:** *"seems to be systemic can we document the inception
workflow in the workflow designer and investigate / rework it together?"*
Correct on systemic — five instances, four hit live in one session. The premise
that it needs documenting turned out to be false (F-1); the map exists and is
accurate. What it lacks is the Framework lane (F-2). Proposal put to the operator:
amend `aef-inception-flow` rather than draft a new map, adding Framework ·
Authority and re-homing the six gates in F-3 into it.

**2026-08-07 — agent, on this task's own filing:** T-2863 was filed with a GO
before the map was opened, because the T-2204 gate requires a recommendation at
filing. That prior was partially refuted within the hour. Recorded here rather
than quietly amended, because it is the cleanest available evidence for instance 5.
