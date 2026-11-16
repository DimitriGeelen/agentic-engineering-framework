# T-5136 Human AC#1: evidence report (panel seat claude-code, rung 5)

Reviewer: `reviewer-judge-t-5136-r5-claude-code-ece509c485b8:claude-code`. Revision reviewed: `527d33c296ed874df862d1c012d7b1a24856126f`.
Criterion: "The task list opens quickly and the pager is usable". Expected: the list appears within a few seconds and shows "Showing 1–200 of …"; paging keeps the filter and sort; the search page with its tag cloud opens within a few seconds.

Verdict: **green**. Every clause of Expected was observed directly on the live Watchtower at http://192.168.10.107:3000 on 2026-11-16, not taken from the task's own evidence block.

## 1. The criterion's four steps, walked in a browser (Playwright Chromium, 1440 px)

| step | time | URL after | pager text |
|------|------|-----------|------------|
| open `/tasks?view=list` (to first row) | 1.24 s | `/tasks?view=list` | Showing 1–200 of 5159 (page 1 of 26); 200 rows |
| click "Next →" | 1.18 s | `/tasks?view=list&page=2` | Showing 201–400 of 5159 (page 2 of 26) |
| click "← Previous" | 1.15 s | `/tasks?view=list&page=1` | Showing 1–200 of 5159 (page 1 of 26) |
| pick status = work-completed in the toolbar | 2.35 s (includes a 1.5 s settle wait of mine) | `…status=work-completed…view=list…sort=id` | Showing 1–200 of 4595 (page 1 of 23) |
| pick "Sort by Name" | 2.59 s (same 1.5 s wait) | `…sort=name…status=work-completed…view=list` | Showing 1–200 of 4595 (page 1 of 23) |
| click "Next →" | 1.80 s | `…sort=name…status=work-completed…view=list&page=2` | Showing 201–400 of 4595 (page 2 of 23) |
| open `/search` | 0.24 s | `/search` | Browse by topic: 24 topics from 1419 tagged items |

Console and page errors across the whole walk: none.

Filter and sort kept after paging, checked three ways on the filtered page 2:
- the URL carries `status=work-completed`, `sort=name` and `page=2`;
- all 200 rows have status `work-completed` (one distinct value);
- the toolbar still shows `status=work-completed` and `sort=name` selected, and the Previous and Next links both carry the filter and the sort (`/tasks?status=work-completed&sort=name&view=list&page=1` and `…page=3`).

Row order under "Sort by Name" is alphabetical; 7 of 199 adjacent pairs differ from a case-insensitive order, each explained by upper case sorting before lower case (for example "…for VALID_OWNERS" before "…for agents/audit"). Not part of the criterion; noted only.

Server response alone (curl): list 0.87 s / 865 KB, page 2 0.57 s, filtered and sorted page 2 0.42 s, search 0.04 s / 101 KB.

Screenshots of the walk: `reviewer-w1-pager-page1`, `reviewer-w2-pager-page2`, `reviewer-w3-status-pick`, `reviewer-w4-sort-filter-page2`, `reviewer-w5-search` (each with this dispatch id as suffix).

## 2. Rendered pages from the brief (all six read)

- `01-tasks-view-list`: list view, toolbar and table header, rows from T-001. Top of page only (page is 16,389 px); the pager row is judged from section 1 and the crops in section 3.
- `02-search`: search box, mode buttons, "Browse by topic 24 topics from 1419 tagged items" with the tag cloud, Try a search, Saved Answers. Nothing clipped.
- `03-cockpit-activity`: a bare unstyled list of recent commits. This is an htmx fragment, not a full page, and it is not named in the criterion. Not judged.
- `04-fabric`: 28 subsystem cards and the component table; renders complete.
- `05-fabric-graph`: Fabric Explorer graph renders. Not named in the criterion.
- `06-tasks`: board view, five columns with counts. Top of page only (40,055 px).

## 3. Visual Verification checklist (all 12 shots read)

The list shots are 13,000 to 17,000 px tall, so I cropped the top 420 px and the bottom 330 px of each into `reviewer-crop-list` and `reviewer-crop-list-page2` to read the pager row at full size.

| state | control | 1024 | 1440 | 1920 | what I saw |
|-------|---------|------|------|------|------------|
| list | table, pager row | ok | ok | ok | "Showing 1–200 of 5125 (page 1 of 26)" at the left, "Next →" at the right, below the last row; no Previous on page 1 |
| list-page2 | pager with Previous and Next | ok | ok | ok | "← Previous · Showing 201–400 of 5125 (page 2 of 26) · Next →", one row, no overlap |
| search | search box, tag cloud, try-a-search | ok | ok | ok | all three present; tag cloud wraps to 3 / 2 / 2 lines |
| fabric | subsystem overview | ok | ok | ok | 28 cards in three columns, component table below |

Measured on the live page: at 1024 px the table is 1308 px wide inside a 976 px container with `overflow-x: auto`, so the BVP and Tags columns are reached by scrolling the table sideways; the document itself does not overflow (1024 px) and "Next →" ends at x=1000, inside the viewport. At 1440 px with "Sort by Name" the table is 1607 px in a 1392 px container (same sideways scroll; visible in `reviewer-w4-sort-filter-page2`, where the BVP column starts at the right edge). The pager is unaffected at every width. The wide table predates this task's pager and the criterion does not cover it.

## 4. What I did not test

- A cold start. I am read-only and did not restart Watchtower, so the first load after a restart (the case `web/warmup.py` exists for) was not timed. The criterion as written asks for the list and the search page to open within a few seconds, which they do on the running server.
- The total is 5159 now against 5125 in the task's shots: tasks were created in between, nothing more.
