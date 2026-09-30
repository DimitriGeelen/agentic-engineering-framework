# T-3574 / T-3575 perf notes (2026-09-30)

## T-3574 arc page
- Cause: `_bvp_coherence_for_arc` did an uncached `yaml.safe_load` over all ~3,590 task files (28s of 29s); `_arc_member_tasks` walked the whole corpus for ~28 members.
- Fix: `bvp._task_index()` (stat-signature cached membership + id->path map); members/coherence parse only the arc's files via the mtime-cached reader; libyaml CSafeLoader.
- Numbers: `_bvp_signals(continuous-run)` 28.7s -> 0.4s. Live /arcs/continuous-run cold/warm 25.8s/15.9s -> 1.04s/0.31s; /arcs/readme-first-run 2.74s/0.44s -> 0.28s/0.14s. `_bvp_signals` JSON for 4 arcs byte-identical.
- Files: web/blueprints/bvp.py, web/blueprints/arcs.py, tests/web/test_t3574_arc_page_perf.py (8 tests; legacy-vs-new equality on the live corpus).
- State: partial-complete (render-surface gate required a [REVIEW] Human AC).

## T-3575 tasks page
- Cause: 30s TTL cache (most visits cold, 3.35s) and a 1MB board (every captured/in-progress card, each with 4 inline forms).
- Fix: change-driven cache in web/shared.py (signature + per-file mtime caches, 300s safety TTL); board columns capped at 20 (+N more -> status-filtered list); whitespace-trimmed inline_select and tag dropdown.
- Numbers: cold 3.35s -> 0.18s; bytes 1,044,881 -> 304,676; browser warm DCL 1081-1576ms -> 527-592ms; first-load DCL 5521 -> 851ms.
- Files: web/shared.py, web/blueprints/tasks.py, web/templates/tasks.html, web/templates/_partials/inline_select.html, tests/web/test_t3575_tasks_page_perf.py (5 tests).
- Unresolved: warm DCL still ~530-590ms (target <500) on a loaded host; /tasks?view=list is still 13MB; independent render review pending (parent).

## Round 2 (after the independent review, docs/reports/T-3574-T-3575-render-review.md)

Measured 2026-09-30 05:41-05:51, load average 2.9-4.3 on 24 cores (round 1 was at 20-28).

### T-3577 (new): arc_id with a trailing `# comment`
- `_ARC_ID_LINE_RE` kept the comment in the value, so `.tasks/completed/T-3440` (`arc_id: arc-001   # T-3440: ...`) was filed under a junk key and missing from arc-001 (dispatch-safety) everywhere built on `scan_tasks_by_arc_membership`. Registered as G-107.
- Fix: one shared `parse_arc_id_value` (lib/arc_membership.py); lib/arc.sh (2 inline parsers), the shell awk in lib/arc_membership.sh and agents/context/check-arc-id.py got the same rule.
- Membership before/after (whole corpus): 23 arcs / 481 entries both sides; exactly one task changes: T-3440 moves from the junk key to `arc-001` (0 -> 1; junk key 1 -> 0). It is the only task file with a trailing comment on `arc_id`.

### T-3574 arc page
- Coherence equivalence test is now real (score injection into both paths, every arc on disk). Control: it fails on dispatch-safety (11 vs 12) with the old parser and passes with the fix.
- Warm criterion, curl, after restart: continuous-run cold 0.99s, warm 0.40-0.46s (was 1.65-1.83s after T-3575 landed); readme-first-run cold 0.19s / warm 0.18-0.22s; dispatch-safety cold 0.29s / warm 0.19-0.24s.
- Verification commands moved out of the template comment into `## Verification`.

### T-3575 tasks page
- Board: newest-first (last_update, then descending id) before capping; only Captured and Completed are capped (20 / 10); In Progress (47) and Issues are never capped. Test: most recent started-work task is on the default board.
- `_task_files_signature()` memoised in flask.g for GET/HEAD requests: the arc page paid it 53x (1.5s).
- "+N more" keeps owner, horizon, tag, q, type, component, arc, sort.
- Getting warm DOMContentLoaded under 500ms with 27 more cards needed lighter cards (target kept at 500ms): board selects render one `<option>` and fill the rest on first mousedown/focus, have no `<form>` wrapper or hidden CSRF input (csrf-htmx.js sends the header), and post through one delegated `htmx.ajax` listener (htmx load-time processing was 44ms); cards use `content-visibility: auto`. List view unchanged.
- Numbers: /tasks 419KB with the uncapped column and the old card markup, 294KB after; curl warm 0.17-0.24s; browser DOMContentLoaded from about:blank, 14 warm runs, median 454ms (range 431-545, first load 582), load 4.2. Earlier same-session batches at load 3-7 gave medians 472, 477, 493 (36 runs) before the last trims.
- Visible changes: board meta selects size to their value (text no longer clipped); a task with no owner/type/horizon shows a blank select instead of the first option. Render-review criterion left unticked.
- Tests: tests/web/test_t3575_tasks_page_perf.py (8), tests/playwright/test_tasks_board_lazy_selects.py (2); existing tasks/kanban-drag/inline Playwright suites (25) pass.

