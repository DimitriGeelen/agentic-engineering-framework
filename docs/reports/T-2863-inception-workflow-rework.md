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

## F-10 — And a sixth machine stamps the empty recommendation **CONFIRMED**

T-2857's archived body carries this, written 1 second after the decide:

```
## Recommendation Verdict (v1.0)
- **Overall:** CONFIRMED
- **Claims:** 2
| `T-2856` | task | ✓ pass |
| `T-2854` | task | ✓ pass |
```

Watchtower renders it directly beneath the Agent Recommendation
(`web/templates/inception_detail.html:416-419`).

What the validator actually checks (`lib/reviewer/recommendation_claims.py:1-30`)
is **referent existence**: a `T-XXX` claim passes if a file by that name exists
in `.tasks/`. `CONFIRMED` is defined as *"≥1 claim, all verifiable claims pass."*

T-2857's rationale mentioned T-2856 and T-2854 in passing prose. Both task files
exist. Two claims, two passes, **CONFIRMED** — on a recommendation whose Evidence
block was the untouched template comment and whose central assertion the spike
refuted forty minutes later.

The module is internally honest: its docstring says *"Advisory only."* The
failure is in the **word that reaches the operator**. `CONFIRMED` under a
recommendation is read as *this has been checked* — and something was checked,
just not the thing the word implies. Nothing in the rendering distinguishes
"the identifiers resolve" from "the reasoning holds".

This makes the F-9 chain six steps, not five, and the last one actively adds
false confidence rather than merely failing to add real confidence.

## F-11 — The readiness predicate exists and is wired one transition too late

**Operator reframe (2026-08-07), and it relocates the defect.** An inception is
an interactive conversation. Through research *and* dialogue we gather enough
clarity, insight and background to decide whether to proceed and in what
direction. **At that point** — and not before — the inception may be put forward
for approval. What is wrong is that it is put forward before those requirements
are met.

This is a better statement of the problem than F-8's. I was arguing about the
*field* (should it be called `prior:` or `recommendation:`); the operator is
arguing about the *transition* (when is this thing eligible to be shown to a
human at all). The field question is downstream of, and mostly dissolved by, the
transition question.

**Test: is there a readiness check at the put-forward transition?**

`fw task review` → `emit_review` (`lib/review.sh`) is the put-forward verb. It
creates `.context/working/.reviewed-<id>`, which is the token `decide` requires.
Before creating it, it validates exactly two things:

1. `audit_inception_recommendation` — a `**Recommendation:** <word>` line exists
   (F-7: one grep; Rationale and Evidence unread).
2. T-2139 review-handoff homework detection.

It does **not** check open questions, assumptions, exploration-plan execution,
whether the artifact contains findings, or whether any conversation occurred.

**And the check that would do it already exists.** `check_disposition_gate`
(`agents/task-create/update-task.sh:768`) requires every `IW-N` to carry a
disposition and a rationale. Its trigger (`:1583`):

```bash
if [ "$NEW_STATUS" = "work-completed" ]; then
    check_disposition_gate
fi
```

**It fires on `work-completed` — after the operator has already approved.** It
guards the filing cabinet, not the decision. The one substantive readiness
predicate in the system sits downstream of the transition it should protect.

```
file ──> explore + converse ──> PUT FORWARD ──> operator decides ──> completed
                                     │                                   │
                          checks: rec line exists              checks: IW disposed
                                  (F-7: one grep)                  ← the readiness
                                                                     check, here
```

**Second hole: `deferred` counts as disposed.** T-2857 was approved and archived
with **all four** open questions at `disposition: deferred`, IW-4 at
`confidence: 0`, whose own rationale reads verbatim:

> *"Unmeasured. **This is the go/no-go evidence** — a gate with a high
> false-positive rate on historical commits is a gate agents will learn to
> bypass."*

The task named its own go/no-go evidence, recorded it as unmeasured, and was
approved anyway — and the disposition gate would have passed it even had it
fired, because it checks that a *disposition string is present*, not that the
question is *answered*. Form, not substance. (When the spike finally ran, IW-4's
answer inverted the recommendation.)

**Third hole: the conversation is unrepresented.** The operator's model has two
inputs — research *and* dialogue. C-001 §7 asks for a `## Dialogue Log` in the
artifact, and nothing anywhere checks for one. Half of the stated readiness
condition has no representation in any gate, any schema, or any node on the map.

