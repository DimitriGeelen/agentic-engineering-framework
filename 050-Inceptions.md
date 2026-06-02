# Inceptions — Agentic Engineering Framework

## Overview

An **inception** is the framework's discipline for *exploring a problem before
building*. The output of an inception is **decisional knowledge** — a GO,
NO-GO, or DEFER answer to a single question — not source code, not a feature,
not a deliverable. The artefact you ship is a recommendation backed by
evidence; the build that may follow is a separate task with its own scope.

**Core principle: An inception is one question, answered with evidence, by a
trace another agent can replay.** (See CLAUDE.md §"Task Sizing Rules" — "one
inception = one question".)

This doc owns inception **lifecycle**, the **disposition gate** that prevents
exploration theatre, the **scoring exception** that lets inceptions rank
against build work without mis-mapping, the **three-tier adjudication** that
routes decisions to the right authority, and the **park state** that DEFER
collapses into. The complementary documents are
[010-TaskSystem.md](010-TaskSystem.md) (the underlying task substrate) and
[040-ValueDrivers.md](040-ValueDrivers.md) (the scoring system inceptions
extend).

---

## Lifecycle

An inception is a `workflow_type: inception` task with the same lifecycle
shape as any other task — `captured → started-work → work-completed` — plus
two structural rails specific to exploration:

| State | Meaning | Transition rule |
|-------|---------|-----------------|
| `captured` | Inception filed, question scoped, no exploration yet | Promote via `fw work-on T-XXX` (status → `started-work`, horizon → `now`) |
| `started-work` | Exploration in progress — research artifact open, dialogue happening | Two-commit exploration budget (see "Commit budget" below); ends with a decision |
| `work-completed` | Decision recorded (GO / NO-GO / DEFER), constituent build tasks filed if GO | Set via `fw inception decide T-XXX go|no-go|defer --rationale "..."` then `fw task update --status work-completed` |

### Research artifact (C-001)

The first commit in an inception **must** create the research artifact:

```
docs/reports/T-XXX-<slug>.md
```

The thinking trail IS the artifact — conversations are ephemeral, files
permanent. Update the file incrementally as dialogue produces findings; do
**not** wait until the end. Commit after each meaningful segment (Step 0
discovery, candidate matrix, dialogue round, decision). The framework's
inception-decide preflight grep's this file for evidence sections; an empty
or skeletal artifact will not pass the disposition gate (see below).

The artifact has a required **`## Dialogue Log`** section for human-dialogue
phases. Findings capture *what* was decided; the dialogue log captures *why*
and *how* the reasoning evolved. Reviewer-agent's `defer-as-hedge` detector
(T-2145) reads both.

### Commit budget

The default exploration budget is **two commits** (configurable via
`FW_INCEPTION_COMMIT_LIMIT`, default `2`). After two T-XXX commits, the
commit-msg hook blocks further commits until `fw inception decide T-XXX go|no-go|defer`
is recorded. This bounds the "still thinking, just one more spike" failure
mode.

**Storage exemption (T-2195).** The current implementation counts *every*
T-XXX commit including the initial filing + research-artifact storage
commits, which can consume the budget before substantive exploration starts.
T-2195 reshapes the counter to count only commits that *advance* exploration
(skip filing-only, storage-only, and demotion-only). Until T-2195 ships,
raise the limit explicitly when storage is heavy:

```
FW_INCEPTION_COMMIT_LIMIT=6 fw inception decide T-XXX go --rationale "..."
```

The override is logged Tier-2.

### Producer ≠ judge

Under `$CLAUDECODE=1` (an agent session), `fw inception decide` is **refused**.
The agent produces the recommendation; the human decides. Override flags
exist for script/test contexts (`--i-am-human`) and the Watchtower backend
(`--from-watchtower`). The structural lockout is at `lib/inception.sh`.

See CLAUDE.md §"Presenting Work for Human Review" for the recommendation
shape. The agent's job ends at:

```
fw task review T-XXX     # emit class-correct Watchtower URL
```

---

## Disposition Gate

An inception body has an **`## Open Questions`** section listing each
exploration question (typically `IW-1 … IW-N`). The disposition gate
(implemented in `agents/task-create/update-task.sh` per T-2190) refuses
`--status work-completed` unless every Open Question has a **disposition** of
one of three forms:

| Disposition | Meaning | What evidence looks like |
|-------------|---------|--------------------------|
| **answered** | Question resolved with verifiable rationale | File / code path / decision cited inline; reviewer can replay the check |
| **dissolved** | Question turned out to be ill-formed (premise false, conflation, etc.) | Step-0 discovery that refuted the question's framing |
| **deferred** | Genuinely needs more information; cannot be answered now | Specific evidence needed + revisit trigger filed (see Park State below) |

**Never binary.** An IW question must not collapse to a yes/no — that's the
shape that hides confidence gaps. Either explain what was found ("answered"),
explain why the question is malformed ("dissolved"), or explain what
information would make it answerable ("deferred"). The gate refuses bare
checkboxes.

### Evidence-or-justified-absence discipline (§ACD)

A disposition without evidence is theatre. The reviewer-agent's `defer-as-hedge`
detector (T-2145, extended in T-2191) catches the failure mode where a
disposition reads as "answered" but the artifact has no Step-0 / candidate
matrix / dialogue trace to back it up. The signal vocabulary it flags:
*"seems to be"*, *"likely"*, *"probably"*, *"appears that"* without an
accompanying cited evidence line.

Cross-ref CLAUDE.md §"DEFER is for evidence gaps, NOT confidence gaps"
(T-2144 origin) — the same discipline applies to dispositions, not just to
final Recommendation.

---

## Scoring Exception

Inceptions break the BVP cost model in a specific way: the F8 composite cost
formula in [040-ValueDrivers.md](040-ValueDrivers.md) is:

```
cost = 0.6 × blast_radius + 0.3 × tier + 0.1 × effort
```

An inception's `components:` is empty by definition (the build doesn't exist
yet), so `blast_radius` evaluates to `0`. This drags inception cost low and
makes inceptions *look* cheaper than the build slices they unblock — even
when the inception will authorise a 5-component refactor. The 040 formula was
designed for build-shaped work; inceptions need a proxy.

