# T-2140 corpus walk — `review-link-homework` detector

**Date:** 2026-05-31
**Task:** T-2140 (T-2138 V2)
**Scope:** `.tasks/{active,completed}/T-*.md` — every task file in the repo

## Method

Loaded `lib.reviewer.static_scan.detect_review_link_homework` and ran the
detector against the `## Acceptance Criteria` section of every task file.
Detector fires on `### Human` ACs whose Steps/body contain one of three
named homework patterns (`URL from bin/fw watchtower url`, `base from
bin/fw watchtower url`, `(Watchtower URL from`) and no author opt-out
marker.

## Walk size

| Quantity | Value |
|----------|-------|
| Task files scanned | 2119 |
| Tasks with Human-AC homework patterns | 5 |
| Findings (per-AC) | 5 |
| Match rate | 0.24% |
| False-positives | 0 |
| False-negatives (vs T-2138 prior grep) | 0 |

## Hits (true positives — all `### Human` ACs)

| File | AC# | Site class |
|------|-----|------------|
| `.tasks/active/T-1991-watchtower-foundation-tokens--6-palettes.md` | 1 | arc-007 (foundation tokens) |
| `.tasks/active/T-2012-arc-007-s6a--command-palette-core-k-jump.md` | 1 | arc-007 (command palette) |
| `.tasks/active/T-2013-arc-007-s6b--keyboard-shortcuts-overlay-.md` | 1 | arc-007 (keyboard shortcuts) |
| `.tasks/active/T-2027-arc-007-s5a--arcs-pages-semantic-colour-.md` | 1 | arc-007 (semantic colour) |
| `.tasks/completed/T-1853-watchtower-arcs-lifecycle-filter-tabs-t-.md` | 1 | arc-007 (lifecycle filter tabs) |

All five hits are the genuine homework-pattern sites that prompted T-2138's
RCA. The four active sites still carry the pattern in `### Human` ACs;
T-1853 already shipped with the pattern (completed pre-T-2138). T-2139's
transition-time gate will block these at next handoff; this detector
surfaces them during pre-completion review (`bin/fw reviewer T-XXX`) so
the agent can self-correct earlier.

## Silenced (true negatives — documentation-meta class)

T-2138's prior grep found these additional sites; the detector correctly
silences them because the pattern occurrences are in body sections
outside `## Acceptance Criteria` (e.g. `## Problem Statement`,
`## Recommendation`, `## Context`), not in `### Human` ACs.

| File | Why silent |
|------|------------|
| `.tasks/completed/T-2030-review-hand-offs-must-always-emit-concre.md` | Origin inception; pattern discussed in body, AC clean |
| `.tasks/completed/T-2118-review-handoff-palette-inception.md` | Sibling inception; pattern in `## Problem Statement` only, Human AC has full URL |
| `.tasks/completed/T-2138-rca-review-handoff-homework-pattern-recu.md` | RCA itself; pattern quoted in body, Human AC clean |
| `.tasks/completed/T-2139-transition-time-blocking-gate--review-li.md` | V1 gate build; pattern in Context + Recommendation, Human AC clean |
| `.tasks/completed/T-2140-reviewer-static-scan-catalogue-entry--re.md` | This task; pattern in AC bodies under `### Agent`, not `### Human` |

## Design choices that drove 0 false-positives

The detector landed at 1/1 precision on first attempt — better than the
sibling arc-008 detectors (T-2147 audience-mismatch needed 3 regex
iterations to clear corpus FPs; T-2145 defer-as-hedge needed an
indicator-count threshold raise from ≥1 to ≥2). Two structural choices
made the difference:

1. **Scope to `## Acceptance Criteria` section, not whole body.** Done at
   `scan_task` invocation site (`detect_review_link_homework(ac_section)`).
   This structurally excludes the documentation-meta class — RCAs and gate
   builds inherently quote the literal pattern in their `## Problem
   Statement` / `## Recommendation` / `## Context` blocks.

2. **Filter to `### Human` subhead inside the AC section.** Done in the
   `_check_and_emit` inner check. Agent ACs and Verification commands
   legitimately reference paths and shell invocations; only Human Steps
   need clickable URLs because only humans click.

Together these two filters carve out exactly the surface where the
pattern is a violation, with no regex tuning needed.

## Opt-out marker design

Even with the structural scoping above, a Human AC inside a future
documentation-meta task could legitimately quote the literal pattern
(e.g. "verify the catalogue description text reads cleanly"). The
detector supports three opt-out phrases via `_REVIEW_LINK_OPT_OUT_RE`:

- `<!-- review-link-homework-ok: ... -->` — primary syntax (mirrors
  audience-mismatch's `audience: operator` shape)
- `<!-- meta: review-link-homework-discussed -->` — alternate
- text saying "documents the homework pattern" — natural-language form

Override-add via `fw reviewer override add T-XXX --pattern
review-link-homework --reason "..." --ttl 90` is also available for
TTL'd FP suppression, same as the other detectors.

## Conclusion

The detector lands at 0/0 false-positive rate on the live 2119-task
corpus on first attempt, with 5 true-positive captures matching T-2138's
prior grep exactly. Structural scoping (AC section + `### Human`
subhead) eliminates the meta-task FP class without regex tuning. Future
violations will surface as CONCERN during `fw reviewer T-XXX`
pre-completion review, prompting self-correction before T-2139's
transition-time gate fires at handoff.