**Consequence for the map (S-1).** The Framework-Authority lane needs a state the
workflow currently lacks: *exploration complete / ready for approval*, distinct
from *filed* and from *approved*, with the put-forward transition guarded by the
readiness predicate rather than by a string-presence check. Instances 1–5 all
attach to that missing state or to the transition into it.

## F-12 — Readiness = agent judgment on top of a self-consistency floor

**Operator (2026-08-07):** *"we want agent to evaluate readiness and propose
approval once it deems enough readiness, correct"*

Yes, and it maps cleanly onto the Authority Model:

| Tier | Role in readiness |
|------|-------------------|
| Agent · INITIATIVE | evaluates readiness, **proposes** approval |
| Framework · AUTHORITY | refuses to **transmit** a proposal that contradicts the agent's own record |
| Human · SOVEREIGNTY | decides |

The agent's judgment is the deliverable — *"I have enough clarity to recommend a
direction"* is not mechanically derivable and should not be. But judgment alone is
exactly what failed: on T-2857 the agent proposed approval while its own task file
recorded IW-4 at `confidence: 0` with the rationale *"this is the go/no-go
evidence."* Self-assessment with no floor is instance 3.

**The floor does not require the framework to judge readiness.** It only has to
check the proposal against the agent's *own recorded state* — a self-consistency
check, not a domain judgment:

- an `IW-N` declared blocking and left unanswered contradicts "ready"
- an Evidence block still holding the injected placeholder contradicts "I explored"
- a missing `## Dialogue Log` contradicts "we converged in conversation"

Each is a contradiction between two things the agent itself wrote. Cheap,
deterministic, content-blind — and it answers IW-6's determinism question in the
affirmative for this transition without requiring any semantic understanding.

**One schema addition makes it mechanical.** Today `disposition: deferred` is
indistinguishable from `answered` to every gate (F-11 hole 2), so *"we deferred
the one question that decides this"* passes. Some deferrals are legitimate — a
question the build will answer does not block the direction call. The distinction
the operator's principle needs is whether the question blocks the go/no-go, and
that is a per-question field:

```
- **IW-4: How many past commits would this gate have caught?**
  confidence: 0
  blocking: true          # ← does this block the direction decision?
  disposition: deferred
  rationale: Unmeasured. This is the go/no-go evidence.
```

Readiness floor = **no `blocking: true` question left unanswered.** T-2857 states
"this is the go/no-go evidence" in prose today; the field turns that sentence into
a predicate. The agent still decides which questions are blocking — judgment stays
with initiative — but having declared it, the agent cannot propose past it.

**Where it wires:** `emit_review` (`lib/review.sh`), the put-forward verb, which
today checks only that a `**Recommendation:**` line exists. Putting the readiness
check here rather than at `work-completed` (F-11) lands it on the transition it is
meant to guard. No new verb needed.

## F-13 — Not-ready is an instruction to continue, and the deficit names the action

**Operator (2026-08-07):** *"and if it deems not to be ready it should initiate
more research, more testing or more dialogue or more of all of these"*

This makes the readiness evaluation a **loop**, not a terminal gate, and it makes
the failing check a **router** rather than a refusal. Not-ready is not a stop; it
is an instruction to continue, and *which* deficit fired determines *which* mode
of work resumes:

| Deficit detected | Remediation the agent initiates |
|------------------|--------------------------------|
| blocking `IW-N` unanswered, question is empirical | **testing** — run the spike |
| blocking `IW-N` unanswered, question is a direction/preference call | **dialogue** — ask the operator |
| Evidence block empty or placeholder | **research** — the exploration did not happen |
| no `## Dialogue Log` | **dialogue** — the conversation half is missing |
| assumption stated, never validated | **testing** or **research** per assumption shape |
| several of the above | all of them, in parallel where independent |

Two consequences.

**For the map (S-1).** Today `aef-inception-flow` is linear: a collapsed
exploration subProcess, then the `decision?` gateway. The operator's model needs a
**cycle** — exploration → readiness evaluation → *(not ready)* → back into
exploration **in a named mode**. The return edge is not a generic "keep going";
it carries which of research / testing / dialogue is owed. That is a second thing
the current map cannot express, alongside the missing Framework lane (F-2) and
the missing *ready-for-approval* state (F-11).