### `target_blast_radius` (T-2188)

Inceptions carry a frontmatter field declaring the **anticipated** blast
radius of the build work the inception would authorise on GO:

```yaml
workflow_type: inception
target_blast_radius: 5    # expected component count if GO
voi_score: 0.7            # value-of-information, 0..1 (see below)
```

The estimator (T-2189) detects `workflow_type: inception` and substitutes
`target_blast_radius` into the F8 cost formula, recovering rank parity with
build tasks. A PreToolUse hook (T-2188) validates the field is present and
within range; absent on legacy inceptions is grandfathered (T-2193 backfills
historic ones).

### Value of Information (VoI)

`voi_score` is the **expected value of resolving the question** independent
of the build cost. An inception that resolves a question affecting 5
constituent tasks has higher VoI than one resolving a single-task question.
VoI feeds into BVP scoring as a free driver on inception tasks only;
build-task BVP is unchanged.

The two fields together let `fw bvp rank` surface inceptions against builds
on the same axis: *"this question is worth resolving because answering it
unblocks N tasks of expected blast-radius B"*.

---

## Three-Tier Adjudication

Not every inception decision needs the same level of authority. The framework
routes by stakes:

| Tier | Stakes | Decider | Mechanism |
|------|--------|---------|-----------|
| **Low** | Reversible, local, single-task scope | Reviewer-agent self-eval | `bin/fw reviewer T-XXX` PASS verdict is sufficient; agent records decision |
| **Medium** | Cross-task, touches policy doc, or affects scoring rubric | Reviewer + human nod | Reviewer-agent verdict + `fw task review T-XXX` → human acknowledges via Watchtower |
| **High** | Strategic, irreversible, cross-arc, or sovereignty-adjacent | Human only | `fw task review T-XXX` → human GOes/NO-GOes via Watchtower `/inception/<id>` |

**Stake markers (write these in the inception body):**

- **Low:** "Reversible by single commit revert", "scoped to one component",
  "no downstream readers"
- **Medium:** "Affects N tasks", "edits .context/<policy>.yaml", "shipped
  weights change"
- **High:** "Affects framework directive", "renames frontmatter field",
  "edits enforcement hook", "irreversible external publish"

The reviewer-agent's static scan (T-2191) classifies stake from the inception
body's scope-fence + components touched and refuses agent self-eval when
markers indicate medium/high.

### Producer ≠ judge, again

Three-tier doesn't bypass producer ≠ judge. The agent never decides its own
inception — even low-stake. The reviewer-agent is independent of the
producer (separate static scan, different evidence inputs); the human is
independent of both. The triad is *who can sign*, not *who can self-grade*.

---

## Park State

An inception that cannot be answered now is **deferred** — not abandoned, not
silently dropped. DEFER decomposes into three frontmatter fields:

```yaml
status: work-completed     # the decision IS the closure
horizon: later             # excludes from priority scheduling
revisit_at: 2026-09-01     # daily revisit-scan trigger (G-053)
revisit_evidence_needed: > # what would make this answerable
  Once T-2191 ships and the reviewer-agent emits disposition findings,
  re-evaluate whether IW-3 can be answered from production data.
```

**`revisit_at` + `revisit_evidence_needed`** (T-1451) together park an
inception with a specific resurfacing trigger. The G-053 daily scan
surfaces `revisit_at` dates that have arrived without `--horizon now`
re-promotion; the human reads `revisit_evidence_needed` and decides whether
the trigger condition has been met.

### DEFER is for evidence gaps, NOT confidence gaps

This is worth stating explicitly because the failure mode is reliable:
agents reach for DEFER when they don't *want* to commit to a recommendation,
not when they *can't*. If the artifact contains a complete Step-0, candidate
matrix, and dialogue log, you have the evidence to recommend GO or NO-GO —
DEFER is wrong.

Use DEFER **only** when:

- A spike is needed that the inception couldn't run (env access, external
  dep, sovereignty-blocked tool)
- A dependency is unresolved (another task / external party must move first)
- An external party must respond (vendor, regulator, upstream maintainer)

