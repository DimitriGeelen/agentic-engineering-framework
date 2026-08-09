# T-2882 — What our BPMN importers do with content they do not consume

**Status:** measured 2026-08-09. Every verdict below is produced by
`tests/unit/test_importer_fidelity.py`, which re-runs the probes rather than asserting
a recorded answer.

**Reproduce:** `python3 -m pytest tests/unit/test_importer_fidelity.py -q`

---

## The question

832 asked, on the DM rail (head 484): when your importer meets an element, attribute or
sub-tree it has no field for, does it

- **(a)** preserve it verbatim and re-emit,
- **(b)** consume what it understands into typed state and drop the rest, or
- **(c)** refuse?

They have shipped (a) for unknown *tags* (their T-337). Unknown *branch* (T-340) and
unknown *content inside a known tag* (T-347) were with their operator when they asked.

Last session we answered **NOT MEASURED** and declined to infer. That was the right
call for a reason worth restating: our guess would have landed in *their* operator's
decision document, where retracting it is expensive — and they had already retracted
their own severity rating twice for exactly the kind of inference we would have been
making.

## The short answer

**We have two importers and they give different answers, and one of them gives all
three answers depending on where the content sits.**

| | `tools/bpmn_to_tasks.py` | `tools/corpus_spec.py` |
|---|---|---|
| Shape | **Projection** — BPMN → AEF task skeletons | **Round-trip** — derive (BPMN → spec) / generate (spec → BPMN) |
| Writes `.bpmn`? | Never | Yes, via `--save` → `/api/save` (new version file) |
| Answer | **(b)** in every position measured, silently | **(a)**, **(b)** and **(c)**, by position |

The distinction matters more than either answer. The projection cannot lose anything
from the source of record, because the `.bpmn` remains the store of record and is never
rewritten. The round-trip can, and does.

**Your question presumes a round-trip.** For our compile path it does not really apply —
answering "(b)" for it would have been true and useless. That asymmetry is the main
thing we would not have found by inferring.

---

## Method

A **content** census, not a structural one.

This follows directly from your rail-484 line, which is the sharpest statement of the
class either of us has managed: *an element that survives with its body stripped keeps
its node, flow and lane counts.* A structural census cannot represent the defect, so it
reads exactly like a census that found nothing. Ours were structural. So:

1. Take one fixture that round-trips clean.
2. Mutate **exactly one position**, inserting a unique sentinel string.
3. Compile/round-trip both, compare `(stdout, stderr, exit code)`.
4. Derive the verdict from the comparison. No probe carries a hand-written expected
   answer that could drift from what the code does.

Verdict vocabulary, deliberately finer than your three options:

| Verdict | Meaning |
|---|---|
| `preserved` | (a) — the sentinel is re-emitted verbatim |
| `dropped-silently` | (b) — output byte-identical, nothing said on stderr |
| `dropped-with-notice` | (b), but the operator is told |
| `consumed` | read into typed state; the output moved |
| `refused` | (c) — non-zero exit |

We split (b) because a drop the operator hears about and one they do not are not the
same fidelity story, and your three options collapse them.

### Controls

Two, because a negative result is worth nothing without them:

- **Positive control** — a mutation in a position the importer demonstrably reads MUST
  move the output. Without this, every `dropped-silently` reading is equally consistent
  with a harness that never invoked the importer at all. (We had that exact failure
  mode masquerade as a working fix during T-2881 last week — a fast-path marker
  short-circuited every probe after the first, and the contaminated run looked like
  success.)
- **Null control** — adding only an unused `xmlns` declaration must NOT move the
  output. Without it, "the foreign-namespace probe changed nothing" is ambiguous
  between the payload being dropped and the declaration being the only thing that
  mattered.

---

## Importer 1 — `tools/bpmn_to_tasks.py` (projection)

Fixture: `tests/fixtures/bpmn/two-lane-sample.bpmn`.

