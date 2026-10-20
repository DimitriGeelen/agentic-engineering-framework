# T-4350 Human AC#1 — Watchtower search after reindex change

Reviewer: independent rung-3 reviewer. Revision: 5f0223840fb1165a4738fe2fdb3c382c1f63530a

## What I checked
- Screenshot `/search?q=release%20decision` (copy in this directory, AC1-<dispatch>-01-search-q-release-20decision.png).
- Task file for a `## Visual Verification` section.

## Findings
- The page renders without an error panel. It reads "Found 20 results for release decision (hybrid) — 13436 docs indexed, 747660 chunks".
- Results are relevant release/decision tasks (T-4364, T-4346, T-3114, T-3192, T-4340, T-4101, ...), Project Decisions (decisions.yaml), fabric components lib-release / lib-release-tags, and one Episodic Memory hit. Each has a title, a path, and a snippet with the matched terms in bold.
- Cosmetic issues (not caused by the reindex as far as I can tell): one facet chip shows "(19)" with no label; the episodic T-4364 hit has a title made of "====" characters.
- There is no `## Visual Verification` section in the T-4350 task file. The brief says the visual-evidence gate does not pass and forbids green for this render criterion.
- I saw only one width (1280px). There is no "before" baseline to compare against, so "as before" cannot be confirmed.

## Outcome
not-evaluated: the required visual-verification evidence is missing (no Visual Verification checklist, no screenshots at every UX_SHOT_WIDTHS width). The single screenshot I saw looks healthy.
