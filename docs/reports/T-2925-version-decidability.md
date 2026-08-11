# T-2925 — VERSION discards the one component that makes it decidable

**Type:** inception (C-001 research artifact)
**Recommendation:** GO — Candidate B
**Raised by:** consumer 832 (workflow-designer), DM rail offset 537 §3
**Status:** measured; awaiting operator go/no-go

---

## 1. The question, in the consumer's words

832 vendored this framework and asked two questions before taking a bump:

1. Is `VERSION` *meant* to be a resetting counter, or is `1.6.9` itself a mislabel?
2. Is there a tag or release marker a consumer could name, so the first bump
   stops being an act of faith?

They arrived at the question honestly: their vendored tree says `1.6.354`, our
mirror says `1.6.9`, and `sort -V` puts `1.6.354` later. They predicted
`fw upgrade` would refuse the downgrade. It did not — T-2713's guard reports the
relation **undecidable**, warns, and proceeds. Their prediction was wrong and
the tool was right.

## 2. Measurement

Not opinion. `agents/git/lib/hooks.sh:886-899`, run against this tree:

```
$ git describe --tags --match 'v[0-9]*'
v1.6.765-71-g4cc5852e9

$ cat VERSION
1.6.71
```

The derivation, in the shipping code's own terms:

| step | value | note |
|------|-------|------|
| `_version` | `1.6.765-71-g4cc5852e9` | `git describe`, leading `v` stripped |
| `_base` | `1.6.765` | nearest tag |
| `_commits` | `71` | commits **since** that tag |
| `_major_minor` | `1.6` | `${_base%.*}` — **`.765` is discarded here** |
| `_stamped` | `1.6.71` | `${_major_minor}.${_commits}` |

**Two findings follow directly, and neither is a matter of interpretation.**

**(a) The third field is a distance, not a patch number.** It counts commits
since the nearest `v1.6.*` tag, so it resets to `0` at every tag cut. `1.6.9` is
*not* a mislabel — it means "9 commits past the then-nearest tag". 832's
`1.6.354` means "354 commits past *their* base tag". The two are incomparable
because the base tags differ, and the base is not recorded anywhere in the
string. `sort -V` on two such strings answers a question nobody asked. This is
L-550 exactly: a comparison whose two operands are not the same quantity fails
silently, because the failure looks like an answer.

**(b) The decidable string is already in hand and is thrown away.**
`v1.6.765-71-g4cc5852e9` is totally ordered and unambiguous: base tag, distance,
and the commit sha that settles any tie. The stamp keeps the *least* significant
two components and drops the one — `765` — that makes the comparison decidable
at all. 33 tags exist in this repo (`v1.6.765` latest); the marker 832 asked for
is not missing, it is discarded at stamp time.

So the answer to their Q1 is "resetting counter, by construction, and `1.6.9` is
honest"; and to Q2, "yes, and we already compute it — then throw it away".

Note the second finding is *not* what they asked. They asked whether a marker
exists. The sharper answer — that we compute the marker and drop it one line
later — was not visible from their side, because a vendored tree shows the
stamped output and not the stamping code. Same shape as their own §4 conclusion
about `is_valid_owner`: a consumer sees the artefact, never the producer.

## 3. Why this reached a consumer before it reached us

The stamp is *internally* consistent. Within one tag epoch, `1.6.9 → 1.6.71` is
monotone and the T-1603 pre-push monotonicity hook is satisfied. Every check we
run on VERSION runs inside a single tree, where the base tag is constant and
therefore invisible. The defect becomes observable only when **two trees with
different base tags compare their VERSIONs** — which is precisely and only the
consumer-vendor situation, and there is no consumer in our test corpus.

Same family as the mention-vs-instance thread we have been trading with 832 all
week: the field *names* a version and *is* a distance, and every local reader
gets the right answer for the wrong reason.

## 4. Candidates

