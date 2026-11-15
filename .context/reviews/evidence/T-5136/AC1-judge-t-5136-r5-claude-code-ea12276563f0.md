# T-5136 Human AC#1 — "The task list opens quickly and the pager is usable"
Reviewer seat: rung-5-panel:claude-code. Revision 34bc15411c2c6cf4895387b6975fbe4dd0461eab.

## Outcome: not-evaluated

The criterion is a render criterion ("the pager is usable", scroll to the bottom of the table).
I could not see the rendered pager:
- The task file has no `## Visual Verification` section (only the inert template comment at line 155),
  so there are no `fw ux shots` crops of the pager at any width.
- The capture of `/tasks?view=list` is 16,389 px tall, over the 16,000 px limit; the screenshot
  `01-tasks-view-list` shows only the top of the page (header, filters, rows T-001..T-006). The pager
  at the bottom of the table is not in it.

## What I did check (non-render, measured with curl against http://192.168.10.107:3000, 2026-11-15)

| request | status | time | finding |
|---|---|---|---|
| /tasks?view=list (1st request) | 200 | 6.34 s | "Showing 1–200 of 5122 (page 1 of 26)"; next link `?view=list&page=2` |
| /tasks?view=list (3 repeats) | 200 | 0.84 / 0.39 / 0.35 s | |
| /tasks?view=list&page=2 | 200 | 0.34 s | "Showing 201–400 of 5122"; links to page=1 and page=3 |
| /tasks?view=list&sort=name&page=2 | 200 | 0.34 s | pager links keep `sort=name` |
| /tasks?view=list&status=work-completed&page=2 | 200 | 0.83 s | "Showing 201–400 of 4569"; pager links keep `status=work-completed` |
| /tasks?view=list&status=work-completed&sort=name&page=2 | 200 | 0.31 s | pager links keep both; row order differs from the ID sort (T-185, T-062, T-720 ...) |
| /search | 200 | 0.04 s, 0.03 s | |

- Screenshot `02-search`: search page renders with its tag cloud ("Browse by topic — 24 topics from 1415 tagged items").
- Screenshot `01-tasks-view-list`: list view renders, 5122 tasks, filters and "Sort by ID" present; top of page only.
- Screenshot `06-tasks`: board view renders (top of page only).
- Capturing browser reported no console or page errors on any of the six pages.
- Screenshots `03-cockpit-activity`, `04-fabric`, `05-fabric-graph` are cited because the ledger requires them;
  they are not pages this criterion names and I did not judge them.

## Observation for the producer
One request for `/tasks?view=list` took 6.34 s (the first one I made); all later ones were under 1 s.
"Within a few seconds" is met on repeats; the single 6.3 s load is at the edge and is worth a look
(cache expiry / cold path) when the visual evidence is added.

## What is needed
Add a `## Visual Verification` section to the task file with the pager state(s) of `/tasks?view=list`
(bottom of table: "Showing 1–200 of …", "← Previous", "Next →") and run
`fw ux shots T-5136 <state>=<URL>` at every configured width, then re-dispatch.