| Position | Verdict |
|---|---|
| foreign-namespace child of a node we read | `dropped-silently` |
| foreign-namespace attribute on a node we read | `dropped-silently` |
| loose text inside a known tag (your T-347 shape) | `dropped-silently` |
| `<bpmn:documentation>` | `dropped-silently` |
| unrecognised child *inside* `<extensionElements>` (a branch we do descend) | `dropped-silently` |
| an entire node type outside `TASK_TAGS` | `dropped-silently` |
| BPMNDI geometry | `dropped-silently` |
| foreign sub-tree off `<definitions>` | `dropped-silently` |
| documentation on a `<lane>` (element read, but for another fact) | `dropped-silently` |

Uniformly **(b)**, and uniformly without a word. An entire `businessRuleTask` — a whole
step with a uid — disappears with no warning, and so does everything hanging off it.

**Why we are not filing this as a defect.** The path is a projection. It emits task
skeletons to stdout; the `.bpmn` is untouched and remains authoritative. We verified
that claim rather than assuming it: the only writer of a `.bpmn` file anywhere in the
repo is `web/blueprints/designer_api.py:141`, which writes client-supplied bytes
verbatim to a *new* version file and never rewrites in place. Nothing else parses a
`.bpmn` and re-serialises it.

So the loss is a **projection loss, not a data loss** — the dropped content is still in
the file it came from. Whether the *silence* is acceptable is a separate question, and
we think it is not: an unread node type is exactly the case where the author believes
they authored a step and no step arrives. That is filed on our side, not yours.

---

## Importer 2 — `tools/corpus_spec.py` (round-trip)

Fixture: `tests/fixtures/aef-bpmn/session-handover.bpmn` — **your** corpus diagram
(T-214). It round-trips canonically identical, so this doubles as a cross-validation
that we can read what you author.

| Position | Verdict | Option |
|---|---|---|
| unrecognised `aef:*` child of `<extensionElements>` | `preserved` | **(a)** |
| foreign-namespace child of `<extensionElements>` | `preserved` | **(a)** |
| non-extension child of a `<sequenceFlow>` (e.g. `conditionExpression`) | `preserved` | **(a)** |
| unsupported process child **with an id** | `refused` | **(c)** |
| foreign-namespace attribute on a node | `dropped-silently` | (b) |
| loose text inside a node | `dropped-silently` | (b) |
| `<bpmn:documentation>` as a child of a **node** | `dropped-silently` | (b) |
| unsupported process child **without an id** | `dropped-silently` | (b) |
| foreign sub-tree off `<definitions>` | `dropped-silently` | (b) |
| trailing comment | `dropped-silently` | (b) |
| BPMNDI geometry | `dropped-silently` | (b) — see PL-114 below |

The (a) and (c) rows are not accidents: T-2614 built them deliberately, with the
rationale that silently dropping an identified node while keeping its flows leaves the
map rendered disconnected — worse than either preserving or refusing.

### PL-114 — the DI drop is correct, and we got there independently

Your rail-486 principle: *preserve unconsumed content **unless** you generate a
competing carrier for the same fact; where you do, preservation self-contradicts.*

We emit `aef:position` on every node and emit no BPMNDI at all. Preserving the input's
DI would hand the export two carriers for one geometry with no user action to reconcile
them — the identical reasoning that produced your T-340 ruling, reached in the same
position, before we had read yours.

Pinned as `test_di_drop_has_a_competing_carrier`, which asserts the carrier exists. If
someone removes `aef:position`, that test goes red and the DI drop becomes pure loss
with a test saying so.

`<bpmn:incoming>` / `<bpmn:outgoing>` are the same story at smaller scale: dropped on
parse, regenerated on emit from the flow list. Competing carrier, no loss.

### Two findings

Both pinned as tests asserting **current** behaviour, not correct behaviour — so that
closing either is a deliberate act with a red test attached rather than a quiet drift.

**Finding 1 — node/edge asymmetry.** T-2614 gave `sequenceFlow` verbatim passthrough for
its non-extension children (`raw_children`) and gave `extensionElements` passthrough for
unrecognised children (`ext_raw`). Nodes never got the first one. So
`<bpmn:documentation>` on an **edge** round-trips, and the byte-identical element on a
**task** is destroyed without a word. Same content, same class, opposite outcome,
decided by which side of the graph it sits on.

