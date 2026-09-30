You are building T-3595 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3595`. Follow CLAUDE.md.

Spec: .tasks/active/T-3595-*.md (### Agent criteria; the first is already done: the test is sandboxed). Code: agents/termlink/termlink.sh cmd_cleanup (~line 441-566) and DISPATCH_DIR (line ~33). Round 4 of T-3580 just changed this file (durable results, per-dispatch secret); read `git log -3 -- agents/termlink/termlink.sh` first and keep its behaviour.

CRITICAL SAFETY: this code decides what gets deleted under /tmp/tl-dispatch, where LIVE workers keep their state, including yourself and another worker (t3593-94-fix) running right now. In ALL tests, point DISPATCH_DIR (via the new env override) at a sandbox tmp dir. Never run cleanup against the real /tmp/tl-dispatch. Never kill real processes; use fake worker processes you spawn yourself in the sandbox (e.g. `sleep` under a renamed parent), and kill only those.

Rules:
- Stage by name only; commit messages start "T-3595: ".
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- Run tests/unit/termlink.bats, tests/unit/t3440_close_state.bats and the T-3580 round-4 tests that touch termlink.sh.
- Close with `bin/fw task update T-3595 --status work-completed` when every criterion is proven. If the close is blocked only by another worker's vendor drift, leave it and report.

Print only: commits, per criterion met or not (with the proving test).