If a peer reviewer walked your artifact and asked *"is the evidence
incomplete?"* and you'd answer *"no, just the implications are
uncomfortable"* — that's a confidence gap. Recommend GO or NO-GO with the
rationale you have.

Cross-ref CLAUDE.md §"DEFER is for evidence gaps, NOT confidence gaps"
(T-2144 origin, T-2145 reviewer detector).

---

## Worked example

A canonical end-to-end inception, with the same shape every inception
should follow:

1. **File.** `fw task create --type inception --name "Recalibrate inception
   workflow"` — creates `T-XXX` in `captured`. Body has Problem Statement,
   Open Questions (`IW-1..IW-7`), Scope Fence, Assumptions.
2. **Promote.** `fw work-on T-XXX` — status → `started-work`, focus set.
3. **Step 0.** Discovery against actual framework code. Refute or confirm
   the inception's working conclusions before treating them as fact. Commit
   findings.
4. **Dispositions.** Walk each Open Question. Each gets answered / dissolved
   / deferred with cited evidence. Commit.
5. **Recommendation.** Write `## Recommendation` in the task body — GO,
   NO-GO, or DEFER, with rationale and concrete evidence list. Commit.
6. **Hand off.** `fw task review T-XXX` — emits the class-correct Watchtower
   URL (`/inception/<id>`). Stop. Do **not** run `fw inception decide`.
7. **Human decides** via Watchtower. The `/inception/<id>` POST is
   filesystem-equivalent to a direct CLI invocation with `--from-watchtower`.
8. **File constituent slices** (if GO). Each is a separate build task with
   `related_tasks: [T-XXX]` and its own ACs. The inception itself doesn't
   "do the work"; it authorises it.
9. **Close.** `fw task update T-XXX --status work-completed`. Episodic
   auto-generated. Inception moves to `completed/`.

T-2186 itself was filed under this exact lifecycle and ships as the worked
example anchored at `docs/reports/T-2186-recalibrate-inception-workflow-seed.md`.

---

## Anti-patterns

- **Treating a pickup message's detailed spec as authorisation to skip
  inception.** A pickup message is a *proposal*. The more detailed it is,
  the more likely it needs inception, not less. CLAUDE.md §"Pickup Message
  Handling" (G-020 origin).
- **Building under the inception task ID after GO.** The build is a separate
  task. The inception authorises; it doesn't execute. After GO, file the
  constituent build slices and close the inception.
- **DEFER as a hedge.** Covered above.
- **Skipping the research artifact ("I'll write it after").** Conversations
  are ephemeral. Without the on-disk trail you have a folklore decision the
  next agent can't audit. C-001 requires the artifact *first*, updated
  incrementally.
- **Umbrella inceptions ("explore A, B, and C together").** One inception =
  one question. Compound inceptions produce all-or-nothing decisions and
  coarse traceability. Split.

---

## Cross-references

- [010-TaskSystem.md](010-TaskSystem.md) — task lifecycle, frontmatter,
  workflow types, AC discipline
- [040-ValueDrivers.md](040-ValueDrivers.md) — BVP scoring, drivers,
  estimator semantics, F8 cost composite
- [012-ArcSystem.md](012-ArcSystem.md) — arcs as collections of related
  tasks (inceptions can authorise arc-spanning work)
- `docs/reports/T-2186-recalibrate-inception-workflow-seed.md` — the
  inception that produced this doc; canonical worked example
- CLAUDE.md §"Inception Discipline" — the agent-facing behavioural rules
  (operational complement to this doc)
- CLAUDE.md §"Presenting Work for Human Review" — recommendation shape and
  handoff command
- CLAUDE.md §"DEFER is for evidence gaps, NOT confidence gaps" — T-2144
  origin
- T-2186 (`docs/reports/T-2186-recalibrate-inception-workflow-seed.md`) —
  the recalibration inception that produced this doc

---

## Implementation status (2026-06-03)

This doc is the keystone of T-2186 Slice 1 (T-2187). The constituent slices
that wire the discipline into structural enforcement:

| Slice | Task | What it ships |
|-------|------|---------------|
| 2 | T-2188 | Frontmatter schema: `target_blast_radius` + `voi_score` + PreToolUse validation |
| 3 | T-2189 | Estimator `workflow_type=inception` branch — substitute `target_blast_radius` into F8 |
| 4 | T-2190 | `## Open Questions` body section + disposition gate in `update-task.sh` |
| 5 | T-2191 | Reviewer-agent disposition completeness + extend `defer-as-hedge` |
| 6 | T-2192 | Watchtower `/bvp` scatter inception axis (rank inceptions vs builds) |
| 7 | T-2193 | Migration: backfill `target_blast_radius` on existing inceptions |
| 8 | T-2194 | Filing-time placeholder check (Open Questions non-empty) |
| 9 | T-2195 | Commit-counting semantics — exempt storage from exploration budget |

Until those slices ship, the discipline is documented but not yet
structurally enforced beyond the existing $CLAUDECODE=1 lockout and 2-commit
budget. The doc IS the spec the slices implement against.
