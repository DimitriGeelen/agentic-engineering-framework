# External review brief — what should an "arc" carry so that it explains itself?

**For:** three independent reviewer models. **From:** the Agentic Engineering Framework
(AEF), task T-3563, 2026-09-29. **Requested by:** the human operator.

This is a design question about knowledge structure, not code. The brief is
self-contained.

---

## 1. What AEF is

AEF is a governance framework for AI coding agents working inside real software
projects. It is a set of structural rules enforced by hooks and gates, not a library:

- **Nothing gets done without a task.** A task is a Markdown file with acceptance
  criteria and verification commands that must pass before it can close.
- **Authority:** the human is sovereign; the framework enforces and logs; the agent
  proposes but never decides. Irreversible actions need human approval.
- **Memory ("context fabric"):** working, project and episodic memory persist across
  sessions, plus decisions, learnings and a component graph, so a cold agent can resume.
- **Inceptions** are exploratory tasks for a single question. They produce a research
  report with a verbatim dialogue log of the human's words, open questions each with a
  disposition and rationale, a recommendation, and a go/no-go decision the human
  records. They are where most of the reasoning lives.
- **Constitutional directives,** in priority order: Antifragility, Reliability (no
  silent failures), Usability, Portability.

**Consumer projects.** AEF is developed in one repository and vendored into many other
projects (`fw init`, `fw upgrade`, a vendored `.agentic-framework/` directory). Each
consumer project runs its own agents under the same rules. Improvements, and defects,
propagate to all of them.

## 2. What an arc is

An **arc** is AEF's container for a feature or initiative that spans many tasks. One arc
typically holds between a few and ~120 tasks. It is a YAML file with, among others:

- `name`, `description` (median 34 words), `status`
- `headline_mechanic` — mandatory (G-062): *"<who> <does what> <observes what
  user-visible result>"*
- `anchor_task` — usually the inception where the arc was conceived
- `scoped_drivers` — up to three arc-specific value drivers
- `demo_evidence` — a path or URL to a captured artefact showing the headline firing
- rarely used: `design_doc`, `decision`

Tasks join an arc through an `arc_id` field.

### What the arc is used for

1. **Container.** It groups the tasks of one initiative, so progress and scope are
   visible as one thing rather than as scattered tasks.
2. **Value drivers and scoring.** AEF scores tasks for Business Value Points (BVP):
   0–5 per driver, weighted. Four global drivers derive from the constitutional
   directives. An arc may add up to three **scoped drivers** that capture what makes
   this initiative valuable beyond the globals, e.g. "determinism" for a replay arc.
   Each driver carries a rationale and a scoring spec; an automated reviewer admits it.
   Tasks also carry a cost estimate, and value × cost gives four quadrants
   (high/low value × low/high cost).
3. **Goal derivation.** The operator's intent is that value flows down a goal
   hierarchy: project objectives → arc (via its drivers) → task. A task's value is judged
   against the goal at the right level.
4. **Closure.** As of today an arc is offered for closure when (L1) no open member is
   unestimated, (L2) no high-value work remains open, (L3) the anchor carries a
   recommendation with a verdict and rationale, and (L4) its recorded demo evidence
   exists and is traceable. The human closes it.

## 3. The problem

The operator's words: *"there should be way more emphasis on headline of an ARC that
describes what it is, what's the background, research decisions made, back and forth.
All the context fabric that we've created … often in our inception."*

**Measured across all 20 arcs:**

| | count |
|---|---|
| arcs with an anchor task | 19 |
| … whose anchor is an inception with a research report | **14** |
| arcs that link a design document | **1** |
| arcs that record their decision | **1** |

So for most arcs the story (why it exists, what was researched, what was decided and
reversed, the operator's own words) **already exists**, one hop away in the anchor
inception. The arc itself never shows it.

**What the headline is today.** A typical example: *"agent crosses the context-budget
threshold without operator relay -> checkpoint.sh fires self-trigger -> handover + resume
via claude-fw -> operator observes multi-cycle continuous session whose iteration
counter, directive, and bounded tier-ceiling are visible in fw resume status."*

It is a precise, demo-able check, and deliberately so: the rule (G-062) exists because
arcs used to be closed on "the substrate is in place" without anything user-visible
working. It succeeded at that. But it does not tell a reader, human or agent, what the
arc *is*, why it exists, or what was decided along the way.

**Why that costs something.** An arc runs for weeks and spans sessions and agents. A
cold agent, a consumer project, or the operator months later meets the arc and has to
reconstruct its purpose from a demo sentence and a list of task titles. Drivers and
scoring are judged against a purpose nobody wrote down on the arc. Closure (L3) asks
whether "the goals were achieved" when the goals are not stated on the arc.

## 4. Questions

Please answer each, then give an overall verdict.

1. **What should an arc carry** so that it explains itself to a reader arriving cold?
   Propose a concrete structure (sections or fields) and say what each is for. Be
   explicit about what should *not* be on it.
2. **Headline versus story.** Should the demo-able headline mechanic stay a separate,
   sharp, testable claim, with a richer narrative beside it, or be expanded into the
   narrative? What is lost either way?
3. **Derived or written?** The material mostly exists in inception artefacts (research
   report, dialogue log, dispositions, decisions). Should the arc's story be *derived*
   from them (generated, linked, summarised), *written* by hand, or both? How do you stop
   a derived summary from going stale, or a written one from drifting from the evidence?
4. **Goals and drivers.** How should the arc state its objective so that its scoped
   drivers, the task scoring, and closure leg L3 ("goals achieved") are all judged
   against the same written statement, and trace upward to the project's objectives?
5. **Evolution.** Arcs change over weeks: scope is cut, decisions are reversed, pivots
   happen. How should an arc record that history without becoming an unreadable log?
6. **For agents specifically.** Much of the reading is done by AI agents with a limited
   context budget. What shape serves an agent that must act on the arc well, as well as
   a human reviewing it?
7. **What would make this fail in practice?** For example, a field that is mandatory
   but filled with boilerplate, which is a known failure mode in this framework.

## 5. Required answer format

End with a verdict block in exactly this shape:

```
VERDICT: green | amber | red | unknown
  green   = the operator's direction is right as stated
  amber   = right direction, with the changes listed below
  red     = this would make arcs worse
  unknown = cannot judge from this brief (say what is missing)
GUIDANCE: required for anything other than green. Concrete and actionable.
PROPOSED STRUCTURE: the arc sections/fields you recommend, one line each.
TOP RISK: the single most important way this could go wrong.
```
