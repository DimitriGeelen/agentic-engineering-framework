You are fixing T-3627 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3627` alone on its line first. Then read the task file (Context, Agent ACs) and the py-spy dump docs/reports/T-wt-hang-2026-10-01-pyspy.txt. Follow CLAUDE.md, including the web-touching rule (`bin/fw watchtower restart`, then `bin/fw watchtower current`).

What happened on 2026-10-01: the operator could not reach Watchtower. 59 of 91 threads were stuck in `web/blueprints/discovery.py:_build_application_index` (the /graduation view), which reads every task and episodic file on every request with no cache. 83 connections sat in CLOSE-WAIT, and even static files timed out. A restart restored service, but it also truncated watchtower.log, which destroyed the evidence of who made the ~60 concurrent requests.

Do the ACs in order, tests first:
1. Cache the index on the corpus signature. Reuse `web/shared.py` `_task_files_signature` and the shared task cache from T-3590/T-3600; do not invent a new one. Episodic files need their own signature component.
2. Profile the routes that `tests/playwright/test_response_times.py` and `test_all_routes_height.py` sweep, using `app.test_client()` in-process, NOT the live server. List the uncached whole-corpus readers in Decisions. Fix the ones as bad as /graduation, and file one follow-up task for the rest.
3. Bound heavy concurrent work: a single build lock per cache, so concurrent misses wait for one build, and/or an in-flight limit with 503 + Retry-After. Test it in-process with threads, not against the live server.
4. Make restart rotate the log instead of truncating it.
5. Look for the caller: do any playwright tests or monitors target the LIVE operator Watchtower URL (`bin/fw watchtower url`, port 3002) rather than a fixture server? If so, point them at their own server, as T-3604 noted for port 3099.

SAFETY: never load-test the live operator Watchtower. All concurrency tests run in-process or on a fixture server on a free port. Restart the live server only once, at the end, for `bin/fw watchtower current`.

Other workers are running concurrently:
- T-3593: lib/tier0_action.py, check-tier0.sh, hooks.sh;
- T-3580: lib/verdict_ledger.py, lib/reviewer/, agents/termlink/termlink.sh;
- T-3623 and T-3624: tests/unit triage.
Do not touch their files.

COMMIT WITH AN EXPLICIT PATHSPEC: `git commit -m "..." -- <paths>`. All workers share one git index. With `bin/fw vendor self`, use `FW_VENDOR_ONLY`, and commit only your vendored copies. Never write a bare `! cmd` that is not the last statement of a bats block.

Rules:
- Commit messages start with `T-3627:`.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* / FW_VENDOR_ALL flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` and `bin/fw work-on` alone on their line.
- Run everything in the FOREGROUND. Never background a command and end your turn.
- Tick Agent ACs as each one is proven. Do not close the task: P-013 needs a render criterion, and the parent adds it.

Print only: commits, per AC done or not (with the proof), cold and warm timings, the other heavy routes found, and the caller if identified.
