# T-5195 Human AC#1 — evidence report (judge-t-5195-r3-eb9b50f387dc)

Revision reviewed: f18f28b579f7352683494b8076c8eb3f31bc1fb7. Verdict: **green**.

Criterion: the approvals page loads in a few seconds, the refresh line is plain and
unobtrusive, and after the refresh the queue looks the same as before this change.

## What I checked

1. **Load time (live, 2026-11-17).** Two consecutive `curl` GETs of
   http://192.168.10.107:3000/approvals: HTTP 200 in 4.87 s and 3.67 s (1.5 MB each).
   The first was served while an entry was stale, so the stale path itself answered
   in under 5 s. The task records 21.8 s for the same situation before the change.
2. **The refresh line, as actually served.** The first response carried
   `<p class="approvals-refreshing"><small>1 entry is being refreshed; reload in a minute.</small></p>`.
   The second response, seconds later, did not: the background refresh had finished.
   None of the six supplied screenshots shows the line (nothing was stale when they
   were taken; the task's checklist says so). So I rendered it myself: Chromium loaded
   the live /approvals URL with the body of that first served response (live CSS and
   JS, the 10 s content poll blocked so it could not replace the line), at 1024, 1440
   and 1920. This is a replay of a real response, not a mock-up, but it is a replay.
   - `refresh-line-1024-judge-t-5195-r3-eb9b50f387dc.png`, `refresh-line-1440-judge-t-5195-r3-eb9b50f387dc.png`, `refresh-line-1920-judge-t-5195-r3-eb9b50f387dc.png`
   - At every width: one line of small body-colour text between the brake card and the
     summary tiles, 24 px tall, no box, no colour, no icon. Visible, unclipped, no
     overlap, no horizontal scroll (scrollWidth equals the viewport), no page errors.
   - The words are plain: a count, what is happening, what to do.
3. **Queue the same after the refresh.** With the refresh line removed, the stale
   response and the refreshed response have the same seven sections in the same order,
   the same summary counts (47 / 237 / 2 / 95 / 55 / 434), the same 14 headings and the
   same 588 task links in the same order. The task's template change from its first
   commit to the reviewed revision is one inserted line in
   `web/templates/_approvals_content.html` (the refresh line) and no CSS change, so
   the layout is otherwise what it was before.
4. **Supplied screenshots, control by control (Visual Verification checklist).**
   - `approvals-top@1024/1440/1920` (sha256 match the capture record): summary bar is
     six tiles in one row at every width, all text readable, none clipped or
     overlapping: ok / ok / ok. Refresh line: absent at all three, which is correct for
     a page with nothing stale; its rendered form is covered by item 2.
     At 1024 the theme toggle wraps under the nav; the task did not touch the nav.
   - `01-approvals`: styled page, title, brake card, summary tiles, Decisions list;
     no console errors recorded.
   - `02-approvals-content`: the unstyled fragment that the page polls; summary
     counts then Decisions, same grouping.
   - `03-approvals-continuous-state`: brake fragment only; not affected by this task.
5. **Tests.** `tests/unit/test_t5195_approvals_single_flight.py`: 8 passed (includes
   `test_approvals_context_reports_stale_count`).

## Limits

- I did not restart Watchtower or change a ledger to force a large refresh; I saw the
  line with a count of 1 only. The plural wording ("N entries are being refreshed") I
  read in the template and the test, not on a rendered page.
- "Same as before this change" is judged from the stale-versus-refreshed comparison and
  the one-line template diff, not from a screenshot taken before the change.
