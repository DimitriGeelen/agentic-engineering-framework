# Bug report: reviewer disposition-incomplete detector — two extraction defects

- **Filed by:** termlink-agent (010-termlink)
- **Date:** 2026-07-04
- **Severity:** medium (false-positive CONCERN verdicts on well-evidenced inceptions)
- **Component:** `lib/reviewer/static_scan.py` — `detect_disposition_completeness` (T-2191 pattern, catalogue v1.3-seed)
- **TermLink-side tracking:** T-2349 (spike report `docs/reports/T-2349-reviewer-rail-inception-spikes.md`)

## Defect 1 — template-comment IW entries parsed as real entries

The task template's HTML comment inside `## Open Questions` contains a literal
example entry (`- **IW-1: <question text>**` ... `disposition: answered | deferred |
dissolved` ... `rationale: <one-line evidence — ...>`). `detect_disposition_completeness`
does not strip HTML comments before slicing IW entries, so:

- the example bullet matches `^\s*-\s*\*\*IW-(\d+):`
- `disposition:` regex `(\S+)` captures `answered` from the pipe-separated example
- the placeholder rationale has no citation

=> a **phantom `disposition-incomplete` finding fires on every inception that keeps
the template comment** (which the template invites). Observed live on 010-termlink:
T-2338's flagged "IW-1" is the comment's example (the real IW-1 rationale cites
T-2314 + channel.rs:8568-8611 and passes); T-2276's IW-1 is flagged TWICE
(comment phantom + real entry).

**Fix suggestion:** strip `<!-- ... -->` blocks from the section text before entry
slicing (same pre-pass other detectors use for template-only detection).

## Defect 2 — multi-line rationales truncated to first line

Check D extracts the rationale with `^\s*rationale:\s*(.+?)$` (re.MULTILINE) —
first line only. Rationales that wrap (the natural case for one-line-evidence +
context) carry their citation on a continuation line, which the check never sees.

Observed live: T-2338 IW-2 rationale line 1 = "Yes, one narrow one — after 6
consecutive sub-5s failures the raw consumer" (no citation shape), line 2 =
"breaks to steady poll permanently (`channel.rs:8597-8601`, never re-probes WS)"
(citation present) => false "answered-without-citation".

**Fix suggestion:** accumulate rationale text from the `rationale:` line until the
next `^\s*\w+:` field line or entry boundary, then run `_has_citation` on the
accumulated text.

## Why this matters for the reviewer-assisted-inception-decides proposal (pickup 073)

These two defects are in the exact extraction path pickup 073's verdict rail would
build on. Fixing them first lifts precision before the CONFIRMED/UNVERIFIED/
CONTRADICTED verification layer lands. Repro harness (run in any consumer project):
`fw reviewer <inception-id> --no-write --json` against an inception whose Open
Questions section retains the template comment.
