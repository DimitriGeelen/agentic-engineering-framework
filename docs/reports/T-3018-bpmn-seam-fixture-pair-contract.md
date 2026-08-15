# T-3018 — BPMN seam fixture-pair contract with 832-Workflow-designer

**Type:** inception
**Status:** awaiting operator decision
**Recommendation:** GO, scoped to a 3-fixture adversarial pilot

## Problem statement

The BPMN seam between this framework and 832-Workflow-designer has no test on
either side that can detect a defect in the other side's half. Both projects
recently discovered, independently, that their tests were *lenient readers* of
their own code — a test cannot catch a defect it inherits from the thing it is
testing.

Concretely at this seam: 832 authors BPMN documents carrying uids that are meant
to resolve to AEF record identities. 832 can verify their document is
well-formed. They cannot verify it is *correct*, because "correct" here means
"the records AEF would have produced had the workflow been authored natively",
which is a fact about our data model, not about their document.

The reverse holds for us. We can verify our renderer produces something. We
cannot verify it produces what their document meant.

## Why this is not hypothetical

832 shipped a silent escaping defect at this seam. Their probe read the XML back
with the browser's `DOMParser` — a parser lenient enough to agree with their own
writer's bug. The test was green and the output was wrong, and the two facts
were indistinguishable from outside.

We hit the same class twice in the same week:

| Instance | The lenient reader |
|----------|--------------------|
| Removal-detection test | The universe of indexed files came from the module's own `file_state` bookkeeping table, so nothing had ever been purged and no test could observe a purge |
| Routing mutation test | Asserted on the bootstrap branch while the mutation lived in the incremental branch — one test, two code paths, never met |

One confirmed silent defect at an untested seam is the failure-rate evidence.
We are not speculating about whether this seam breaks; we are recording that it
already did, and that neither side's instruments could see it.

## The proposal (832's, chat-arc offset 11909)

A **fixture pair contract**:

- 832 publishes N BPMN documents plus a machine-readable statement of what each
  asserts (element → uid → intended record identity).
- We publish the expected rendering for each.

Each side then runs its own half against a fixed reference without executing the
other's code. The seam gets a regression test that survives either side
refactoring.

This respects the T-559 boundary — neither project executes the other's tooling
— which is an operator rule and is not up for negotiation here.

## Why the shape is right

Each side's oracle comes from the *other* side. This is the first arrangement
either project has proposed in which the checker is not downstream of the thing
being checked. It is the structural answer to the lenient-reader class, not a
larger quantity of the same kind of test.

## Two amendments (ours, chat-arc offset 11912)

### A1 — expected-rendering artifacts must be generated, never hand-written

A hand-authored "expected rendering for document N" is correct the day it is
written and silently wrong forever after. Our renderer changes, the fixture does
not, and the pair still passes because 832's half is checked against our stale
*claim* rather than our actual behaviour.

That is not a smaller version of the bug the contract exists to prevent. It is
the same bug relocated into the contract.

Fix: expected-rendering files are emitted by our code and committed. A behaviour
change then surfaces as a diff in review, where a human sees it — the same
pattern as the framework's cron registry→generated drift gate, where the
generated file is a tripwire rather than documentation.

We asked 832 for the symmetric guarantee on their assertion statements.

### A2 — start at N=3, chosen adversarially

Not N-comprehensive. Three documents covering the cases where the two models
actually disagree:

1. An element carrying a uid we have no record for
2. An element carrying two uids
3. A uid on an element type that cannot hold one in our model

The boring cases pass on day one and teach nothing. The contract earns its keep
on the shapes where "correct" is genuinely contested. If all three round-trip
cleanly that is a real result and we widen; if one does not, we found a seam
defect before either side shipped against it.

### Format constraint

Plain JSON, one file per fixture, parseable without either side's tooling. If
reading a fixture requires 832's renderer, the contract has rebuilt exactly the
coupling it exists to avoid.

## Candidates considered

| # | Candidate | Verdict |
|---|-----------|---------|
| A | Fixture-pair contract, 3-fixture adversarial pilot, generated artifacts | **Recommended** |
| B | Fixture-pair contract, N-comprehensive from the start | Rejected — cost scales with fixtures, value concentrates in the contested three |
| C | Hand-authored expected renderings | Rejected — reintroduces the silent-staleness failure the contract prevents (A1) |
| D | Spec constraint on assigners instead of a test contract | Rejected earlier in the exchange; a spec cannot detect its own violation, which is the whole problem |
| E | Do nothing | Rejected — the seam has one confirmed silent defect and zero coverage from either end |

## Cost

Bounded and mostly ours. Three fixtures, a generator for the expected-rendering
artifacts, and a CI rail that diffs generated-vs-committed. The asymmetry is
real and was acknowledged to 832: this is more work for us than for them, which
is why they proposed rather than assumed.

## Dialogue log

**Round 1 (us → 832).** Recommended the `&#10;` escaping fix over a spec
constraint on assigners. Offered three parallel instances of the lenient-reader
class from our own week's work.

**Round 2 (832 → us).** Answered our scoping question — the blocker on their
reverse renderer is (3) *no oracle*, not corpus and not headless invocation.
Corpus is fine (24 rendered maps, any shape synthesisable). Headless invocation
is fine in principle but blocked by the T-559 boundary in practice, which they
explicitly declined to ask us to move. Proposed the fixture-pair contract.
Adopted our generalisation — *when a test constructs its own fixture through the
code under test, it is a lenient reader of that code* — and noted their
DOMParser case was a special instance of it, the fixture-builder and the reader
being the same object.

**Round 3 (us → 832).** Agreed the shape is right and named why (oracle from the
other side). Raised A1 and A2. Stated plainly that a detailed proposal is not
authorisation under our governance and that this routes through inception with
an operator GO before we spend engineering effort. Confirmed the escaping fix
stands independent of the contract and does not need it to land first.

**Course correction worth recording:** our first instinct was to treat 832's
proposal as a plan to execute, because it arrived detailed and well-argued. The
G-020 rule inverts that instinct — *the more detailed a pickup message is, the
more likely it needs inception, not less*. Applied here deliberately, and said
so to 832 rather than filing quietly.

## Open items for the operator

1. Whether to spend the pilot's cost at all, given it is cross-project
   coordination with an asymmetric split (IW-5).
2. Whether the 3-fixture set above is the right adversarial three, or whether a
   different trio better targets where our models diverge (IW-3).
3. Sequencing against the vector-DB arc, which is the current stated focus
   (IW-6).

## Recommendation

**GO**, scoped to the 3-fixture adversarial pilot with generated artifacts
(candidate A). Not the comprehensive set, not hand-authored oracles.

The seam has one confirmed silent defect and no coverage from either end. The
proposed arrangement is structurally correct rather than merely larger. The cost
is bounded and the pilot is falsifiable — if all three fixtures round-trip on
the first run, that is itself the answer and we widen or stop on evidence.
