# T-5136 Human AC#1 — evidence report (seat claude-code, dispatch judge-t-5136-r5-claude-code-b872f526a95b)

Reviewed revision: aa5c2bb76f5c5c108c760fdbb0b163a1c8fe8a95. The live Watchtower footer reports build cdbfd7bbc;
`git diff cdbfd7bbc aa5c2bb76 -- web` is empty and `web/` has no uncommitted changes, so the served pages are the reviewed code.
/health: warmup state "done" (finished 16:40:03Z) — every timing below is on a WARM server.

Verdict: **green**

## What I did (my own headless-Chromium walk of the criterion's four steps, 1440 px, 2026-11-15)

| step | result | time |
|---|---|---|
| 1. open /tasks?view=list | 200 rows, pager "Showing 1–200 of 5134 (page 1 of 26) · Next →" (no Previous on page 1) | 2.93 s to load + pager |
| 2. click "Next →" | URL ?view=list&page=2, "← Previous · Showing 201–400 of 5134 (page 2 of 26) · Next →", first row T-202 (page 1 started at T-001) | 2.28 s |
| 2. click "← Previous" | URL ?view=list&page=1, "Showing 1–200 of 5134" | 1.81 s |
| 3. toolbar status = work-completed | "Showing 1–200 of 4573 (page 1 of 23)" | 2.71 s |
| 3. then "Next →" | URL keeps status=work-completed, page=2; "Showing 201–400 of 4573 (page 2 of 23)"; toolbar still shows work-completed | 2.76 s |
| 3. toolbar "Sort by Name" (filter still on), then Next, Next, Previous | every URL keeps sort=name AND status=work-completed; pages 2, 3, 2 of 23; all 200 rows on each page have status work-completed (read from each row's own status select); toolbar still shows work-completed / name; name order continues across the page break (page 1 ends "Add htmx error handler…", page 2 starts "Add inception research…", page 3 starts "BVP T-1936…") | 2.29 / 2.47 / 1.77 s |
| last page /tasks?view=list&page=26 | "← Previous · Showing 5001–5134 of 5134 (page 26 of 26)", no Next | — |
| 4. open /search | "Browse by topic", 24 tag-cloud links | 0.64 s |

Browser console / page errors across both walks: none.
curl timings (server only): list 0.57–1.24 s, 864 KB; search 0.06–0.08 s.
Regression tests: `pytest tests/web/test_t5136_task_list_pager.py tests/unit/test_t5136_tag_cloud_c_loader.py` → 10 passed.

Two checks in my first script run were wrong and I discarded them, not the product: a wait that matched the already-present "Next" text,
and a status regex that read the option lists of the row dropdowns. Both were redone correctly in the second run (the table rows above).
My own name-sort comparison (Python str.lower) did not match the server's order exactly; I did not chase which collation the server uses.
The sort itself predates this task; what the criterion asks — that paging KEEPS the sort — is shown by the URL, the toolbar and the
alphabetical continuation across pages.

## Each Expected clause

- "the list appears within a few seconds" — 2.9 s in a browser (warm). Met.
- 'shows "Showing 1–200 of …"' — literal text present: "Showing 1–200 of 5134 (page 1 of 26)". Met.
- "paging keeps the filter and sort" — met for status filter alone, and for filter + sort together, forward and back.
- "the search page with its tag cloud opens within a few seconds" — 0.64 s, 24 topics. Met.

## Screenshots, judged against the Visual Verification checklist

Full-page list shots are 13–17k px tall, so I cropped the top and the bottom of each of the six at full resolution to read the pager row.

| state | control | 1024 | 1440 | 1920 |
|---|---|---|---|---|
| list | table, pager row | ok — pager "Showing 1–200 of 5125 (page 1 of 26)" left, "Next →" right, inside the viewport (live: nav box x 24–1000, Next x 944–1000) | ok | ok |
| list-page2 | pager with Previous and Next | ok — "← Previous · Showing 201–400 of 5125 (page 2 of 26) · Next →" | ok | ok |
| search | search box, tag cloud, try-a-search | ok | ok | ok |
| fabric | subsystem overview | ok | ok | ok |

Judge-evidence pages: 01 list (top only: toolbar, table header, rows — fine), 02 search (tag cloud, 24 topics), 04 fabric, 05 fabric graph, 06 board — all render;
03 /cockpit/activity is an unstyled bullet list because that URL is an htmx fragment (the response is a bare `<ul class="wt-activity-list">`), not a page.

## Things I noticed that are NOT this task's change (not counted against the criterion)

- At 1024 px the list table is 1308 px wide, so the Arc, BVP and Tags columns are off-screen. They are reachable: the table sits in
  `div.table-responsive` (overflow-x auto; I scrolled it and the Tags column came into view). T-5136's template diff is the pager `<nav>` and the loop variable only.
- At 1024 px the top navigation wraps (the theme toggle drops to a second line). Site-wide, not from this task.
- On the board (06), the type/horizon/owner selects in the narrower columns are squeezed to a few pixels of text. Not the list view, not from this task.

## Not tested

- A cold first visit right after a restart. I am read-only and did not restart Watchtower. The task itself records that a request landing while the
  startup warm-up is still running pays the cold cost (39 s for the first list view at one point). The criterion's steps do not ask for a restart, so
  this does not change the verdict, but the operator should know "within a few seconds" was verified warm only.