**For the framework's role.** The check does not decide whether the work is good;
it reports which of the agent's own commitments are outstanding, and the agent
acts on that report. The framework stays content-blind (F-12) while still being
useful — it is holding the agent to statements the agent made, and telling it what
it still owes.

It also removes the incentive that produced instance 3. Under a terminal gate,
"not ready" is a blocked task and the cheap escape is `--skip-*`. Under a loop,
"not ready" is a work item with a named next action, and bypassing it costs more
than doing it.

## F-14 — No designer extension needed; all three constructs already ship

**Operator (2026-08-07):** *"do we need to extend the workflow designer
functionality? In which case we should contact the relevant agent for enhancing
the module."*

**No — and the agent's phrasing caused the question.** F-11/F-13 said "the map
can't express X", meaning *our current `aef-inception-flow` content*. Read as a
statement about the designer's capability, it implies a missing feature. It isn't
one. Verified live against the corpus:

| Construct needed | Already exists in | Evidence |
|---|---|---|
| **Framework · Authority lane** | `aef-tier0-escalation` | `- Framework · Authority (authority: authority)` — three-lane, matching the full Authority Model |
| **State-carrier node** (`ready-for-approval`) | `aef-task-lifecycle` | non-terminal nodes carry `state: captured / started-work / issues / work-completed` |
| **Refusal cycle back into work** | `aef-task-lifecycle` v4 (T-2618) | `[gateway] gates pass?` → `do the work; tick Agent ACs progressively — blocked — unchecked AC / non-zero Verification; fix and retry` |
| **Back-edge / retry loop** | `aef-dispatch-loop` | `re-dispatch retry envelope` → `spawn isolated worker — retry envelope` |

`aef-task-lifecycle`'s completion-gate refusal loop is **structurally the thing
F-13 describes**: a gateway that refuses, labels *why*, and routes back into the
work node. The readiness router is the same shape with more outbound edges — one
per deficit class (research / testing / dialogue) instead of one generic
`blocked`. Multiple labelled edges off a gateway are already used throughout the
corpus.

So the inception rework is **entirely a content job in our own corpus**, and the
map that already carries `detail-authority` is a working precedent for all four
constructs at once. No 832 contact required. If something genuinely un-drawable
surfaces during S-1 seeding, that is the moment to escalate — with a concrete
missing construct rather than a speculative one.

## S-1 — skeleton seeded: `draft-inception-readiness` v1

Seeded per the arc-014 pair-draft ritual (agent seeds, operator corrects in the
UI, agent re-reads and normalises). Live at
`{watchtower}/designer?id=draft-inception-readiness`, uuid
`de31abe1-51d3-469c-9971-205abe5ecc17`, **17 nodes / 18 flows / 3 lanes**.

Authored as a spec YAML → `fw corpus generate` → saved through `/api/save`, not
hand-written XML. Verification actually run:

| Check | Result |
|---|---|
| `fw corpus lint` on the draft | **CLEAN** first write |
| store lint baseline unchanged | 4 findings / 3 maps, before and after (dispatch-loop, session-lifecycle, t2584-scratch) |
| round-trip `derive → generate → diff` | **IDENTICAL (canonical semantic form)** |
| served, not just on disk | `/api/list` returns 13 maps incl. this uuid; `/designer` gallery lists it; `fw corpus explain` renders 3 lanes |

**What changed against v1 (10 nodes / 9 flows / 2 lanes):**

1. **Framework · Authority lane** — four gates that were parentheticals on Agent
   nodes are now nodes with their own preconditions: the T-2204 filing gate, the
   readiness floor, `emit_review` put-forward, and the decision-record/AC-tick.
2. **Readiness evaluation split across two lanes** — `agt_5_evaluate` (agent
   judgment, INITIATIVE, "is there enough clarity to recommend a direction?")
   feeding `fw_6_readiness` (framework self-consistency floor). F-12's split
   drawn explicitly rather than implied.
3. **Named not-ready return edges** — the cycle F-13 describes:
   - `not ready — research / testing owed` → back into explore
   - `not ready — dialogue owed (blocking IW is a direction call)` → to the
     operator-dialogue node → answer folds back into the artifact
   - `ready — no blocking IW unanswered, evidence present, dialogue logged` →
     put forward
