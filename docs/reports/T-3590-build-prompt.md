You are building T-3590 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3590` (session-scoped focus). Follow CLAUDE.md.

URGENT and safety-relevant: the live /approvals page offers a "Complete 2 Ready Tasks" button that would close two tasks that are NOT ready (T-2200, T-2202). Read .tasks/active/T-3590-*.md (the spec) and docs/reports/T-3586-T-3587-review.md part A (the evidence and root cause).

Code: web/blueprints/approvals.py (_load_pending_human_acs, the ready_count computation, complete_batch around line 955, the batch form in web/templates/_approvals_content.html), web/blueprints/tasks.py (_parse_acceptance_criteria), and the canonical counters (needs_human_review / count_unchecked_human_acs; grep for T-3139).

DO NOT click or POST the live batch-complete endpoint against real tasks. Test with the Flask test client and fixture tasks only. Do not modify T-2200 or T-2202.

Rules:
- Stage by name only; commit messages start "T-3590: ".
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- `bin/fw watchtower restart`, then `current`; `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- Tick each criterion when proven, EXCEPT the last (render review, done by the parent). Leave the task in started-work.

Print only: commits, per criterion met or not (with the proving test), what live /approvals shows after restart.
