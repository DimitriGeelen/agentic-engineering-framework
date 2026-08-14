# T-2687 — should origin-free band-feasibility become a corpus lint rule?

**Task:** T-2687 (inception) · **Predecessors:** T-2684 (shipped `lane-geometry`), T-2686
(used feasibility as a repair oracle) · **Peer thread:** 832 rail 333–336, their T-310
· **Started:** 2026-07-29

## Problem Statement

`fw corpus lint`'s `lane-geometry` rule (T-2684) catches the class where a BPMN map's
declared lane membership and its drawn node geometry disagree — an authority defect, since
lane membership is the "who" axis in this dialect. The rule ships an *ordering* invariant:
for lanes in laneSet declaration order, member-node y-ranges must be strictly ordered and
non-overlapping.

During T-2686 a second check was written as a repair oracle: **does there exist a band
origin `O` that places every node inside its own declared band**, given the cumulative
`aef:laneMeta height` values the map already stores? This is interval algebra — it assumes
nothing about `O`'s value, so it is origin-free in the same sense as the ordering rule.

It produced the best evidence in that task. On both T-2686 maps the interval was **empty**
(`[160,-80]`, `[120,-160]`), which is a proof the declaration is unsatisfiable for *every*
origin — the evidence class the T-2684 band model could not produce, because that model had
to guess one specific origin (and guessed wrong, yielding 7 phantom mismatches on a clean
map).

The question: does it graduate into a corpus rule, and in what relationship to
`lane-geometry`?

**Why now:** 832 said at rail 335 they intend to mirror a geometry-vs-declaration check and
called it "a first-class check, not a rendering of the existing rule set". The shape settled
here is the shape handed to them.

## Method

IW-2 and IW-4 are empirical — survey all 11 store maps. IW-1 and IW-3 are design calls that
measurement informs but cannot settle. Findings appended as they landed (C-001).

## Findings

### F1 — my "strictly stronger" claim was wrong, and measurement is what caught it