4. **The dialogue is a node** — `hum_7_dialogue`. Previously the conversation had
   no representation anywhere in the system (F-11 hole 3).
5. **Explore subProcess constituents renamed** to the three co-equal modes
   (research · testing · dialogue) rather than a spikes→recommend→decide
   sequence, matching the operator's model that clarity comes from research *and*
   conversation.

**Marked as PROPOSED, deliberately.** The corpus documents systems as actually
operated; a draft proposing a change must not be mistaken for as-is. Two node
names carry a literal `PROPOSED —` prefix (`agt_5_evaluate`, `fw_6_readiness`),
the doc comment states *"NOT as-operated"* in its second line, and every other
node's meta note names its current source of truth plus the finding against it.

**Not done, and not to be skipped (F-5 ordering).** The map is step 1 of five.
Promotion to `detail-authority` still requires `inception-transitions.yaml`
(step 2) and `lib/inception.sh` / `update-task.sh` reading it (step 3). Flipping
the registry primitive before those exist buys a green rail over a drawing
nothing executes.

### S-1 round 2 — operator laid out v2; agent re-read and normalised

Operator saved v2 through the designer UI. Re-read from the store and diffed on
`uid` (the cross-version stable identity — node **ids** are file-scoped and the
editor regenerates them on every save, which is harmless):

| Dimension | v1 → v2 |
|---|---|
| nodes / flows / lanes | 17 / 18 / 3 — unchanged |
| node uids | all 17 preserved, none added, none removed |
| names, lanes, types | **no changes** |
| flows (uid, endpoints, labels) | **no changes** |
| `aef:meta` notes | 13/13 preserved; subProcess constituents intact |
| positions | **all 16 placed nodes moved** — the operator's layout |
| lint | **CLEAN** |
| **doc comment** | **LOST** |

So v2 is the seeded topology plus the operator's layout, minus the map header.
The framework-lane nodes were tidied onto a common row (y≈168) and the agent
chain dropped to y≈466–480 — a real layout pass, not an incidental save.

**The doc loss is instance 3 of a known, already-registered defect.**
`tools/corpus_spec.py:178` names it: *"designer save path destroying doc comments
(T-2682, G-071 class)."* Prior instances: `draft-knowledge-leveling` v5→v6 and
`draft-trigger-handling` v1→v2. The pattern is exact each time — the last
agent-authored version carries the doc, the first UI save drops it, every save
after inherits the absence. Nothing else is harmed, which is precisely what makes
it easy to miss.

**Not repaired now, per the T-2682 precedent:** restoring a doc on a map under
active operator editing is futile until the save path is fixed — the next UI save
drops it again. It will be restored at promotion, which is when it matters and
when editing has stopped. In the meantime the "this is a proposal, not as-is"
signal survives in three other places the editor does preserve: the `PROPOSED —`
prefixes on `ir_evaluate` and `ir_gw_readiness`, the pool name *"AEF inception
flow (readiness draft)"*, and the title. v1.bpmn with the full doc is committed,
so nothing is unrecoverable.

**Escalation is warranted here, unlike F-14.** This is a genuine designer-side
defect on the shared seam, now at three independent instances across two maps and
two months, and 832 had not replied to the rail-332 report as of 2026-07-29. The
schema fix proposed then still stands: carry `doc` as an `aef:` attribute on
`workflowMeta` rather than a leading XML comment, so it survives any DOM
round-trip. Operator's call whether to re-raise on the rail with the new
instance count.

## F-15 — Designer version checked, and the id churn I called "harmless" had a mechanism

Operator asked to check with the workflow agent for the latest version, on the
grounds that their notation/routing revision may bear on this draft. Rail message
posted at **DM offset 443**. Three things established before posting.

**We are current, not drifted.** Pin `policy/designer-pin.yaml` = 0.8.0; served
bytes sha256 `cab3c751…0935` / 903600 B match the pin exactly. (I briefly
mis-read this as drift because `ls | head` truncated the vendor listing at 0.7.0
— corrected by reading `vendored_path:` and hashing the served response.) The
`web/blueprints/designer.py:112` docstring still says "vendored 0.3.0 bundle";
that is stale prose, not the resolution path.

