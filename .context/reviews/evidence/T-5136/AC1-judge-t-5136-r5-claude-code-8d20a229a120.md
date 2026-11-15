# T-5136 Human AC#1: evidence report (seat claude-code, dispatch judge-t-5136-r5-claude-code-8d20a229a120)

Revision reviewed: 2c3d6550f840ceeb0f4c965e3554832e1ecbb35f. Live Watchtower at http://192.168.10.107:3000, 2026-11-15 about 15:55 to 16:05 local, host load about 17.

## Verdict: amber

Three of the four expected outcomes hold. Step 3 fails when done the way the criterion says ("Pick a status filter or Sort by Name"): picking either one in the toolbar collapses the list to 4 tasks with no pager.

## What I ran

Headless Chromium (Playwright, 1440 px) against the live server, plus curl timings.

| Step | Result |
|------|--------|
| 1. open /tasks?view=list | first row at 0.7 s, complete at 1.1 s; 200 rows; "Showing 1–200 of 5127 (page 1 of 26)"; no Previous link on page 1 |
| 2. Next → | 1.0 s; URL ?view=list&page=2; "Showing 201–400 of 5127 (page 2 of 26)" |
| 2. ← Previous | 1.3 s; URL ?view=list&page=1; "Showing 1–200 of 5127 (page 1 of 26)" |
| 3. pick "work-completed" in the status select | **fails**: header shows "Tasks 4", 4 rows, no "Showing" line, no Next link |
| 3. pick "Sort by Name" in the sort select (fresh page) | **fails** the same way: "Tasks 4", 4 rows, no pager |
| 3 (control). open ?view=list&status=work-completed&sort=name directly, then Next | works: "Showing 201–400 of 4570 (page 2 of 23)", URL ?status=work-completed&sort=name&view=list&page=2 |
| 4. open /search | 0.2 s; "Browse by topic: 24 topics from 1415 tagged items", tag cloud shown |

curl: /tasks?view=list 0.27 to 0.53 s over three warm rounds (864 KB); /search 0.02 to 0.03 s. The very first request of my session to /tasks?view=list took 8.45 s once; every later one was under 0.6 s. I could not reproduce it.

## The step 3 failure

Reproduced twice, each from a freshly loaded page 1. After the pick the address bar holds a 12,136-character URL that starts:

    /tasks?status=work-completed&type=specification&owner=human&horizon=now&q=&owner=&horizon=&tag=&view=list&type=&component=&sort=id&status=work-completed&horizon=now&type=specification&owner=human&status=…

The toolbar selects use hx-include="[name='status'],[name='type'],[name='owner'],[name='horizon'],…" (web/templates/tasks.html:706, all_filters). Those selectors also match the status, horizon, type and owner select in every table row, so each pick sends 200 rows of values. The server takes the first value of each, which is the first row's (type=specification, owner=human, horizon=now), so the list is filtered to those 4 tasks. Screenshot: reviewer-toolbar-status-pick-judge-t-5136-r5-claude-code-8d20a229a120.png (filter chips "owner: human", "horizon: now", "status: work-completed", "type: specification" that nobody picked).

The all_filters line is the same in the commit before T-5136 (5b254c7d8^), so this task did not introduce the wiring. It is still what the operator meets at step 3.

The task's own walk records a clean URL (?status=work-completed&sort=name&view=list&page=2) for this step. A toolbar pick does not produce that URL in my browser; only opening the filtered URL directly does. So that walk shows the pager links keep filter and sort once they are in the URL, which I confirm, but not that picking them works.

## Visual Verification checklist, control by control

| state | control | 1024 | 1440 | 1920 | what I saw |
|-------|---------|------|------|------|-----------|
| list | table, pager row | ok | ok | ok | pager row below the table, "Showing 1–200 of 5125 (page 1 of 26)" left, "Next →" right, no Previous. At 1024 the table is wider than the page: the Owner column is cut at the right edge ("claude-") and BVP/Tags are off-screen; the pager row itself is whole. |
| list-page2 | pager with Previous and Next | ok | ok | ok | "← Previous", "Showing 201–400 of 5125 (page 2 of 26)", "Next →", no overlap. Same Owner-column cut at 1024. |
| search | search box, tag cloud, try-a-search | ok | ok | ok | all present; at 1024 the theme toggle wraps to a second nav line (site chrome, not this task) |
| fabric | subsystem overview | ok | ok | ok | 28 subsystem cards and the component table render |

The two list shots are 13,000 to 17,000 px tall; I judged the pager from crops of the bottom 500 px of each of the six files.

Dispatch screenshots: 01 (list top, toolbar and first rows fine), 02 (search with tag cloud), 04 (fabric), 05 (fabric graph), 06 (board) render normally. 03 (/cockpit/activity) is a bare unstyled bullet list, which looks like an htmx fragment opened as a page; it is not part of this criterion.

## What is needed

Make a toolbar pick send only the toolbar's values: scope hx-include to the filter controls (for example wrap them in one container and include from that, or give the row selects different names), then re-walk step 3 by actually picking from the selects. A regression test that picks from the select in a browser would have caught this.
