# T-5136 Human AC#1 — AMENDED report (supersedes my green row V-20261115-190e237e)

## Verdict: amber

I first recorded green. Seconds later I measured the list again and withdrew it. Reason:

| When | What preceded it | `/tasks?view=list` (curl) |
|---|---|---|
| ~16:57:50 | review-ledger files written 16:57:43–46 (this review's dispatch) | **9.2 s** |
| 16:58–17:04, 50 requests | nothing, or an ordinary commit (17:01:03) | 0.27–1.0 s |
| right after my `verdict record --commit` | verdicts.jsonl written and committed | **22.5 s** |
| the request after that | nothing | 0.5 s |

So the slow load is reproducible, two out of two: after any write to `.context/reviews/*.jsonl` (a review
dispatched, a verdict recorded), the next list load takes 9–22 s. `web/shared.py::_readiness_stamp` keys the
"awaiting review" cache on those files and `web/blueprints/tasks.py:831` (`board_awaiting_reason`) rebuilds it
on the request. The startup warm-up does not cover it, because it runs once. The task's RCA names this cost and
says "Not changed here". In this project reviews are dispatched and recorded many times a day, so the operator
will meet it, most likely right after a review finishes, which is when they open the list.

Everything else in the criterion is met, as the original report below shows: in the steady state the list
appears in about 2 s in a browser, shows "Showing 1–200 of …", the pager keeps filter and sort, and `/search`
with its tag cloud opens in 0.4 s.

## What is needed

Either make the list (and board) not pay the verdict-ledger re-verification on the request after a ledger write
(for example: rebuild it off the request thread, or re-verify only the tasks whose rows changed), or the operator
accepts a 9–22 s first load after each review write as within "a few seconds" for this criterion.

---
(original report follows, unchanged apart from its verdict being superseded)

# T-5136 Human AC#1 — "The task list opens quickly and the pager is usable"

Reviewer seat: rung-5-panel:claude-code. Revision reviewed: f913267ca7e3978275ea88c63da72c9b7ca07cd9.
Live server: http://192.168.10.107:3000, Watchtower pid 3687239, started 2026-11-15T15:36:30Z, warm-up done;
`fw watchtower current` says the process is newer than every file under `web/`. All measurements below are mine,
2026-11-15 16:57–17:04 CET, host load average 14–27.

## Verdict: green

## What I did (the criterion's four steps, in a real browser: Playwright/Chromium, 1440 px)

| Step | Result | Time to "Showing …" visible |
|---|---|---|
| 1. open `/tasks?view=list` | 200 rows, "Showing 1–200 of 5129 (page 1 of 26)", no Previous link on page 1 | 1.8 s (2.1 s on a second run) |
| 2. scroll down, click "Next →" | `?view=list&page=2`, "Showing 201–400 of 5129 (page 2 of 26)", 200 rows | 1.9 s |
| 2. click "← Previous" | `?view=list&page=1`, "Showing 1–200 of 5129 (page 1 of 26)" | 1.5 s |
| 3. pick status "work-completed" in the toolbar | "Showing 1–200 of 4572 (page 1 of 23)"; every row's status is work-completed; List view stays active | 2.5 s |
| 3. click "Next →" | "Showing 201–400 of 4572 (page 2 of 23)"; URL and both pager links carry `status=work-completed`; rows all work-completed | 2.5 s |
| 3. pick "Sort by Name" (status still set) | back to page 1 of 23, first rows in name order, status filter still set in the toolbar | 2.2 s |
| 3. click "Next →", then "← Previous" | page 2 of 23 then page 1 of 23; URL and pager links carry `sort=name` and `status=work-completed`; rows still all work-completed and in name order | 3.0 s, 2.4 s |
| 3. fresh page, "Sort by Name" only, then "Next →" | page 2 of 26 with `sort=name` kept | 4.1 s (incl. the page open), 2.5 s |
| 4. open `/search` | "Browse by topic: 24 topics from 1415 tagged items", tag chips shown, Try-a-search and Saved Answers cards | 0.4 s |

No console errors, page errors or failed requests in any step. Raw data from my runs is in the tables above
(scripts were run from /tmp and are not kept in the repo).

Server-side timing (curl, 50 requests over 6 minutes): list 0.27–1.0 s, 864 KB per page (the task says 18.9 MB before);
filtered+sorted page 2: 0.27 s; `/search`: 0.03–0.5 s.

## One slow load, disclosed

My very first request to `/tasks?view=list` (curl, about 16:57:50) took **9.2 s**. Every one of the 50 later
requests and all browser loads were fast. Cause, as far as I could establish: the review-ledger files
(`.context/reviews/review-runs.jsonl`, `review-dispatches.jsonl`, `review-completions.jsonl`) were written at
16:57:43–46, when this review was dispatched. `web/shared.py::_readiness_stamp` keys the "awaiting review" cache
on those files, so the next list request re-verifies the verdict ledger (`board_awaiting_reason`,
`web/blueprints/tasks.py:831`). An ordinary commit at 17:01:03 did not cause it (the next load took 1.0 s).
The task's RCA names this cost ("19.2 s in board_awaiting_reason → verdict-ledger git calls … Not changed here").
I did not reproduce it a second time, because the only way is to write the ledger. I judge the criterion met: the
page the operator opens appears in about 2 s, and the pager, filter and sort behave as the criterion expects. The
operator should know that the first list load after a review is dispatched or a verdict recorded can take about 9 s.

## Screenshots read

Capturing browser's pages (all six read; no console errors reported for any):
- `01-tasks-view-list` — list view, top of page: toolbar, filters, table with 200 rows, count 5129.
- `02-search` — search box, mode chips, tag cloud (24 topics from 1415 tagged items), Try a search, Saved Answers.
- `03-cockpit-activity` — an unstyled list of recent commits. This is an htmx fragment, not a page; it is not part of the criterion.
- `04-fabric` — subsystem cards and the component table, complete.
- `05-fabric-graph` — the explorer graph renders.
- `06-tasks` — board view, five columns.

Task's Visual Verification checklist, judged at every width (the list shots are 13,000–17,000 px tall, so I read
the top 520 px and the bottom 420 px of each at full size):