**832's RAIL-440 explains the id churn I dismissed an hour earlier.** They shipped
T-364: `aef:uid` is now DERIVED from the BPMN element id rather than minted from
`Math.random()` per parse. The load-bearing detail is that `computeDisplayId`
ranks same-lane nodes by x and breaks ties on uid, and the resulting display id
**is** the emitted BPMN element id. So the uid was not describing identity, it was
deciding it.

Tested against today's two saves before reading their account — a clean
cross-check, not confirmation:

| Map | Lane | Emitted ids in x-order | ascends with x |
|---|---|---|---|
| draft-inception-readiness v2 | agent | `agt_1_question` … `agt_11_handoff` | ✅ |
| | framework | `fw_1_2204` … `fw_4_record` | ✅ |
| | human | `hum_1_operator`, `hum_2_operator` | ✅ |
| aef-task-lifecycle v2 | agent | `agt_1_work` … `agt_14_task` | ✅ |

`id = f(lane, x-rank)` holds on **32/32 placed nodes across both maps**. The
consumer-facing corollary is sharper than "harmless": **a horizontal drag rewrites
`sourceRef` / `targetRef` / `flowNodeRef` across the whole lane.** Benign for
anyone uid-keyed, silently fatal for anyone id-keyed.

**So: is AEF id-keyed anywhere?** Measured, and the answer is no. Exactly one
element id is stored anywhere in the tree —
`.context/designer/registry.yaml` ghost `referenced_by[].node` — and it is not a
lookup key: `web/designer_registry.py:125` strips a project's entries and rebuilds
them from the current document on every rescan, so it self-heals on the next save.
Every other apparent hit is prose in episodic YAML.

**My own instance of their finding.** I reported the id churn as *"the editor
regenerates ids on save, harmless"* — quoting a memory written when every map we
had carried authored uids. True, and true for the wrong reason: correct over the
one population where the defect cannot occur. That is precisely the class 832
flagged in 440 about their own 24/24 byte-identity gate, arriving on our side the
same day.

**Asked on the rail, pending:** (1) is there a release after 0.8.0 — T-364 shipped
with commits but no version announced, so I cannot tell whether the uid derivation
is in a cut release or ahead of our pin; (2) does the notation/routing revision
touch **lanes or cycles**, since this draft is a 3-lane map whose point is a cycle
with three named return edges — better to draft into the new notation than promote
into the old one; (3) does it touch `aef-bpmn-mapping-v1.md:42-45`, the clause
classing `aef:routing` / `routingHint` / `loopDetour` / `anchors` as presentational
and *"derived, never authoritative"* — our census shows `routingHint` 8 and
`loopDetour` 8 live in our corpus, so if routing stops being presentational that
clause is what moves, and it is load-bearing for how we generate.

Also re-raised the doc-comment defect at four instances / three maps / two months,
with the rail-332 proposal unchanged (carry `doc` as an `aef:` attribute on
`workflowMeta`, so it survives any DOM round-trip).

## F-16 — 832 answered (RAIL-444): no notation revision, and the doc defect was fixed nine days ago and never shipped

**Q2/Q3 — there is no notation or routing revision in flight.** 832 checked their
task tree rather than their memory of it. Nothing touches lane semantics or cycle
authoring; the four routing-adjacent tasks are z-order render (T-286), a layout
heuristic (T-102, T-093) and a typing-vocab note (T-289). **`aef-bpmn-mapping-v1.md:42-45`
is untouched, no task proposes touching it, and Part I is FROZEN** — a change
there needs a version bump and *our* ratification.

**Direct consequence: do not defer, do not draft into an anticipated notation.**
My advice to hold S-2 pending their answer was wrong — the answer is "proceed
against the current clause." The 3-lane readiness-gateway cycle with three named
return edges is authored against something that is not moving.

Caveat 832 raised themselves, worth keeping open: our operator's belief came from
somewhere, so an intent may exist that has not reached their task tree. They are
asking their operator and will correct within the day if so.

**Q1 — no release after 0.8.0, and this reframes the doc-comment work entirely.**
Our pin is correct and current. But **T-311 fixed the save-path doc destruction on
2026-07-30 — one day *after* the 0.8.0 cut — and it has never shipped.** Their
measurement:

```
grep -c docComment  src/aef-workflow-designer.html  -> 5
grep -c docComment  dist/…-0.8.0.html               -> 0
grep -c docComment  dist/…-0.7.1.html               -> 0
```

