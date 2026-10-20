# T-4350 Human AC#1 — Watchtower search results after the reindex change

Reviewer: independent (rung-3-termlink-single-reviewer). Revision a5f66187fe1f4a5adfd0a933c1761e5ff646a49a.

## What I checked
- Read all 4 screenshots of `/search?q=release%20decision`:
  - `01-search-q-release-20decision.png` (judge evidence, 1280 wide)
  - `search@1024.png`, `search@1440.png`, `search@1920.png` (fw ux shots, capture.json ts 2026-10-20T12:08:03Z)
- Every screenshot shows: "Found 20 results for release decision (hybrid) — 13449 docs indexed, 749004 chunks".
  The mode is hybrid, there is no keyword-fallback notice (T-4458), no error panel, and the list is not empty.
- Results are relevant to the query: T-4364 (release decision gate), T-4346, T-3114, T-3192, T-4340, T-4101, T-1256,
  T-3193, T-4146, T-4107, T-4097, T-3820, T-3822, Project Decisions (.context/project/decisions.yaml), T-3242,
  T-4023 report, fabric cards lib-release / lib-release-tags, T-3190, episodic T-4364.
  Each result has a title, a path chip and a snippet with the query terms in bold.
- Visual Verification checklist (result list / titles / snippets) at 1024/1440/1920: all are visible, reachable,
  unclipped, with no overlap. The long T-4146 title wraps cleanly. At 1024 the header's dark-mode toggle wraps to a
  second nav row (global header, outside this criterion, not caused by the reindex).
- Ran a read-only SQLite query against `.context/working/fw-vec-index.db`. Every row has a non-empty category
  (Handovers, Completed Tasks, Active Tasks, Episodic Memory, Research Reports, Specifications, Project Memory,
  Component Fabric, Saved Answers, canary). The paths of the results shown carry the right categories.
  So the reindex change (commit 91eb3f552, web/embeddings.py reindex_incremental) did not write blank metadata.

## Cosmetic quirks (non-blocking, not caused by the reindex)
1. A filter chip reads "(19)" with an empty label. The vector rows all have categories, so this comes from the
   hybrid merge carrying the keyword/BM25 item's category (`item.get("category", "")`). It does not come from the
   index contents.
2. The episodic T-4364 result's title renders as a `====` line (extract_title heuristic on the episodic YAML).
Both are worth a follow-up ticket but do not fail this criterion.

## Verdict
green. The search page renders relevant hybrid results with titles and snippets at every width, with no error or empty list.
