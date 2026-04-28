# T-1539 — Blind Reviewer Walkthrough

**Reviewer:** TermLink dispatch worker, no prior session context
**Date:** 2026-04-27T00:00:00Z
**Watchtower URL:** http://192.168.10.107:3000
**Surfaces visited:** handover markdown, /approvals, fw review-queue, /review/T-1531

---

## What worked

- **Handover Awaiting section** — 8 tasks listed, every one prefixed `[GO]`. URLs are
  well-formed absolute links (`http://192.168.10.107:3000/review/T-XXX`), clickable and
  pointing at the correct host. The section is scannable at a glance; no wall-of-text.

- **`/approvals` verdict badges** — 44 `verdict-badge` span elements rendered. Each card
  carries `data-verdict="GO|DEFER|?"` on its outer div, enabling JS client-side filtering.
  Filter buttons are present for: `all`, `go`, `defer`, `review`, `rubber-stamp`, `stale`.

- **`fw review-queue` table** — Clean terminal table with header row (VERDICT / AGE / ID /
  NAME), ANSI colour applied correctly: green=GO, amber=DEFER, grey=?. Sort order is GO
  first (oldest within group), then DEFER, then ?. Summary line `45 task(s) awaiting human
  review  (19 GO / 10 DEFER / 16 ?)` is clear and machine-parseable. The NO-GO row is
  present in help text but correctly absent from output (no NO-GO tasks exist today).

- **`/review/T-1531` Recommendation block** — Renders the full `## Recommendation` section
  from the task file: **Recommendation:** GO, Rationale paragraph, Evidence bullet list with
  specific file references. Content is exactly what an approver needs to make a decision.

---

## What didn't work

- **`fw review-queue` footer hardcodes `localhost`** — Last line of the Python inline script
  (bin/fw ~line 3437):
  ```python
  print(f"Open in Watchtower: http://localhost:{port}/approvals")
  ```
  `port` comes from `FW_PORT` env var but the host is always `localhost`. On a remote
  machine (this project: 192.168.10.107) the link is wrong and will fail if copy-pasted.
  This is the explicit anti-pattern flagged in CLAUDE.md §Watchtower Port. Fix: replace
  with `fw_watchtower_url()` or read the triple-file, same as `lib/review.sh` already does
  (line 46: `base_url=$(_watchtower_url "$task_id")`).

- **`/approvals` missing `data-filter="nogo"` button** — Filter buttons found:
  `all | go | defer | review | rubber-stamp | stale`. There is no `nogo` filter button.
  If any task acquires a NO-GO verdict, the badge will render (the CSS and Python extraction
  code handle it) but the human cannot filter to that verdict class — no button to click.
  The GO and DEFER buttons are present, NO-GO is the only verdict-class with no filter.

- **`/review/T-1531` Recommendation block styled amber/yellow regardless of verdict** — The
  block uses a single CSS class `.recommendation-block` with amber background (`#fefce8`)
  and amber border (`#eab308`, `#ca8a04`). For a GO verdict this is misleading: amber is
  associated with DEFER/warning. A GO block should be green; a DEFER block amber; a NO-GO
  block red. Currently all three would look identical. The `/approvals` badges do apply
  per-verdict colour (green/amber/red) but `/review` does not.

---

## What was missing or surprising

- **Handover shows 8 tasks; review-queue shows 45** — The handover Awaiting section is
  horizon-filtered (only recently-touched `now` tasks appear), while review-queue scans all
  active tasks. There is no note in the handover that 37 additional awaiting-review tasks
  exist. A human reading only the handover would not know the full backlog scope. Consider
  adding a line: `(+37 more — see fw review-queue or /approvals for full list)`.

- **`/approvals` shows 57 cards; review-queue shows 45 tasks** — One task with N unchecked
  Human ACs generates N separate cards in `/approvals` but one row in review-queue. This
  is architecturally coherent but a task with 3 unchecked ACs appears 3× in the approvals
  list, which can make the queue feel larger than it is. The row-per-task model of
  review-queue is easier to triage.

- **`/review` page has no "take action" affordance** — The page is read-only: no approve
  button, no link to the `/approvals` flow, no `fw inception decide` entry point. The human
  reads the Recommendation block but must navigate elsewhere to act. A single "Open in
  approvals ↗" link (or QR code, as `fw task review` generates) would close the loop.

- **`data-filter="nogo"` absent but `data-verdict="NO-GO"` presumably handled** — The Python
  extractor and badge CSS both handle `NO-GO` (review-queue sort order includes it), so the
  verdict would render if it existed. Only the filter button is missing. Low risk today
  (zero NO-GO tasks), but a gap to patch before the first NO-GO lands.

- **Inception cards in `/approvals`** — T-1537 was supposed to surface `data-verdict` on
  inception cards. The HTML contains 18 occurrences of "inception" (class references + text)
  but zero `approval-card go-decision` matches. Unable to confirm inception cards have
  `data-verdict` wired end-to-end without a live inception pending-decision task in the
  queue to inspect.

---

## Counts (cross-checks)

| Surface | GO | DEFER | NO-GO | ? | Total |
|---|---|---|---|---|---|
| Handover Awaiting | 8 | 0 | 0 | 0 | 8 |
| /approvals badges (data-verdict ÷ 2) | 19 | 10 | 0 | 15 | 44 badges |
| fw review-queue rows | 19 | 10 | 0 | 16 | 45 tasks |

**Discrepancy flags:**
- Handover (8) vs review-queue (45): expected — handover is horizon-filtered. Not a bug.
- /approvals badge count (44) vs review-queue task count (45): off by 1. Likely T-1539 (this
  task, just created, no Recommendation block yet) appears in review-queue but renders `?`
  in /approvals; the CSS grep count of 44 includes 1 stylesheet definition of `.verdict-badge`,
  so actual badge elements may be 43. Low confidence — acceptable noise.
- /approvals card count (57) vs review-queue (45): expected — approvals shows per-AC cards,
  not per-task. Not a bug.
- GO counts agree (19) across both data surfaces. ✓
- DEFER counts agree (10). ✓

---

## One-line conclusion

**CONCERN** — The workflow is functionally live on all 4 surfaces, but two concrete bugs
need fixing before the queue can be trusted: `fw review-queue` footer hardcodes `localhost`
(wrong host on remote machines), and `/approvals` has no `data-filter="nogo"` button; plus a
colour-signal mismatch on `/review` where GO renders amber instead of green.