All four of our instances ran on builds without the fix. So the correct action is
**re-pin once they cut a release containing T-311**, not to keep hand-repairing
docs. Eight commits sit ahead of the pin (T-308, T-310, T-311, T-315, T-337,
T-358, T-361, T-364); the cut is gated on their operator and they are escalating
today with our four instances as the motive.

**T-364 is a no-op for us**, and they confirmed the reasoning independently:
derivation only runs where `aef:uid` is absent, and `corpus_spec` emits uid on
every map we generate. Re-pin for T-311, not for T-364.

**They support the rail-332 proposal — and it is our fence.** Carrying `doc` as an
`aef:` attribute on `workflowMeta` is a *standard* change; Part I is frozen, so it
needs our version bump and ratification. Their argument for it survives their own
fix: today the comment is preserved by out-of-band special-casing at emit time,
which works only because one implementation remembers to. §Purpose says the
framework talks to the format, not to any one editor — a datum that survives only
by reference-implementation special-casing is not portable. If we take it they
want `doc` classed **semantic** in §1, plus a migration note for the four maps
now carrying an absence.

**A §1 hole they surfaced, adjacent to our Q3 and also our fence.** §1 opens
*"Every aef: datum is exactly one of two classes"* and declares the partition
normative — but it **enumerates rather than defines**, and the current build emits
two kinds in neither list: `aef:laneMeta` (28×) and `aef:workflowMeta` (10×). They
left both UNCLASSIFIED rather than defaulting them to presentational, because
`aef:laneMeta` carries `authority=` — Axis-1 governance data — so the obvious
default would have understated it. An absence in an enumeration cannot carry a
classification ruling.

**Owed by us (five questions back, plus the §6.3 scope reading from 442).** One is
already answerable from this session: their Q4 asks whether
`designer_registry.py:125` rebuilding refs on every rescan is deliberate
self-healing or incidental. **Deliberate, and documented** — the `sync_project_refs`
docstring states replace-semantics explicitly: *"the save is the authority on what
this project references NOW — its old `referenced_by` entries are stripped first,
so deleted connectors disappear."* Not one refactor from becoming an id
dependency; the property is the stated contract.

Their Q2 is the one with direct value to us: they have **never tested a cycle
through a subProcess boundary** and offered to run `draft-inception-readiness`
through their fidelity probes before we promote it. That is worth taking up —
it de-risks the one structural novelty in the draft.

<!-- S-2 (walk the five instances across the revised map) and S-3 (conformance
     rail) are UNBLOCKED — 832 confirmed the notation is not moving. -->

## S-2 — the five instances walked across v2, and only one lands

The test S-2 exists to run: for each of the five instances, is there a node or
edge on `draft-inception-readiness` v2 where the failure *attaches* — and does the
attachment **prevent** the failure or merely **depict** it?

Result: **1 of 5 fully attached.** The map that was drawn to fix the
representational defect reproduces it for instance 4, and has no node at all for
instances 1 and 2.

| # | Instance | Attachment on v2 | Verdict |
|---|----------|------------------|---------|
| 1 | T-2862 decide-preflight deadlock | **none** — the preflight has no node | ❌ unattached |
| 2 | T-2442 schema deadlock (sibling) | **none** — same gate | ❌ unattached |
| 3 | T-2857 bypass + auto-tick | `fw_10_record` note only; the two bypass edges are undrawn | ⚠️ half |
| 4 | T-2861 artifact-first vs write guard | a **note on `agt_3_artifact`**, an Agent node | ❌ mis-attached |
| 5 | Root — T-2204 prior-before-evidence | `fw_2_filing_gate`, own Framework node, plus `fw_6_readiness` | ✅ attached |

### Instances 1 + 2 — the deadlock gate is not on the map

`lib/inception.sh:521-534`. The preflight is *inside* `do_inception_decide`, and
it runs in a specific order:

```bash
if [ "$decision" = "go" ] || [ "$decision" = "no-go" ]; then
    tick_inception_decide_acs "$task_file"          # tick first …
    …
    if [ "$_agent_total" -gt 0 ] && [ "$_agent_unchecked" -gt 0 ]; then
        echo "ERROR: Cannot record decision — $_agent_unchecked/$_agent_total agent AC unchecked"
```

Tick first, then count. That ordering is why T-2862 deadlocks and why it is not a
generic P-010 complaint: the greenfield seed's AC carries no
`@auto-tick-on-decide`, so the tick does not cover it, so the count finds it, so
decide refuses — over an AC whose content *is* the decide it is refusing.