I stated in T-2686's Decisions, and to 832 on rail 336, that feasibility is *strictly
stronger* than the shipped ordering rule ("ordered non-overlapping spans are necessary for
feasibility, not sufficient"). **The corpus survey falsifies this.**

`aef-session-lifecycle` v1 is ordering-**DIRTY** and closed-interval-feasibility-**CLEAN**,
with a degenerate interval `[-60,-60]` — exactly one admissible origin. Root cause, verified
rather than assumed: at `O=-60` the band boundary lands exactly on `y=100`, and all three
contested nodes (`hum_1_operator`, `hum_2_operator` declared human; `agt_9_session` declared
agent) sit at `y=100`. Closed-interval containment (`O+top ≤ y ≤ O+top+h`) lets a node on a
shared boundary belong to **both** adjacent bands, so the check waves through the exact
defect the ordering rule correctly flags.

So the two checks were **incomparable**, not ordered. The premise the whole task rested on
was false in the direction that matters — it claimed extra safety it did not have.

### F2 — half-open semantics fixes F1, and then adds nothing on the crossing class

With half-open bands (`[O+top, O+top+h)`, so a boundary node belongs to the lower band only
— matching what a reader sees), `aef-session-lifecycle` becomes correctly INFEASIBLE, and
the two rules then **agree on all 11 maps**: 9 clean/feasible, 2 dirty/infeasible. Zero new
failures, zero missed failures.

Consequence: on today's corpus, half-open feasibility contributes **no additional detection**
on the lane-crossing class, while offering strictly worse diagnostics — it returns an
interval, not the extremal witness *pair* of nodes that made `lane-geometry` actionable (the
witness is what resolved `draft-knowledge-leveling` v8 to exactly `kl_dormant`/`kl_healing`,
matching 832's independent account).

### F3 — but it catches a class the ordering rule is structurally blind to, and the corpus already has one

The ordering rule compares lanes *against each other*. It cannot see a lane whose **own
members span more than its declared height** — order is correct, nothing crosses, and yet
the band cannot contain its content, so the render overflows the band.

Proven on a synthetic map (framework lane spanning 190px inside `height=100`):

| check | verdict |
|-------|---------|
| `lane-geometry` (ordering) | **CLEAN — structurally blind** |
| feasibility | `[100, 0]` → **INFEASIBLE, caught** |

And it is not hypothetical. Per-lane headroom (`height − node span`) across the store:

| map | lane | span | height | headroom |
|-----|------|-----:|-------:|---------:|
| **draft-knowledge-leveling** | **agent** | **513** | **260** | **−253 OVERFLOW** |
| draft-knowledge-leveling | framework | 362 | 380 | 18 |
| aef-session-lifecycle | agent | 200 | 260 | 60 |
| aef-task-lifecycle | agent | 130 | 200 | 70 |
| aef-inception-flow | agent | 140 | 220 | 80 |

`draft-knowledge-leveling`'s agent lane overflows its declared height by **253px**. That map
is the v8 promotion candidate currently awaiting the operator's taste GO. The ordering rule
never mentioned this, because the ordering rule cannot see it — it reported only the
two-node authority question. These are **two independent defects on the same map with
different fixes**: the two-node call is a membership decision, the overflow is a lane-height
(or node-compression) fix.

### F4 — headroom is understated by exactly one renderer constant we do not have

Every number in F3 measures node **top-y** only. A node occupies its own rendered height
`H` below that point, so any lane with `headroom < H` is *already* overflowing in the render.
If `H ≈ 80` (the conventional BPMN task box), then `aef-session-lifecycle` agent (60),
`aef-task-lifecycle` agent (70) and `draft-knowledge-leveling` framework (18) are all
overflowing too — that would be 4 of 11 maps, not 1.

We deliberately do not read 832's tree, so `H` is theirs to state. This converts a
speculative worry into a single bounded question, asked at rail 337. **No rule ships on a
guessed `H`** — that is precisely the T-2684 band-model error (guess a renderer constant,
generate confident phantom findings).

## Open-question dispositions

- **IW-1 (top-y vs centre resolution)** → **dissolved, and reframed by F1.** The
  centre-vs-top choice is a *uniform* offset: it shifts the feasible interval without
  emptying a non-empty one, so it cannot flip a verdict. I had it as the primary design
  call; measurement showed the verdict-changing choice is **open vs half-open boundary
  semantics** (F1/F2), which I had not considered at filing. The real live constant is the
  node height `H` (F4), which affects the *capacity* class, not the ordering class.
- **IW-2 (how many clean maps fail the stricter check)** → **answered: zero.** Half-open
  feasibility and ordering agree on all 11 maps (F2). This is not a re-baselining exercise
  and carries no repair backlog — which also means it is not the tightening I expected.
- **IW-3 (replace or sit beside `lane-geometry`)** → **answered: sit beside, as a distinct
  rule.** Replacement is now clearly wrong: it would trade an actionable witness pair for a
  bare interval and gain nothing on that class (F2). The value is the *orthogonal* capacity
  class (F3), which deserves its own rule name, its own message, and its own fix advice.
  Proposed name `lane-overflow` (or `band-capacity`) — "declared height cannot contain this
  lane's own members", separate from `lane-geometry`'s "lanes cross".
- **IW-4 (can it distinguish a height defect from a placement defect)** → **answered:
  partly, and better than feared.** A per-lane span-vs-height comparison localises the
  defect to one lane and states the shortfall in pixels (`−253`), which points at the height
  directly. What it cannot do is decide whether the right fix is a taller lane or tighter
  node placement — that is an authoring judgment, so the message should report the shortfall
  and name both options rather than prescribe one.

## Recommendation

**Recommendation:** GO — but for a **different rule than the one this task proposed.**

**Rationale:** the premise (promote feasibility as a stronger `lane-geometry`) is dead: it
was weaker under closed semantics (F1) and redundant under half-open semantics (F2). What
the exploration surfaced instead is a genuinely orthogonal defect class the shipped rule is
structurally blind to — a lane whose declared height cannot contain its own members — with a
live instance overflowing by 253px on the very map awaiting a promotion decision (F3). Ship
that as its own rule, half-open, once 832 states the node height (F4). This is a GO on
evidence, not a hedge: the class is proven by construction, the instance is measured, and the
one missing input is a single constant with a named owner.

**Evidence:**
- F1 falsification traced to a specific mechanism at a specific coordinate (boundary at
  `y=100`, three nodes on it), verified by computing the bands rather than by inference
- F2 full-corpus agreement table, 11 maps, both boundary conventions
- F3 synthetic proof of blindness + the −253px live instance on the promotion candidate
- F4 the one unknown isolated to a single renderer constant with an owner, not guessed

**Immediate operator-facing consequence, independent of the rule:**
`draft-knowledge-leveling` v8's agent lane overflows its declared height by 253px. That is a
second, previously unnamed defect on a map in the taste queue, and it is a different fix from
the two-node authority call already routed there. Worth knowing *before* the promotion
decision, not after.

## Dialogue Log

**2026-07-29 — the survey overturned my own framing, twice.**

I filed this task expecting a straightforward tightening: a strictly stronger geometric check
that would probably find a few more disagreeing maps and need a re-baseline. Both halves of
that expectation were wrong.

First reversal: the very first corpus survey printed `aef-session-lifecycle` as
"ordering dirty but feasible(!)" — the opposite of what a strictly-stronger rule can produce.
I had already asserted "strictly stronger" in T-2686's Decisions *and* on the rail to 832.
Rather than treat it as a quirk I computed the bands at the degenerate origin and found the
shared-boundary mechanism (F1). The claim was simply false, and only measurement caught it —
the reasoning that produced it had felt airtight.

Second reversal: fixing the semantics made the rule *redundant* rather than stronger (F2).
At that point the honest answer looked like NO-GO. What rescued it was asking what the
ordering rule *structurally cannot* see, rather than what it currently misses — which
surfaced the capacity class, and the 253px overflow sitting on the promotion candidate (F3).

The pattern worth keeping: this is the second time in two tasks that a geometric check felt
right and was wrong (T-2684's band model, now this "strictly stronger" claim), and both were
caught by validating against the whole corpus before relying on the result. Also the second
time the fix was to ask "what constant am I assuming?" — there the band origin, here the node
height. A geometric rule over data that stores positions but not sizes has exactly one safe
posture: assume no renderer constant, or get it from the renderer's author.

**Correction owed and sent:** rail 337 retracts the "strictly stronger" claim I made at rail
336, with the counterexample, and asks 832 for the node height. Third correction in this
thread; each one came from measurement rather than from being told, which is the part I want
to keep.
