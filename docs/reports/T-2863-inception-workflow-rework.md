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

## F-6 — Ticking a Human AC is the function's stated purpose, not a leak (A2 falsified)

A2 said *"`@auto-tick-on-decide` ticking a `### Human` AC is always wrong."*
That is wrong. `lib/inception.sh:292` — the function's own header:

> **T-1324: Tick the Human AC that authorizes the inception decision.** After
> `fw inception decide` writes the Decision block, the templated `[REVIEW] Review
> exploration findings and approve go/no-go decision` Human AC is structurally
> satisfied by the same command — leaving it unchecked keeps the task in
> partial-complete forever (G-008 contributor).

The reasoning is sound *given its premise*: if the human ran `decide`, the human
approved, so the approval AC is satisfied by construction.

**The premise is what fails.** `decide` has entry paths that are not the human:
`--i-am-human`, `--from-watchtower`, `--skip-sovereignty`. T-2857 arrived through
`--skip-sovereignty` with the Watchtower log ending 2.5h earlier, and the tick
fired anyway. The tick reads *"a command ran"* and writes *"a human approved."*

So the fix is not "never tick a Human AC" — it is **tick only when the caller is
provably the human**, i.e. condition the tick on the authority channel that let
`decide` through. That is a Framework-lane decision (F-2), which is why it had no
node to hang on.

Two asymmetries worth recording. The Agent branch requires a `## Recommendation`
section to exist before it ticks (`elif in_agent and has_recommendation`); the
Human branch has no such condition. And a **third caller** exists —
`do_inception_sweep` (`lib/inception.sh:866`, comment: `# Tick the Human AC`)
ticks in **batch** across many tasks, with no `decide` and no human anywhere in
the call.

## F-7 — The recommendation gate enforces one third of the contract it prints

On refusal, `do_inception_decide` prints (`lib/inception.sh:493-496`):

```
The task file must contain a ## Recommendation section with a non-commented:
  **Recommendation:** GO / NO-GO / DEFER
  **Rationale:** Why (cite evidence)
  **Evidence:** Bullet list of findings
```

The predicate behind it, `audit_inception_recommendation`
(`lib/task-audit.sh:117`), is a single grep:

```
^[[:space:]]*[-*]?[[:space:]]*\*\*Recommendation:\*\*[[:space:]]*\*{0,2}[A-Za-z]
```

**Rationale and Evidence are never checked.** T-2857 is the proof — it passed
this gate with its Evidence block still holding the template comment, verbatim,
unedited.

L-539 class again (T-2764): the message describes a three-part contract, the
predicate covers one part, and the two are far enough apart in the file that
nobody reads them together.

## F-8 — The template already knows the recommendation is a prior

Inside T-2857's untouched Evidence block, shipped by the template:

> `<!-- Add evidence bullets as exploration progresses (file paths, commit
> hashes, test results). The filing-time recommendation can be revised before fw
> inception decide. -->`

The prior/finding distinction that IW-1 proposes to introduce **is already
written down, in the template, at the exact spot where it matters.** It is
documented intent with zero enforcement: nothing checks that the revision
happened, and the placeholder that says "revise me" is itself sufficient to pass
the gate.

This lowers the cost of IW-1 considerably. It may not need a `prior:` /
`recommendation:` schema split at all — it may need the sentence the template
already contains to become a predicate.

## F-9 — Three machines can write or ratify a recommendation; none requires evidence

Trace one inception end to end:

| # | Step | Who | Evidence required |
|---|------|-----|:---:|
| 1 | T-2204 refuses filing without GO/NO-GO/DEFER | Framework | none — no exploration has happened yet |
| 2 | Hourly cron `inception-retrofit-rec-hourly` **injects a DEFER stub** into any active inception with an empty block (`lib/inception.sh:909,955,998`) | Framework | none |
| 3 | `decide` gate checks a `**Recommendation:** <word>` line exists (F-7) | Framework | none |
| 4 | `@auto-tick-on-decide` ticks the `[REVIEW] … approve go/no-go decision` Human AC (F-6) | Framework | none |
| 5 | Task archives, rendered as human-approved | Framework | — |

**No step in that chain requires a single finding, and step 4 manufactures the
human's signature from the fact that step 3 returned zero.** Instance 5 is not
"the recommendation is requested too early". It is that the framework can
complete the entire filing→approval loop with no human and no evidence, and the
artifact it leaves behind is indistinguishable from one where both were present.

That is also why this went unseen: every individual gate is defensible, each was
added to fix a real incident (T-679, T-973, T-974, T-1324, T-1503, T-2204), and
the composition was never drawn — because the lane that would have drawn it does
not exist (F-2).

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

**2026-08-07 — agent, correcting itself on IW-2:** I had answered IW-2 at
confidence 3 with "almost certainly no, CLAUDE.md says NEVER check a `### Human`
AC." Reading `lib/inception.sh:292` shows that ticking the approval AC is the
function's *entire original purpose* (T-1324) and that removing it re-opens a
real leak (G-008). A2 is falsified. The confidence was high and the answer was
wrong in the same direction as the prior it was meant to check — worth noting,
because IW-2 was the one question I had not planned to re-examine.

**2026-08-07 — agent, on this task's own filing:** T-2863 was filed with a GO
before the map was opened, because the T-2204 gate requires a recommendation at
filing. That prior was partially refuted within the hour. Recorded here rather
than quietly amended, because it is the cleanest available evidence for instance 5.
