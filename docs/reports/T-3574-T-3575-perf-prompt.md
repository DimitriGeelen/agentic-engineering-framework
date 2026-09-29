You are fixing two Watchtower performance bugs, IN SEQUENCE, in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Follow CLAUDE.md. You own the repo's task focus while you run: set it with `bin/fw work-on T-XXXX` for each task.

## Task 1: T-3574 (arc page 12-108s)
Read .tasks/active/T-3574-*.md: its Context has the cProfile baseline, and its ### Agent criteria are your spec. `bin/fw work-on T-3574` (already started). Profile first (cProfile around the Flask test client GET /arcs/continuous-run), fix the dominant cost (per-request re-parsing of ~3,600 task frontmatters in web/blueprints/bvp.py / arcs.py `_bvp_signals`, `_arc_member_tasks`, `_bvp_coherence_for_arc`), profile again. Prior art: L-002 (learnings.yaml), web/shared.py caches (`get_all_task_metadata`, `mtime_cached_get`). You may READ web/shared.py and call its helpers, but do NOT edit web/shared.py in task 1; task 2 owns it. BVP numbers must not change: write the before/after equality test named in the criteria. Record before/after timings in the task file. Close it with `bin/fw task update T-3574 --status work-completed` only if every Agent criterion is met (it has no render change, so no render review is needed).

## Task 2: T-3575 (tasks page)
Then `bin/fw work-on T-3575`. Spec: its ### Agent criteria. Measure first (curl cold/warm, bytes; browser DOMContentLoaded via Playwright or a navigation-timing script), change the cache invalidation in web/shared.py to be change-driven, cut the default /tasks payload without removing any existing filter/search/view, measure again, record the numbers in the task. Tick every Agent criterion you meet EXCEPT the last (independent render review); leave T-3575 in started-work for the parent session.

## Rules for both
- One bug, one task: commit messages start with the task id ("T-3574: ..." / "T-3575: ..."). Stage files BY NAME only; never `git add -A`/`-u`.
- No --no-verify, --force, FW_ALLOW_*, --skip-* flags.
- After web/ edits: `bin/fw watchtower restart`, `bin/fw watchtower current`; `bin/fw vendor self`, then commit the vendored copies (.agentic-framework/...) by name, and `bin/fw vendor self --check`.
- If the Playwright fixture refuses port 3099 (held by a non-Watchtower process), use FW_TEST_PORT=3197.
- Write a short summary to docs/reports/T-3574-T-3575-perf-notes.md (before/after numbers per task, files changed, tests) and commit it.

When done print only: per task, the before/after numbers and commit ids, and anything unresolved.