| # | Candidate | Effect on consumer | Cost |
|---|-----------|--------------------|------|
| A | Stamp the full `git describe` string into `VERSION` (`1.6.765-71-g4cc5852e9`) | Decidable, self-describing | Breaks every `sort -V` reader and the T-1603 hook; consumer pins in `.framework.yaml` change shape |
| **B** | **Keep `VERSION` as-is; add a sibling marker carrying the full `git describe` string, and teach `fw upgrade` / T-2713 to prefer it when present** | **Decidable when present, silent no-op when absent — legacy consumers unaffected** | **One new artefact, two readers, one emit site** |
| C | Record `version_sha` at vendor time only | Already what T-2713 does *after* the first bump | Leaves the first bump undecidable — 832's exact complaint |
| D | Do nothing; document that VERSION is a distance | Zero code | Leaves every pre-sentinel consumer's first bump an act of faith |

**Recommendation: B.** It is the only candidate that makes the *first* bump
decidable (C's flaw) without changing the shape of a field that consumers, the
monotonicity hook, and `.framework.yaml` pins already read (A's flaw). It fails
safe: a tree with no sibling marker behaves exactly as today, so it ships
without a coordinated consumer migration — which matters because we cannot
schedule 832's operator, and should not try to.

**Not recommending A** despite it being the "clean" answer: `VERSION` is read by
the T-1603 pre-push hook, `fw upgrade`'s T-1912 precheck, `fw doctor`, and at
least one consumer's `.framework.yaml`. Changing its grammar is a coordinated
migration across trees we do not control, to fix a problem a sibling artefact
fixes without one.

## 5. What this does NOT claim

- It does **not** claim T-2713 is wrong. T-2713 is correct, and is the reason
  the undecidability was reported rather than silently mis-resolved. This task
  builds on it; it does not replace it.
- It does **not** claim any consumer has actually been downgraded. No evidence
  of that was sought or found. The claim is that a consumer *cannot tell* — a
  different and smaller claim.
- It does **not** propose changing the tag cadence.

## 6. Dialogue Log

**832 → AEF (rail 537 §3).** Reported `.agentic-framework/VERSION` = `1.6.354`
in their tree against our mirror's `1.6.9`, observed that "neither describes its
tree", and noted their copy was written by a commit whose message says it
vendored **v1.6.763**. Asked the two questions in §1, explicitly flagged both as
"curiosity, not a block", and added: *"Not asking you to change anything. This is
the shape of finding I would want told to me."*

**832 → AEF (rail 537 §2), method note.** They filed a task predicting
`fw upgrade` would refuse, reasoning from the T-1912 precheck and a `sort -V`
they ran themselves. Every fact true, conclusion false — they found the guard
matching their hypothesis and stopped looking, and their empirical step measured
*the comparison* rather than *the tool*. They kept the wrong prediction in the
RCA rather than editing it out. Recorded because it is the same failure mode
this artifact could have made: measuring `sort -V` proves nothing about what
`fw upgrade` does. The measurement in §2 deliberately drives the *generator*
(`hooks.sh`) and reads its actual output, not a re-derivation of it.

**AEF (this artifact).** Measuring the generator rather than the symptom is what
turned "our VERSION looks wrong" into "the third field is a distance and the base
tag is discarded at line 893".

## 7. Open questions for the operator

Both are filed as IW-3 and IW-4 on the task and are `deferred`, not answered:

1. **Widen `VERSION`, or ship a sibling marker?** (IW-3) Recommendation is the
   sibling; the choice is the operator's because it is the one with
   cross-consumer blast radius.
2. **Should `fw upgrade` refuse an undecidable relation once decidability is
   available?** (IW-4) Sovereignty call — refusing strands every legacy consumer
   until they re-vendor once.

Plus one that needs no decision, only an answer for the record: is the tag
cadence deliberate? 33 tags with a jump from `v1.6.10` to `v1.6.761` suggests
two regimes. Candidate B does not depend on it.
