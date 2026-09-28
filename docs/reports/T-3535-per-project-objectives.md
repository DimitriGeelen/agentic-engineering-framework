# T-3535 — Per-project goals and objectives

**Inception.** Operator-originated, 2026-09-28. Recommendation: **GO**.
**Sequenced behind T-3534** (project identity, arc-020).

## Problem statement

Selection is specified top-down — *"Start from the project goals and objectives. Anything
that does not advance them is not eligible, however tractable it looks."* No such artefact
exists.

| Layer | Status |
|---|---|
| Mission | CLAUDE.md §Project Overview — one sentence, not decomposable, nothing ladders to it |
| Judgement | 4 Constitutional Directives, `policy/value-drivers.yaml` D1–D4 — **scoring axes with no completion state**. You cannot measure how far an arc moves "Antifragility" |
| **Objectives** | **Missing** |
| Work | 20 arcs, each with a mandatory `headline_mechanic:` and a `description:` |

## The reframe: this layer exists to make work DECLINABLE

The first framing here was "selection has nothing to read". That is the smaller half. Look
at the system's actual shape: **20 arcs in progress, 5 stale past 30 days, 325 tasks awaiting
review, 293 of them already carrying a GO.** That is a system with no mechanism for saying
*no*.

The mandate's own clause — *"anything that does not advance them is not eligible"* — is
unenforceable today, and the 20 concurrent arcs are what that looks like. **The objectives
layer's primary job is not to help pick work. It is to make work refusable.**

## Per-project, not framework-owned — the constraint that shapes everything

Operator, 2026-09-28:

> *"Every project has its own objective. We had a project to develop the agentic engineering
> framework, but once you get vendored in, then that's a different project."*

999 is **one project instance**, not the top of the tree. An objectives artefact shipped as
framework content would push our goals into every consumer — a Directive 4 (Portability)
violation, and precisely the consumer-shape conflation class **arc-004** exists to kill.

**The pattern to copy already exists.** `policy/value-drivers.yaml` is per-project: consumers
get their own copy, bootstrapped from the framework template by `fw bvp driver --init` at
`PROJECT_ROOT` (T-2230). Objectives mirror that exactly — **template** in framework content,
**instance** in each project, created at `fw init`. 999's own objectives are then written as a
*consumer* of the mechanism, which dogfoods it and would have caught this framing error.

## More exists at arc level than first credited

`fw arc create` has required `--headline-mechanic` since **G-062** — *"<who> does what,
observes what user-visible result"* — and arc YAML carries `description:` beside it. The
arc-scoped-driver judge shipped earlier today resolves exactly that pair; its evidence line
reads *"arc-level objective from headline_mechanic: + description:"*.

So arcs already have a goal layer, and it is already machine-readable. The gap is narrower
than "no goals anywhere":

| Layer | Status |
|---|---|
| Project headline / goals / objectives | **Missing** — the real gap |
| Project value drivers | **Exists**, per-project, scoreable |
| Arc headline mechanic | **Exists**, mandatory at `fw arc create` |
| Arc goals / objectives | **Partial** — `description:` carries it informally; operator ruling: make explicit and **optional** |

**Why optional is right at arc level.** Mandatory fields on a creation verb get filled with
whatever unblocks the verb. G-062 can demand `--headline-mechanic` because it is one sentence
with a testable shape that `fw arc close` later checks a demo against. Goals and objectives
are prose; made mandatory they become ceremony, and a required field filled to pass a gate is
worse than an absent one because it reads as considered.

## The Watchtower surface

Operator: *"we should actually have a main page in our Watchtower that describes a project,
goals and objectives and features and stuff like that as it goes along."*

An objectives file with no surface is the thing that drifts. The authored/derived split
(IW-1) is what decides whether the page stays true:

| Authored — sovereign, the operator writes it | Derived — computed, always current |
|---|---|
| Project headline, id, name | Which arcs serve which objective |
| Goals and objectives | Arc completion ratios, staleness |
| What is deliberately out of scope | What shipped against each objective |
| | **Arcs serving no objective — the declinable ones** |

*"As it goes along"* is the derived half, and it is the half that makes the page true rather
than aspirational.

Two constraints from the start: the page is **per-project** (Watchtower already runs
per-project on its own port, but the content must come from the project's own instance, never
framework content); and it is a **render surface**, so P-013 applies — a `[REVIEW]` Human AC
is mandatory at close, because layout and reading rhythm cannot be settled by `curl | grep`.

## Sequencing

**T-3534 (project identity) comes first.** A per-project objectives artefact cannot be trusted
to show the right project's goals until *"which project am I"* has a reliable answer. Order:
**identity → objectives → the surface that renders both.** The page showing project name and
id at the top also answers, directly, the question another agent was asking when it had to
ask the operator "is it you".

## Open questions

Filed on the task as **IW-1 … IW-5**: the authored/derived split; whether "feature" is a new
record or a view over closed arcs' headline mechanics; whether 002 already has a shape this
template should come from; whether this folds into arc-007 or opens an arc; and whether
`serves_objective:` is optional plus what an arc serving nothing triggers.

**IW-3 needs the operator** — the T-559 project-boundary gate refuses the cross-project read,
correctly, and it was not bypassed.

## Dialogue log

**2026-09-28 — operator, on per-project objectives:** quoted under *Per-project* above. This
corrected an agent framing that had treated "the project" as this repo, singular.

**2026-09-28 — operator, on arc-level goals:**

> *"An ARC should have its own headline with goals and objectives. That's part of the ARC
> creation. That's not mandatory, it's optional, but it does help."*

**2026-09-28 — operator, on the surface:** quoted under *The Watchtower surface* above.

**Course corrections recorded:** (1) the agent framed the gap as a missing file; it is a
missing decision about focus, evidenced by 20 concurrent arcs with no basis for declining any.
(2) The agent scoped objectives to this repo; the operator's vendoring point makes per-project
instancing the load-bearing constraint. (3) The agent proposed a new arc; on reflection,
opening a 21st arc against a diagnosis of "20 in progress, 5 stale" asks the problem to solve
itself — folded into IW-4 rather than assumed.