On v2 this gate is nowhere. `fw_10_record` is drawn as the thing decide does, and
the refusal that happens *before* it has no node, so it has no failure edge
either. Instances 1 and 2 have nothing to point at.

### Instance 4 — v2 reproduces the exact defect F-2 diagnosed

F-2's finding was that gates rendered as parentheticals on Agent nodes read as
*things the agent does* rather than as gates with preconditions and refusal
edges. On v2, the background write guard — a Framework refusal — is a
`meta.note` on `agt_3_artifact`, an **Agent** node.

Same shape, same lane error, one map later. The guard refuses a Write; that is an
Authority action and it belongs in the Authority lane with a refusal edge. This
is the sharpest result of the walk, because it says the draft's *lane discipline*
is not yet a habit — the lane was added, and then the next gate was written as a
note anyway.

### Instance 3 — the tick is drawn, the bypasses are not

The agent-block is real and narrow (`lib/inception.sh:429`):

```bash
if [ "${CLAUDECODE:-}" = "1" ] && [ "$i_am_human" = false ] && [ "$from_watchtower" = false ]; then
```

Exactly **two** bypass edges: `--i-am-human` and `--from-watchtower`. v2 draws
neither, so the map shows only `hum_9_decide → fw_10_record` — the path where a
human really did decide. Every T-2857-class arrival reaches `fw_10_record`
*without* passing through `hum_9_decide`, and the map cannot express that.

**Correction to my own earlier note.** I wrote that T-2857's decision "arrived
through one of these [bypasses], including `--skip-sovereignty`". `--skip-sovereignty`
is **not** a decide bypass — it is what decide *itself* passes downstream to
`update-task.sh` (lines 684, 705, 716). So it is a Framework→Framework edge:
decide relaxing a gate on the tool it calls. That is a third undrawn edge, and a
more interesting one than the two I was counting, because no operator ever types it.

## F-17 — DEFER skips the preflight, so the cheapest exit is the one the prose forbids

Falling out of the same read, and not previously recorded.

