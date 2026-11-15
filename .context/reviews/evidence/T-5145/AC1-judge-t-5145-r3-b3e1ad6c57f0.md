# T-5145 Human AC#1: Filtering the task list from the selects keeps the whole list

Reviewer dispatch: judge-t-5145-r3-b3e1ad6c57f0. Revision ed75c9b590327ce5c21bb6e61ac17b6c40ab7025
(HEAD at review time; `web/templates/tasks.html` has no uncommitted change, so the live page serves the reviewed template).

## What I did

I walked the criterion's steps myself in a headless Chromium (Playwright, 1440x900) against the
live page, using the selects, not the URL.

1. Opened `http://192.168.10.107:3000/tasks?view=list`: 200 rows, pager "Showing 1–200 of 5133 (page 1 of 26)".
2. Picked "work-completed" in the status select. Request sent:
   `/tasks?status=work-completed&q=&owner=&horizon=&tag=&view=list&type=&component=&sort=id`.
   Result: 200 rows, pager "Showing 1–200 of 4572 (page 1 of 23)", every row's status is work-completed.
3. Picked "Sort by Name" in the sort select. Request sent:
   `/tasks?sort=name&q=&owner=&horizon=&tag=&view=list&status=work-completed&type=&component=`.
   Result: still 200 rows, "Showing 1–200 of 4572 (page 1 of 23)"; status select still shows
   work-completed; the 200 names are in ascending order (first: `"Complete Task" button …`, last:
   `Add htmx error handler on /review page …`).
4. Scrolled to the pager and pressed Next. URL:
   `/tasks?sort=name&q=&owner=&horizon=&tag=&status=work-completed&type=&component=&view=list&page=2`.
   Result: 200 rows, "Showing 201–400 of 4572 (page 2 of 23)", all work-completed, names ascending and
   continuing from page 1 (first: `Add inception research audit check …`, last: `BVP /bvp?mode=proposed …`),
   no row shared with page 1; both selects still show work-completed / Sort by Name; Previous and Next both shown.

No request carried a row's value or a new-task form value: each has exactly one `status`, `type`,
`owner`, `horizon`. The browser reported no console or page errors during the walk.

## Against the Expected clause

- "thousands of completed tasks": 4572. Met.
- "paged 200 at a time": 200 rows per page, 23 pages. Met.
- "sorted by name": met. The order is by character code, so names that start with a quote or a dot
  come before letters. That is an observation, not a defect of this criterion.
- "Next keeps both choices": met (URL, selects and rows on page 2).

## Code

`web/templates/tasks.html`: 9 controls carry `data-task-filter` (q, owner, horizon, tag, hidden view,
status, type, component, sort); every filter `hx-include` is `[data-task-filter]`; no
`hx-include="[name=` is left. Commit 61ec0bff6 touched only the template, the new browser test and the task file.

## Screenshots

Mine, from the walk: `walk-pager-p1-*.png` (page 1 pager after both picks), `walk-p2-top-*.png`
(page 2 top, selects kept), `walk-pager-p2-*.png` (page 2 pager, "Showing 201–400 of 4572 (page 2 of 23)").

Dispatch captures: `01-tasks-view-list-*.png` (list view top: filter bar, four toolbar selects,
table, count 5133) and `02-tasks-*.png` (board view top: filter bar and five columns intact). Both
show only the top of the page, as the capture note says.

Task's visual evidence, read at full resolution top and bottom, at 1024, 1440 and 1920:
- `list-filtered@{1024,1440,1920}`: status select shows work-completed, sort select shows Sort by
  Name, "status: work-completed" chip and Clear all visible, table full of rows, pager
  "Showing 1–200 of 4570 (page 1 of 23)" with Next. Selects and pager visible, unclipped, no overlap at all three widths.
- `list@{1024,1440,1920}`: filter bar, four selects, table, pager "Showing 1–200 of 5129 (page 1 of 26)"
  with Next. Visible, unclipped, no overlap at all three widths.

One note on the checklist's "table: ok" cells. The table is wider than the viewport at 1024 (both
states) and at 1440 (filtered state): 1559 px in a 976 / 1392 px container, so the right-hand columns
(Owner onward at 1024, BVP/Tags at 1440) are off-screen. The table sits in an `overflow-x:auto`
container, so those columns are reachable by scrolling sideways, and the page itself does not
overflow. This task added attributes only and did not change that layout, and the criterion does
not ask about it, so it does not affect the verdict.

## Verdict

green.
