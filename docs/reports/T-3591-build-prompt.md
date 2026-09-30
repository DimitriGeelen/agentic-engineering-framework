You are building T-3591 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3591` (session-scoped focus). Follow CLAUDE.md.

Spec: .tasks/active/T-3591-*.md (### Agent criteria). Background: docs/reports/T-3590-review.md GUIDANCE 3. T-3590 added the canonical predicate `is_ready_for_batch_completion` in web/shared.py; /tasks/<id> still decides `can_complete` with `_parse_acceptance_criteria` (web/blueprints/tasks.py ~865).

Another worker (T-3580) runs in parallel on lib/verdict_ledger.py, lib/reviewer/, agents/termlink/termlink.sh and tests/unit/t35{79,80,81}*. Do not touch those. Retry commits on index.lock.

Rules:
- Stage by name only; commit messages start "T-3591: ".
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- `bin/fw watchtower restart`, then `current`; `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- Do not click Complete on real tasks; use the Flask test client and fixtures.
- Tick criteria when proven EXCEPT the render review (the parent does it). Leave the task in started-work.

Print only: commits, per criterion met or not (with the proving test), and what live /tasks/T-2200 shows after restart.
