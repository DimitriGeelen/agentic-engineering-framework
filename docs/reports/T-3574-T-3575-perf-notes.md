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
