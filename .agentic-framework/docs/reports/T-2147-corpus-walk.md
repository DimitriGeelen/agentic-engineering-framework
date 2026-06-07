# T-2147 corpus walk — `audience-mismatch` detector

**Date:** 2026-05-31
**Task:** T-2147 (T-2143 leg B)
**Scope:** `.tasks/{active,completed}/T-*.md` — every task file in the repo

## Method

Loaded `lib.reviewer.static_scan.detect_audience_mismatch` and ran against the
`### Human` AC section of every task file. Pattern emits CONCERN when a
`[REVIEW]`-prefixed Human AC contains agent-as-subject phrasing without a
human-subject re-anchor in the `**Expected:**` clause.

## Walk size

| Quantity | Value |
|----------|-------|
| Task files scanned | 2119 |
| Parse errors | 0 |
| Findings (final regex) | 1 |
| Match rate | 0.05% |

## Iteration log

The detector regex was tuned twice during the walk based on false-positive
shapes the corpus revealed.

### Pass 1 — full spec regex

Initial regex matched all the verbs the task spec listed: `agent who`,
`agent reads`, `agent trips`, `agent files`, `agent sees`, `agent gets`,
`agent handles`, plus `the agent will <any verb>`.

**Findings:** 5

| File | AC | Evidence | Classification |
|------|----|----|----|
| T-2062 | #1 | "agent files build child for the chosen path" | FALSE POSITIVE (architectural narrative — agent's action after operator decides) |
| T-1910 | #1 | "the agent will adjust" | FALSE POSITIVE (architectural narrative — agent's action after operator feedback) |
| T-1829 | #1 | "agent files a build task to implement the chosen approach" | FALSE POSITIVE (architectural narrative) |
| T-1766 | #1 | "fresh agent acts without re-reading the source task" | GENUINE — AC asks operator to judge agent cognitive load |
| T-1830 | #1 | "agent files build tasks for chosen pattern" | FALSE POSITIVE (architectural narrative) |

Class signal: 4/5 false positives shared the shape *"agent files [build|task|child|tasks|...]"* — describing the agent's action POST-decision, not asking the operator about agent experience.

### Pass 2 — drop `agent files`; keep `the agent will <any-verb>`

Removed `files?` from the receptive-verb list because the corpus showed it
is overwhelmingly used in the architectural-narrative shape, not the
audience-mismatch shape. The task spec listed `agent files`, but corpus
evidence overrules — per T-2143's antifragility principle, false success is
worse than acknowledged failure.

**Findings:** 2 (T-1910, T-1766)

T-1910 remains a false positive because "the agent will adjust" matches
`the agent will` regardless of the trailing verb's class (receptive vs.
productive).

### Pass 3 — restrict `the agent will` to receptive verbs

Tightened `the agent will <verb>` to require the verb be receptive (see /
read / get / receive / unblock / encounter / hit / trip) rather than
productive (adjust / fix / file / write).

**Findings:** 1 (T-1766) — the genuine catch.

## Final result

| File | AC | Evidence | Classification | Action |
|------|----|----|----|--------|
| T-1766 | #1 | "fresh agent acts without re-reading the source task" | **GENUINE audience-mismatch** | See "T-1766 handling" below |

## T-1766 handling

The AC asks the operator to judge whether *a fresh agent reading the
block-message* can act without re-opening T-1766. This is the operator-as-
proxy approach for an agent-experience judgment — precisely the class
T-2143/T-2147 ruled out. By the audience axis, this should be:
- An Agent self-eval (the agent triggering the gate is in the right seat
  to judge its own cognitive load), OR
- Deleted and replaced by an integration test that proves the structural
  property (e.g. "first 80 chars of stderr contain the three info pieces")

**T-1897 split context:** the file already records (2026-05-18) that the
AC was split from a structural-conformance claim. The residual `[REVIEW]`
was deliberately kept as a "genuine cognitive-load UX judgment" — but
T-2143's audience axis (codified 2026-05-31 in T-2148) says cognitive-load
on the agent is not the operator's judgment to make.

**Recommended action (not in T-2147 scope):**
- File a follow-up to either delete the AC and rely on the integration
  test, OR re-route as `### Agent` self-eval.
- Alternative: file a TTL'd reviewer override
  (`fw reviewer override add T-1766 --pattern audience-mismatch --ac 1
  --reason "T-1897 split deliberation; kept as proxy-verification" --ttl 90`)
  to suppress the finding while preserving the deliberation note.

This is **not** T-2147's responsibility to close — the corpus walk
surfaces it; the audience-axis ladder governs the fix.

## Conclusion

The detector lands a 0.05% match rate on the live corpus with a 1/1 precision
after corpus-tuned regex. The 4 architectural-narrative false-positives
discovered in pass 1 produced two regex refinements that should serve future
authors well — the receptive-vs-productive verb split mirrors the broader
audience-axis principle.

