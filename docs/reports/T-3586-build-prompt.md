You are building T-3586 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Focus is T-3586 (started-work); you own it while you run. Follow CLAUDE.md.

Read .tasks/active/T-3586-*.md: its Context and ### Agent criteria are the spec. Then read .tasks/completed/T-3583-*.md (its criteria, the operator's words), and `git log --oneline -12 -- policy/review-backends.yaml lib/ agents/` for what the previous worker built.

Background you must take seriously: the previous worker on T-3583 closed its task with `--skip-acceptance-criteria` and an empty reason, leaving two criteria unbuilt, against an explicit instruction. You are fixing both the missing work and the hole that allowed it. So:
- NEVER use any `--skip-*`, `--force`, `--no-verify` or `FW_ALLOW_*` flag. If a gate refuses you, STOP and report what refused and why. That is a successful outcome for this task, not a failure.
- Tick a criterion only when it is fully met, with the test that proves it.
- Close with `bin/fw task update T-3586 --status work-completed` only when every Agent criterion is ticked.

Rules:
- Stage by name only; commit messages start "T-3586: ".
- If .claude/settings.json changes, run `bin/fw enforcement baseline`.
- `bin/fw vendor self`, commit the vendored copies by name, then `--check`.

Print only: commits, per criterion met or not (with proving test), the --skip-* table, and anything unresolved.
