# T-2870 — Two rulings on frozen mapping-v1, answered from the text

**Status:** in progress
**Source of truth:** `policy/standards/aef-bpmn-mapping-v1-partI.md` (vendored T-2869,
sha256 `970dd530…`, 7905 B). Provenance sidecar records 832's commit
`4a1a30e115faae79d0e8fa95a05858903e0ac550`, path `docs/standards/aef-bpmn-mapping-v1.md`,
lines 30-145.

## Why this task exists

AEF is a **ratifying party** for this standard. For six days two rulings sat blocked
because we did not hold the document — every clause we had cited was quoted out of 832's
rail messages rather than read from the text (OBS-190). T-2869 closed that gap. This task
spends the thing we bought: both rulings are now answered **from the text**, including
832's own three cold-reading flags, which they explicitly invited us to challenge rather
than agree with.

Method note: where a ruling rests on the text, the clause is quoted. Where it rests on a
measurement, the command is shown. Nothing here is derived from rail correspondence — that
was the failure mode being corrected.

---

## Ruling 1 — may `aef:laneMeta` carry `authority=`, and what class is it?

**RULING: yes, and it is SEMANTIC.** Four independent derivations, listed weakest to
strongest.

**D1 — by §1's definition rather than its enumeration.** §1 defines the semantic class as
data that "compiles into / out of task-YAML fields". §3 states that `aef:laneMeta
authority` compiles into `owner` via the collapse map `sovereignty→human`,
`initiative→agent`, `authority→agent`, `external→no task`. `owner` is a task-YAML field
(§2's table carries a row for it). The definition is satisfied directly. An enumeration is
evidence about a class; the definition *is* the class.

**D2 — enumeration asymmetry.** §1's semantic list is introduced with "**Includes** the
structured elements…" — non-exhaustive by construction. The presentational list carries no
such hedge; it is a bare enumeration of nine names. For a datum absent from both lists,
exactly one of the two lists is open, and it is not the presentational one.

**D3 — the alternative contradicts §3 and §7.** §1: "A change to a presentational
attribute alone MUST be a no-op for the task graph." Were `authority=` presentational,
flipping `sovereignty`→`initiative` would be *required* to be a no-op. §3 makes it flip
`owner: human`→`owner: agent`; §7 makes it flip an inception from conformant to
non-conformant under a machine check (O-3). Since §1 declares the partition total ("exactly
one of two classes") and presentational is excluded, semantic is forced.

**D4 — §1's read-permission clause, the sharpest.** §1: "The forward compile MUST read
**only** this class." This is not a labelling rule, it is a *permission* rule. If
`authority=` were not semantic, a conformant forward compiler would be **forbidden from
reading it** — making §3's IW-9 collapse map unimplementable and 832's own O-3 compile-time
check non-conformant. Our compiler reads it too (T-2534, tightened T-2540). Either
`authority=` is semantic, or every implementation that exists is in violation.

### The hole is real, and it is a format defect rather than a wrong answer

§1's enumerations are **element-granular** everywhere except `aef:meta`, where the text
switches to attribute granularity ("the scalar governance meta-keys carried as attributes of
`aef:meta`"). `aef:laneMeta` is the second element that needs attribute-granular treatment
and does not get it. Live shape, in both our corpus and 832's own fixtures:

```xml
<aef:laneMeta abbr="hum" authority="sovereignty" height="160"/>
```

`height` is layout. `abbr` is a display label. `authority` is governance. **One element,
both classes.**

§1 already anticipates this: it partitions every "`aef:` **datum**", not every element. That
word is load-bearing and correct. The defect is that the *enumeration format* cannot
express the partition its own *definition* demands — so a reader applying §1 literally to
`aef:laneMeta` finds no answer, which is exactly how this ruling came to be blocked.

**Testable consequence:** a presentational-only edit to `@height` MUST be a task-graph
no-op (§1), while an edit to `@authority` on the same element MUST NOT be. Any
implementation diffing at element granularity — the natural way to diff XML extension
elements — gets one of the two wrong. `@height` changes on every lane resize in the editor,
so the common case is spurious task-graph churn. Measured below.

### Recommended amendment (minimal)

- §1 semantic list, add: *the `authority` attribute of `aef:laneMeta` (§3)*.
- §1 presentational list, add: *`aef:laneMeta` `@abbr`, `@height`*.
- §1, one new sentence: *Where an element carries data of both classes, the partition
  applies per attribute; conformant diffing MUST be attribute-granular.*

---

## Ruling 2 — may a diagram-kind marker be ratified as an attribute of `aef:workflowMeta`?

**RULING: NO — not into frozen v1, because `aef:workflowMeta` is not in v1 at all.**

```
$ grep -c "workflowMeta" policy/standards/aef-bpmn-mapping-v1-partI.md
0
```

Zero occurrences. The standard's only process-level carrier is `aef:arc`, mentioned once in
§3's table row for Process. Meanwhile the reference editor emits, on every process:

```xml
<aef:workflowMeta id="task-lifecycle" uuid="df0b8c59-…" version="1"
                  schemaVersion="2" title="task-lifecycle" tier_default="2"/>
```

This is a carrier gap, not a technicality, with three consequences.

**C1 — the proposed attribute's carrier is itself unclassified.** §1 partitions "every
`aef:` datum". `aef:workflowMeta` carries six data live, none classified by §1. At least one
is plainly governance-bearing: `tier_default` sets the default enforcement tier for every
node in the process, and `tier` is a **frozen v1 governance meta-key** (§2). v1 therefore
freezes `tier` at node level while its process-level default rides on an element the
standard does not acknowledge. Adding `kind=` there deepens the gap rather than filling it.

**C2 — §2's escape hatch does not reach.** §2's note permits additional keys that "MAY
change without a standard bump", but is explicitly scoped to "the editor `metaKeys` set" —
attributes of `aef:meta`, node level. `aef:workflowMeta` is a different element at a
different scope. `kind=` cannot be admitted as editor-internal, because the note that would
license that does not cover the carrier.

**C3 — `kind=` is the most semantic datum in the schema.** §3: the forward compile "produces
a **proposed** task/inception graph". `kind="documentation"` means *this diagram proposes
nothing* — it gates whether the forward compile runs **at all**. Under §1 that is semantic a
fortiori: it does not merely compile into a task-YAML field, it decides whether any
task-YAML is produced. A datum with that authority needs §1 classification, a §2 closed
value set, and a §6 conformance clause — the full amendment path, not an additive attribute.

### Our position: NO on the form, YES on the capability — and we need it

Correct sequence:

1. v1.1 admits `aef:workflowMeta` to §1 and classifies its six existing attributes. Our
   reading: `id`/`uuid`/`version`/`schemaVersion` semantic-identity, `tier_default`
   semantic, `title` 832's call.
2. `kind` then lands with a closed value set and a §6 clause: *a conformant forward compiler
   MUST NOT propose tasks from a `kind="documentation"` process.*
3. Until then diagram-kind is **AEF-local and out-of-standard**, and we say so rather than
   let a local key read as ratified.

**Why we want it, from our own corpus.** Our flagship map `aef-task-lifecycle` documents the
framework's *own* lifecycle. Its nodes are `Run completion gate battery`, `Finalize
(date_finished, move to completed/, episodic, clear focus)`, `Partial-complete (stays
active, owner→human, emit review)`. Forward-compiling it would propose creating tasks to
build machinery that shipped months ago. It is a documentation map with no diagram-kind
marker, sitting in a corpus whose compiler's stated job is to propose tasks. The only thing
standing between it and a spurious task graph is that nobody has run `--write` on it.

That is the operator's outstanding **as-operated vs proposed** ruling wearing a different
hat: without `kind=`, "this diagram describes what already runs" is unrepresentable.

---

## 832's three cold-reading flags — ruled on, not deferred to

### Flag A — §1's partition is normative and bounds what a diagram edit may propose

**Confirmed, and stronger than 832 put it.** The operative sentence is not the partition but
§1's "The forward compile MUST read **only** this class". That is a bound on *reads*, not on
proposals. A conformant compiler that consults a presentational attribute to make any
task-graph decision is non-conformant **even when the resulting proposal is correct**. A
fence on reads is testable by inspection of the compiler; a fence on proposals is only
testable by output sampling. 832 described the weaker of the two fences their own text
establishes.

### Flag B — the frozen key list is a closed set of four; anything else is paraphrase leakage

**Confirmed, and we measured our own exposure rather than describing it.** XML parse of 56
diagrams (`.context/designer/projects/**`, `tests/fixtures/**`), 501 `<aef:meta>` elements,
652 attributes:

| key | count | status |
|---|---:|---|
| `note` | 393 | not frozen |
| `state` | 102 | not frozen |
| `terminalKind` | 74 | not frozen |
| `tier` | 34 | **frozen v1** |
| `triggeredBy` | 18 | not frozen |
| `workflowType` | 10 | **frozen v1** |
| `agentType` | 8 | **frozen v1** |
| `decisionOwner` | 6 | not frozen |
| `softFail`, `guard`, `exitCode`, `gate` | 6 | not frozen |
| `horizon` | 1 | **frozen v1** |

**53 attributes (8%) frozen; 599 (91%) not.** Our corpus is built almost entirely on the
half of the schema that §2 says "MAY change without a standard bump".

`state=` (102 uses) is the exposure that matters: the state-carrier design of
`aef-task-lifecycle` (T-2624) rests on it, and the T-2621 conformance rail audits map-vs-code
transition parity *through* those carriers. If 832 renames it, our maps lose state semantics
silently and the rail keeps passing, because it reads whichever key it is told to read.
Filed as **T-2871** — a durability finding about our corpus, not a defect in the standard.
832's §2 note is a deliberate and correct design choice; our gap is that we built on the
unfrozen half without ever recording that we had.

(First pass at this count used `grep -o '[a-zA-Z_]*='`, which matched `=` inside quoted
`note="…"` text and invented five keys that do not exist — `CLAUDECODE`, `CLASSIFY_ORDER`,
`FW_ALLOW_EMPTY_RECOMMENDATION` among them. The numbers above are from an XML parse.)

### Flag C — can a "Frozen (v1)" heading cover v1.1 content?

832 invited us to challenge this. Answering from the text:

**No — but the defect is in the heading, not the content.** v1.1 material appears in at
least three places:

- §7 heading: "Inception marker (G-3) — **ratified v1.1**"
- §3: "**owner is the lane (IW-9, v1.1)**"
- §7: "machine-checked at compile time (**O-3, v1.1**)"
- §2, `owner` row: ~~`owner`~~ *(derived — see §3)* … "has no node-level BPMN carrier **in
  v1.1**"

The last is decisive. §2 is the section that *defines what frozen means* for this standard —
the closed set of governance meta-keys — and a v1.1 change has **struck a row out of it**. A
frozen table with a struck-through row is not frozen. It is v1.1.

The honest reading is that this document **is mapping-v1.1**, mislabelled. Two remedies:

- **(a) Split** — keep v1 frozen as-was, publish v1.1 deltas separately. Cost: the v1 text
  then describes no implementation that exists, since 832's and ours both implement
  IW-9/O-3.
- **(b) Retitle** to "Part I — Frozen (v1.1)" plus a changelog section recording the v1→v1.1
  deltas. Cost near zero.

**We recommend (b).** Note in fairness that §7 is *transparent* about its own status — 832
did not hide it; only the document-level heading over-claims.

Effect on our pin: a retitle changes bytes, so `tests/unit/standard_pin.bats` goes red and
we re-vendor at the new hash. That is the pin working exactly as its sidecar specifies
("832 cut a new version → re-vendor from a new pin and update the provenance sidecar"), not
the pin failing.

---

## Flag we raise back to 832 (low confidence — theirs to rule)

§1 reads "the scalar **governance meta-keys** carried as attributes of `aef:meta` (§3)". The
governance meta-keys are enumerated and value-bounded in **§2**, titled "Governance
meta-keys carried on `aef:meta`". §3 is "Forward mapping". This reads as a mis-reference in
a frozen normative document. It may be deliberate — pointing at where owner-derivation lives
rather than where the keys are listed — which is why we raise it as a flag and not a
finding.

---

## Empirical leg — does the element-granularity hazard actually bite?

Ruling 1 predicts that an implementation diffing `aef:laneMeta` at element granularity
treats a `@height`-only edit as task-graph-affecting, violating §1's no-op requirement.
Rather than leave that as a text argument, it is measured against our own compiler below.

### Result: the prediction does NOT bite our implementation

Fixture `tests/fixtures/aef-bpmn/session-handover.bpmn`, compiled with `fw bpmn compile`,
baseline 107 lines.

| Arm | Edit | Output | Verdict |
|---|---|---|---|
| 1 | `@height` `150`→`999` (presentational) | 107 lines, **byte-identical** | no-op — **conformant with §1** |
| 2 (control) | `@authority` `sovereignty`→`initiative` (semantic) | 107 lines, **differs in exactly one line** | instrument proven sensitive |

Arm 2's entire delta:

```
16c16
< owner: human
---
> owner: agent
```

One line, exactly the IW-9 collapse map, nothing else perturbed.

**So the hazard is real in the text but absent in this implementation.** Our compiler reads
`aef:laneMeta` attribute-by-attribute rather than diffing the element, which is the correct
resolution of §1's ambiguity — arrived at without the standard ever saying so. The
recommended amendment above therefore does not fix a live bug of ours; it removes an
ambiguity that a *future* or *third-party* element-granular implementation would resolve
wrongly, silently, and in the direction of spurious task-graph churn.

Stating that plainly because the first draft of this section predicted churn and the
measurement refuted it.

### Methodological note — the control failed to protect, and why

The first run of this measurement reported **"ARM 1: TASK GRAPH CHANGED (violates §1)"** and
**"ARM 2: instrument proven sensitive"** — i.e. it confirmed the hypothesis on both arms. It
was wrong on both.

Cause: the arms were run from the scratchpad directory, where `fw` resolves the compiler
relative to cwd and exits 1 with `compiler not found`. With stderr suppressed, both mutants
produced **empty** output. The diff against a 107-line baseline then rendered as
`1,107d0` — which reads as a large delta and is in fact an absence.

The positive control did not catch this, and the reason generalises: **a positive control
that shares the fatal environment defect with the test arm cannot detect that defect.** Both
arms died identically, so the control dutifully reported "different from baseline" and
certified an instrument that was measuring nothing.

The root cause is sharper than "suppressed stderr": the **baseline and the arms were computed
in different working directories**. A before/after harness whose two halves run in different
environments is not comparing the thing it claims to compare. This is the third recorded
instance of that shape (cf. the T-2849/T-2856 harness where `FRAMEWORK_ROOT` differed
between arms and the two halves vendored different sources).

What actually caught it was an **absolute** guard, not a relative one: assert the mutant
output is non-empty *on its own terms* before any comparison. Relative guards compare two
things that can both be broken; absolute guards cannot be satisfied by a corpse. Both guards
are now in the harness above (`VOID:` branch).

---

## Rulings summary

| # | Question | Ruling |
|---|---|---|
| 1 | May `aef:laneMeta` carry `authority=`? What class? | **Yes; SEMANTIC.** Four derivations, strongest being §1's "forward compile MUST read only this class" — the alternative makes every existing implementation non-conformant. |
| 2 | May diagram-kind be ratified as an `aef:workflowMeta` attribute? | **NO on the form** (carrier absent from v1 entirely, grep count 0), **YES on the capability**. Amendment path stated. |
| A | 832's flag: §1 partition normative, bounds proposals | Confirmed, and **stronger** — it bounds *reads*, not proposals. |
| B | 832's flag: frozen set is four; rest is paraphrase leakage | Confirmed, **and we are exposed** — our lifecycle map's `state=` carrier is not frozen. |
| C | 832's flag: can "Frozen (v1)" cover v1.1 content? | **No.** §2's own frozen table has a struck-through row dated v1.1. Document is v1.1, mislabelled. Recommend retitle + changelog. |
| — | Our flag back to 832 | §1 cites "(§3)" for the governance meta-keys; they are enumerated in §2. Low confidence, theirs to rule. |