| state | control | 1024 | 1440 | 1920 | what I saw |
|---|---|---|---|---|---|
| list | table, pager row | ok | ok | ok | Pager row under the table: "Showing 1–200 of 5125 (page 1 of 26)" left, "Next →" right, no Previous. At 1024 the table is wider than the window (1308 px in a 976 px `table-responsive` box with `overflow-x: auto`): Owner is cut at the edge and Arc/BVP/Tags are reached by scrolling the table sideways. The pager row is not inside that box and fits the window (Next ends at x=1000). I measured this in a live browser at 1024. |
| list-page2 | pager with Previous and Next | ok | ok | ok | "← Previous" left, "Showing 201–400 of 5125 (page 2 of 26)" centred, "Next →" right; nothing clipped or overlapping. |
| search | search box, tag cloud, try-a-search | ok | ok | ok | All three present and unclipped at each width; the tag cloud wraps to 3 / 2 / 2 lines. |
| fabric | subsystem overview | ok | ok | ok | 28 subsystem cards in three columns, filters and component table below. |

Not part of the checklist, seen at 1024 only: the top navigation wraps and the theme toggle drops to a second line.
The same wrap is on every page at that width, so it is not from this task.

My own shots from the walk: `reviewer-walk-pager-page1`, `reviewer-walk-pager-page2`, `reviewer-walk-status-pick`,
`reviewer-walk-sort-filter-page2` (pager row reads "← Previous · Showing 201–400 of 4572 (page 2 of 23) · Next →"
with status and sort both set), `reviewer-walk-search`.

## Small things noticed, not affecting the verdict

- With "Sort by Name", the first rows on page 1 are tasks whose name shows as `text: '…'`. That is the data in those
  task files, not the pager; I did not look into it further.
- The counts in the task's own evidence (5125) and mine (5129) differ because four tasks were created in between.
