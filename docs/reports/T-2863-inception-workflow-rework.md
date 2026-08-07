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

## F-4 — The map does not codify the process, and its rail is green over one word-set

Operator's meta question: *does the workflow codify our process, and can it be
made deterministic for the logic to follow?*

Authority across the corpus:

| Map | Stage | Rail primitive | Precedence |
|-----|-------|----------------|------------|
| **`aef-task-lifecycle`** | **detail-authority** | **transition-table** | **map wins on detail conflict** |
| `aef-inception-flow` | transitional-subordinate | vocabulary-set | descriptive only |
| `aef-tier0-escalation` | transitional-subordinate | vocabulary-set | descriptive only |
| `aef-dispatch-loop` | transitional-subordinate | vocabulary-set | descriptive only |
| `aef-audit-cron` | transitional-subordinate | vocabulary-set | descriptive only |
| `aef-session-lifecycle` | transitional-subordinate | *none* | descriptive only |

One of six carries authority. So: **no, the workflow does not codify the process.**
`aef-inception-flow` is explicitly "descriptive only — CLAUDE.md prose wins on
conflict".

The inception rail in full (`tools/conformance-registry.yaml`):

```yaml
aef-inception-flow:
  primitive: vocabulary-set
  source: lib/inception.sh
  gateway: decision?
  source_vocab: {anchor: 'case "$decision" in', regex: '([a-z|-]+)\)'}
```

It compares the branch labels on the `decision?` gateway to the `case` arms in
the shell. Green means *the words GO / NO-GO / DEFER appear on both sides*. Not
one transition, not one gate. All five failure instances are outside its reach by
construction, and `.context/audits/2026-08-07.yaml` records it **PASS**.

This is the L-539 class (T-2764): a rail can be correct, cheap, and blind —
check the SET it runs over, not just the predicate.

## F-5 — Determinism exists, is proven once, and the pattern is generative

`aef-task-lifecycle` is not merely checked against a table. `status-transitions.yaml`
is **read at runtime**: `lib/enums.sh:4,14` compiles it to an O(1) associative
lookup, `agents/task-create/create-task.sh:205,416` sources its enums, and
`web/blueprints/tasks.py:151-163` loads it.

```
status-transitions.yaml ──read at runtime──> lib/enums.sh, create-task.sh, web
          └──compared by rail──────────────> aef-task-lifecycle (the drawing)
```

The table is the single source of truth; the code executes from it; the map is
the designable view kept honest by the rail. That is real determinism.

Two senses worth separating:
- **Checked determinism** (exists): map is spec, code is implementation, rail
  proves agreement. Drift becomes impossible.
- **Executed determinism** (does not exist, and probably should not): nothing
  interprets BPMN at runtime. The *table* is executed, never the diagram.

**The forced precondition.** A transition-table rail can only check transitions
that exist as nodes. Today the inception gates are notes on Agent nodes (F-2), so
promoting this map now would make it outrank CLAUDE.md prose while remaining
blind to all five failures — a green rail certifying a happy path. Strictly worse
than descriptive-only.

Ordering is therefore not a preference:

1. Add **Framework · Authority** lane; every gate becomes a node with a refusal edge.
2. Extract **`inception-transitions.yaml`** — sibling of `status-transitions.yaml`.
3. Make `lib/inception.sh` + `update-task.sh` **read** it instead of hard-coding.
4. Flip the registry `vocabulary-set` → `transition-table`.
5. Green → `detail-authority`.

Step 3 is where determinism comes from. Steps 1–2 are prerequisites. Step 4
without them buys a false green.

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