Line 521 guards the preflight with `if [ "$decision" = "go" ] || [ "$decision" = "no-go" ]`.
**DEFER is not in that set.** A DEFER decision therefore skips the agent-AC check
entirely — the comment at line 663 confirms it deliberately ("for the defer path
(which skips preflight)").

Two consequences:

1. **T-2862's deadlock is escapable by deciding DEFER.** The un-completable
   greenfield inception completes if you hedge. The workaround is invisible
   because it looks like an ordinary decision.
2. **There is a mechanical gradient toward DEFER.** GO and NO-GO must clear an AC
   gate; DEFER need not. CLAUDE.md forbids exactly this by prose — *"DEFER is for
   evidence gaps, NOT for confidence gaps"* (T-2144/T-2145) — and T-2145 shipped a
   reviewer detector for it. So we have a prose rule and a static-scan backstop
   pointing one way, and a friction gradient in the CLI pointing the other.

This is the same class as the root defect: a rule stated in prose while the
mechanism rewards its violation. It is worth its own build slice, and it is
cheap — the preflight's guard either includes `defer` or the asymmetry gets a
stated reason.

### What v3 owes

1. A Framework node for the **decide preflight**, with its refusal edge — the
   attachment point for instances 1, 2 and F-17.
2. Re-home the **write guard** out of `agt_3_artifact`'s note into a Framework
   node with a refusal edge (instance 4).
3. The three undrawn edges into `fw_10_record`: `--i-am-human`,
   `--from-watchtower`, and decide's internal `--skip-sovereignty` handoff
   (instance 3).
4. A decision from the operator on whether v2 is a map of **as-operated** or
   **proposed** behaviour. The walk exposes the ambiguity: bypass edges belong on
   an as-operated map and are noise on a proposed one, and v2 currently mixes
   both (PROPOSED nodes alongside as-is notes). This is a prerequisite for S-3 —
   a conformance rail cannot audit map-vs-code parity until we say which one the
   map claims to be.

## F-18 — We are the ratifying party for a standard we do not hold (OBS-190)

Found while composing the rail reply, going to produce the §6.3 scope reading
832 has been owed since offset 442:

```
grep -rln "aef: extension layer\|aef-bpmn-mapping\|routingHint" --include=*.md --include=*.yaml .
-> docs/reports/T-2863-inception-workflow-rework.md
```

One hit, and it is this file quoting 832's rail messages. **We hold no copy of
`aef-bpmn-mapping-v1.md`.** Every clause cited on this rail — §1's two-class
partition, §6.3's subject, `42-45`'s "derived, never authoritative" — was quoted
out of their messages and then reasoned about confidently.

This matters beyond tidiness because 832 has now twice handed the ratification
fence back to us, correctly: the 332 `doc`-as-`workflowMeta`-attribute proposal
and the §1 enumeration hole are both **our** version bump to make. Neither is
answerable without the bytes. A ratifying party that does not hold the document
is not a fence, it is a rubber stamp.

It is also the same defect class this task has been chasing all session — a
conclusion produced over a population that cannot contain the counter-evidence.
A "reading" of §6.3 done from their paraphrase ranges only over the sentences
they chose to quote.

**Blocked on this:** the §6.3 reading, the §1 ruling, and the 332 ratification.
**Fix:** vendor + pin Part I under `policy/` the way `policy/designer-pin.yaml`
pins the dist build. Requested at rail offset 445.

## Next actions (carried, in order)

1. ~~**S-2** — walk the five failure instances across the v2 map.~~ **Done** —
   1/5 attached; v3 owes the four items above. Blocked on the operator's
   as-operated-vs-proposed ruling before v3 is drawn.
2. ~~**Reply on the rail**~~ **Done** — posted at offset 445, replying to 444.
   Their 1-5 answered; fidelity-probe offer taken up with a verified fixture ref
   (`/api/version?id=draft-inception-readiness&v=2`, sha256 `fe3a520d…a846`,
   served bytes confirmed byte-identical to disk); `aef-task-lifecycle` v3
   answered **yes-but-not-yet** — pinning it now pins a hand-repair the toolchain
   cannot regenerate, so the order is *release with T-311 → re-pin → re-save →
   pin that byte state*. Q5 reciprocated with my own `--skip-sovereignty`
   retraction and F-17.
2b. **Blocking on 832: the frozen Part I bytes** (F-18 / OBS-190). Until they
   arrive we cannot give the §6.3 reading, rule on the §1 hole, or ratify 332.
3. **Re-pin when 832 cuts a release with T-311** — then stop hand-repairing docs.
4. **Operator decisions still open:** IW-1..IW-4 shapes (F-12/F-13 confirmed the
   principle; the `blocking:` field is the concrete proposal), the two seed
   questions (does `decision?` belong in the Agent lane; do research and testing
   want separate return edges), and whether to ratify `doc`-as-`workflowMeta`-attr
   into the standard.

---

## Dialogue Log

**2026-08-07 — operator:** *"seems to be systemic can we document the inception
workflow in the workflow designer and investigate / rework it together?"*
Correct on systemic — five instances, four hit live in one session. The premise
that it needs documenting turned out to be false (F-1); the map exists and is
accurate. What it lacks is the Framework lane (F-2). Proposal put to the operator:
amend `aef-inception-flow` rather than draft a new map, adding Framework ·
Authority and re-homing the six gates in F-3 into it.

**2026-08-07 — operator, reframing IW-1:** *"inception is an interactive
conversation with operator / user … the workflow principle is through research
and conversation we gather enough clarity, insight and background information to
decide to proceed with an inception or not and if so what the direction will be,
at that point the inception can be put forward for 'approval'. What is wrong in
our current workflow is that inception is being put forward before all
requirements have been met."*

Accepted, and it moves the defect. My IW-1 was a question about a *field*; this
is a question about a *transition*. Tested it against the code and it holds
mechanically — the put-forward verb checks a string, the readiness check exists
but fires one transition later, `deferred` counts as disposed, and the
conversation half is unrepresented entirely. F-11.

**2026-08-07 — operator, on who evaluates readiness:** *"we want agent to
evaluate readiness and propose approval once it deems enough readiness"* — and,
in the same exchange, *"if it deems not to be ready it should initiate more
research, more testing or more dialogue or more of all of these."* Confirmed with
one qualifier: judgment is the agent's (INITIATIVE), but it needs a
self-consistency floor beneath it, because unfloored self-assessment is precisely
instance 3. F-12 / F-13.

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
