# T-5136 Human AC#1 — evidence report (panel seat claude-code, rung 5)

Revision under review: d40b15e3f677ea0f7245fada4a544d2570aa4e7d. Live Watchtower at http://192.168.10.107:3000
(footer: v1.8.16-be.52-53-gd615b8034). All checks below are my own, run 2026-11-16; the task's walk.json was
read as input and re-checked, not trusted.

## Verdict: green

## What I checked, per Expected clause

**1. "the list appears within a few seconds and shows 'Showing 1–200 of …'"**
- curl `/tasks?view=list`: HTTP 200, 3.30 s on my first request, 0.31 s on repeats, 865 KB.
- Headless Chromium (Playwright, 1440x900): 1.42 s from navigation to the pager being present; 200 table rows;
  pager text "Showing 1–200 of 5160 (page 1 of 26)". No console or page errors.

**2. Steps 2: "Next →" and "← Previous"**
- Page 1 shows only "Next →" (no Previous). Click Next: 1.13 s, URL `?view=list&page=2`,
  "Showing 201–400 of 5160 (page 2 of 26)", links "← Previous" and "Next →". Click Previous: 1.40 s, back to
  `page=1`, "Showing 1–200".
- Rows do change: page 1 = T-001…T-201, page 2 = T-202…T-401, page 26 = last 160 rows (5001–5160).
- Out-of-range input is handled: `page=999` clamps to page 26, `page=0` and `page=abc` give page 1 (all HTTP 200).

**3. "paging keeps the filter and sort"**
- In the browser I picked "work-completed" in the status filter (0.76 s; "Showing 1–200 of 4595 (page 1 of 23)"),
  picked "Sort by Name", then clicked Next (1.63 s). Resulting URL:
  `/tasks?sort=name&…&status=work-completed&…&view=list&page=2`, "Showing 201–400 of 4595 (page 2 of 23)".
  Both selects still showed work-completed / name. All 200 rows on page 2 have status work-completed, and names
  run alphabetically (page 1 starts '"Complete Task" button…', page 2 ends "…BPMN…, BVP /arcs…").
  Previous from there keeps the same filter and sort (`…sort=name…status=work-completed…page=1`).
  Screenshot: walk-filter-sort-page2-<id>.png.
- A filter that leaves one page or less (status=started-work, 143 rows) shows no pager, which is correct.

**4. "the search page with its tag cloud opens within a few seconds"**
- curl `/search`: 0.03 s (x4). Browser: 0.21 s to load. Page shows "Browse by topic — 24 topics from 1419
  tagged items" with 24 tag chips, "Try a search" and "Ask a question". No console errors.

## Screenshots read (all 18 given, plus 2 of mine)
- Judge captures 01–06: list top, search with tag cloud, cockpit activity, fabric, fabric graph, board. No errors
  reported by the capturing browser.
- Visual Verification checklist, control by control at 1024 / 1440 / 1920:
  - list — table, pager row: pager row ("Showing 1–200 of 5125 (page 1 of 26)" left, "Next →" right, no Previous)
    visible, unclipped, no overlap at all three widths (read from full shots plus bottom crops I cut).
  - list-page2 — "← Previous", "Showing 201–400 of 5125 (page 2 of 26)", "Next →" all visible and unclipped at
    all three widths (crop-list-page2-1024-pager-<id>.png is the narrowest).
  - search — search box, tag cloud (24 chips, wraps to 3 / 2 / 2 lines), try-a-search: ok at all three widths.
  - fabric — subsystem overview cards and component table: ok at all three widths.

## Observations that do not change the verdict
- After clicking Next/Previous the window stays scrolled at the bottom of the new page (scrollY 14025 of a
  14925 px page), so the reader sees the last rows of the new page and must scroll up ~14,000 px to reach its
  first row. The criterion does not ask for a scroll reset, and staying at the pager makes repeated paging
  quick, but a pager above the table or a scroll-to-top on page change would be kinder.
- At 1024 px (and 1280) the task table is 1308 px wide inside `.table-responsive` (overflow-x: auto): the Owner
  column is cut at the edge and BVP/Tags are reached by scrolling the table sideways. The pager itself sits
  outside that container and is fully visible (24–1000 px). The table layout predates this task
  (commit 5b254c7d8 added only the pager to tasks.html).
- `/cockpit/activity` (judge capture 03) is an unstyled bullet list: it looks like an htmx fragment opened as a
  page. Not part of this criterion.
- I could not restart Watchtower, so the cold-start time of the first request after a restart (the startup
  warm-up in web/warmup.py) is not measured here; my slowest observed request was 3.30 s.
- Visual shots are from 2026-11-15 (5125 tasks, build be.51-66); the live site today (5160 tasks, be.52-53)
  shows the same pager, confirmed by my own walk.
