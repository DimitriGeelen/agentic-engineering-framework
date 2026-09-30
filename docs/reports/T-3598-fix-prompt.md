You are fixing T-3598 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3598` first, then read the task file (Context, Acceptance Criteria, RCA) and follow CLAUDE.md.

The bug: `agents/context/budget-gate.sh` keeps one project-wide cache, `.context/working/.budget-status`. Every Claude process in the project (the parent session and every TermLink worker) writes that file from its own transcript. The fast path (about lines 248-295) acts on any cache under 90s old without checking who wrote it. So a parent at `critical` blocks every worker, and a worker's low count can be read as the parent's budget (a false `tokens: 0`). Hook stdin carries `session_id` and `transcript_path`, so identity is available.

Deliver:
1. First, a bats file `tests/unit/t3598_budget_cache_session_keyed.bats` that reproduces both symptoms and is red on the current code. Use fixtures only, under a tmp PROJECT_ROOT, with a synthetic transcript and a synthetic cache written by a "foreign" session_id:
   - (a) a foreign `critical` cache must not block a Bash call from a session whose own transcript is small;
   - (b) a foreign `ok` / `tokens:0` cache must not be reported by `agents/context/checkpoint.sh budget` as the caller's budget.
   Add controls: a same-session `critical` cache still blocks, and a same-session `ok` cache still takes the fast path.
2. The fix: the cache is keyed by session identity, either one file per session or an identity field that is checked. Pick the smaller and more robust design and record the choice in the task's `## Decisions`. Keep the files that other code reads working: grep for `.budget-status` readers (checkpoint.sh, handover, auto-restart signal, Watchtower, lib/*) and update each one or keep it compatible. List every reader you checked in the Decisions.
3. `bin/fw vendor self`, commit the vendored copies of YOUR files by name, then `bin/fw vendor self --check`.
4. Run the new bats, every existing bats whose name matches budget|checkpoint|context_tokens, and tests/unit/upgrade_fresh_machine_simulation.bats.
5. Tick the Agent criteria only as each one is proven. Do NOT close the task; leave it in started-work.

Another worker is concurrently editing lib/tier0_action.py, agents/context/check-tier0.sh, agents/git/lib/hooks.sh and the t3593/t3594 bats (T-3593). Do not touch those files. When you run `fw vendor self`, stage only the vendored copies of the files you changed.

Rules:
- Stage by name only, never `git add -A` or `-u`. Commit messages start with `T-3598:`.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* flags. If a gate blocks you, stop and report which one and why.
- Run `bin/fw context focus` as its own call, never chained.

Print only: commits, per criterion done or not (with the proving test), test counts, and the design chosen in one line.
