# T-3252: Recommendation card silently drops text

## Symptom

`web/shared.py:extract_recommendation` tokenises a task's `## Recommendation`
section by bold markers (`**Recommendation:**`, `**Rationale:**`, `**Evidence:**`,
`**Captured learning:**`) and only writes `rationale` and `evidence` into its
return value. Everything else — a span under a marker it doesn't recognise, text
before the first marker, prose trailing the verdict token on the Recommendation
line itself — was discarded. `raw` (the full section text) was computed but never
rendered anywhere. No warning, no count, no visible gap on the `/review/<id>`
card.

Reported by 001-CashWeb (their G-081) at chat-arc offset 956.

## Measurement — before

`docs/reports/T-3252-measure-recommendation-loss.py` walks every task file under
`.tasks/{active,completed}`, calls `extract_recommendation`, and re-derives the
same marker spans the function iterates over internally (`_REC_MARKER_RE` over
the raw section text — not a naive per-line split, which mis-scores an author's
bold marker that happens to wrap across a hard-wrapped line break as two
mismatched fragments instead of the one span the real tokenizer sees). Each
span is checked for presence, flattened (markdown emphasis/links stripped,
separator dashes normalised, whitespace collapsed, lowercased), in the union
of the structured output fields. A span under 25 flattened characters is
treated as noise (dividers, blank markers) and skipped.

Run against the pre-fix parser (`git stash push -- web/shared.py`, script
unchanged, `git stash pop` to restore):

```
bodies_with_section: 1058
lossy_cards: 602
dropped_fragments: 1452
```

602 of 1058 cards (57%) drop at least one real span. Worked examples, first
dropped fragment per card:

- `T-1265` — *"DEFER — demand has not materialised"* — the entire reason for
  the deferral, discarded because it trails the verdict token on the same line.
- `T-1685` — *"This NO-GO is structural confirmation of G-064 — the framework's
  existing autonomous workload is not…"* — a span under the author's own
  `**Implications:**` label, classified `other`, dropped.
- `T-2137` — *"read the research artifact, pick one of Candidates A/B/C/D, answer
  the three open scope questions…"* — the operator's actual next steps, under
  `**Operator action requested:**`, dropped.
- `T-100201` — *"CLOSE AS DISSOLVED. Do not adopt A, B, C or D."* — the operative
  instruction, on the verdict line, after the token.

Every one of those is the sentence a decision-maker most needs. A caveat the
operator never sees does not exist for that decision.

## Fix

`extract_recommendation` (`web/shared.py`) now buckets every span it finds
instead of dropping the ones it can't name:

- **`other`** (new field) — text before the first bold marker (or the whole
  section when there are no markers at all), a span under an unrecognised
  label (`captured_learning`, or anything `_classify_rec_marker` calls
  `other`), and a Recommendation-marker span whose value isn't a recognised
  verdict token (e.g. informal `SHIP`/`DROP`). Labeled spans keep their
  author-written heading (`**Implications**\n\n...`) so a reader can tell an
  author's own heading from one the parser understands.
- **`verdict_note`** (new field) — prose trailing the verdict token on the
  Recommendation line itself (`GO — demand has not materialised` → verdict
  `GO`, note `demand has not materialised`). The verdict regex also now
  tolerates the token itself being bold-wrapped (`**GO**`), a real-world
  pattern present in ~20 corpus cards that previously lost the verdict *and*
  the note together.

`web/blueprints/review.py` passes `rec["other"]` (rendered markdown) and
`rec["verdict_note"]` to the template. `web/templates/review.html`:

- appends `verdict_note` to the `<h3>` next to the verdict badge, in both the
  complete-card and verdict-only-warning branches;
- renders `other` as a labeled "Other" subsection alongside Rationale/Evidence,
  in both of those branches;
- adds a new fallback branch, ranked below the existing NO-REC banner, for
  sections that have content but no parseable verdict/rationale at all (e.g.
  a stray block pasted under the wrong heading) — previously such a section
  rendered nothing whatsoever.

## Measurement — after

Same script, same corpus, fix applied:

```
bodies_with_section: 1058
lossy_cards: 0
dropped_fragments: 0
```

Zero. (An earlier draft of this script split `raw` on literal newlines instead
of re-deriving `_REC_MARKER_RE` spans, and flagged 2 false positives — both
task files where an author's own `**bold**` span wraps across a hard-wrapped
line break, so a per-line comparison split what the real tokenizer treats as
one span. Switching the script to reuse the same span boundaries the function
actually iterates over — rather than trusting a second, independently-invented
notion of "a chunk of text" — resolved both without touching `web/shared.py`.
The two spans were always present in `extract_recommendation`'s actual output;
the earlier number measured the wrong thing, not a real gap.)

## Regression tests

`tests/unit/test_extract_recommendation.py` — 8 new tests, one per shape plus
a combined case and the dash-doubling fix:

- `test_shape_a_preamble_before_first_marker_preserved`
- `test_shape_a_no_markers_at_all_preserved_in_other`
- `test_shape_b_verdict_trailing_prose_preserved`
- `test_shape_b_verdict_trailing_prose_bold_wrapped_token`
- `test_shape_c_other_labeled_span_preserved_with_label`
- `test_shape_c_recommendation_bucket_unrecognised_verdict_token_preserved`
- `test_all_three_shapes_together_nothing_dropped`
- `test_verdict_note_leading_separator_stripped`

**Negative control:** `git stash` on `web/shared.py` alone (keeping the new
tests) and re-running the suite fails all 8 new tests — 5 with `KeyError` on
`out["other"]` / `out["verdict_note"]` (keys that don't exist pre-fix), the
rest on missing text — while the 24 pre-existing tests stay green. Confirms
the tests exercise the actual defect rather than passing vacuously.

## Rendering verification

`/review/<id>` rendered in-process (Flask test client, no live server
disruption) for three representative cards:

- `T-2530` — verdict + rationale + evidence + genuine `other` content
  (`**832 convergence bonus**`, `**Human AC pending**`) and a `verdict_note`
  (`(partial-complete — one [REVIEW] Human AC remains).`) — all four render;
  `<h3>` reads `Recommendation — GO — (partial-complete — …)`, Other section
  shows both labeled spans.
- `T-1872` — bold-wrapped verdict (`**GO** — close T-1872…`) — verdict parses
  to `GO`, note renders once (`Recommendation — GO — close T-1872 as
  work-completed…`), not doubled.
- `T-3182` — a Recommendation section with no parseable structure at all (an
  authoring accident — Verification-block shell commands pasted under the
  wrong heading) — previously rendered nothing; now renders the new
  "Recommendation — unparsed" fallback with the actual content visible.