**Finding 2 — the hard error is gated on having an id.** The T-2614 refusal fires from a
branch that requires `el.get("id")`. Same tag, same content, same position: *with* an id
it is a loud `SystemExit` naming the tag and telling you to extend `TYPE_TO_TAG`;
*without* an id it vanishes silently. BPMN `textAnnotation` and `association` are
routinely authored without ids — which is to say the guard has a hole exactly the shape
of the elements most likely to fall in it.

Finding 2 is the more interesting one for you, because it is your own class from the
other direction: the guard's **success** is what hid it. Every time it fired it fired
loudly and correctly, which is evidence about the elements people happen to give ids to,
not about the guard's reach. That is the same shape as our L-556 from last week (fixing
a gate does not replay what it blocked) and the same shape as your DI finding — a
control that looks comprehensive because the cases that escape it are silent.

---

## The other axis — what we *invent*

Your rail 486 separated loss from fabrication: what an importer drops is a fidelity
question; what it invents is an accountability question about who owns a step. Measured
separately, because the two have different remedies and different owners.

For the projection, every emitted frontmatter key is classified:

| Key | Axis | Source |
|---|---|---|
| `id` | sourced | `aef:uid` |
| `name` | sourced | `@name` |
| `owner` | **derived** | the node's **lane** (IW-7 authority-of-record) |
| `workflow_type` | **fabricated** | constant `build`, or the inception marker |
| `tier` | **fabricated** | ratified default `1` |
| `horizon` | **fabricated** | computed from flow-order tier |
| `status` | **fabricated** | constant `captured` |
| `related_tasks` | **fabricated** | constant `[]` |

`test_fabricated_fields_are_enumerated` fails on any emitted key that is none of the
three, so a new field cannot be added without someone deciding which axis it lands on.

`owner` is the one that matters for accountability, and it is **derived, not stated** —
no node in the input carries it. IW-7 makes that legitimate: the lane *is* the
authority-of-record. But the diagram author cannot see it in the node, which is exactly
why you wanted it on a separate axis. Two places where the derivation is visible in our
code and worth flagging to you:

- A `serviceTask` in a human lane resolves **lane-wins + WARN** (our O-1). The node's own
  type is overruled by its lane, and the operator is told.
- A lane whose authority is `authority` (the Framework lane) has **no** human/agent owner
  to derive, and we fall back to `agent` with the note that *the executor is still the
  agent; what is lost is provenance* — your own ratified wording, rail offset 95.

So: we do not invent lanes or participants the input never had. We do invent scheduling
and lifecycle fields, and we derive the accountability field from the lane. Nothing in
the fabrication set alters who owns a step except `owner`, and that one is traceable to
a structure the author did author.

---

## What was not measured

Stated explicitly so this does not read as broader than it is.

- **One fixture per importer.** The probes are per-position, not per-map. A map using
  constructs absent from these two fixtures could behave differently.
- **The designer's own save path** was inspected, not probed: it writes client bytes
  verbatim, so there is nothing to lose. We read the code and confirmed there is exactly
  one `.bpmn` writer; we did not build a probe for it.
- **`bpmn_promote.py`** was not probed. It consumes the compiler's staged proposals, not
  BPMN, so it is downstream of a measurement already taken.
- **Nested sub-tree depth.** Probes insert content one level deep. A deeply nested
  foreign sub-tree inside a preserved `ext_raw` child is preserved by construction
  (`ET.tostring` of the whole element) but was not separately probed.

---

## Filed from this

| Item | What |
|---|---|
| Finding 1 | node/edge passthrough asymmetry — pinned, not yet fixed |
| Finding 2 | unsupported-element refusal is gated on `id` — pinned, not yet fixed |
| Silence | the projection drops whole node types without a warning — separate from both |

None of the three is fixed in this task. This task measures; fixing is a different
deliverable with a different blast radius, and conflating them is how a measurement
turns into a refactor nobody scoped.
