You are building ONE task in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Your task id is given at the end. Run `bin/fw work-on <TASK>` (session-scoped focus). Follow CLAUDE.md.

Read `.tasks/active/<TASK>-*.md`: its Context and ### Agent criteria are the spec. Tick a criterion only when it is proven by a test or a command you ran, and name the proof.

Other workers run in parallel in the same checkout: T-3580 (lib/verdict_ledger.py, lib/reviewer/, agents/termlink/termlink.sh, tests/unit/t35{79,80,81}*), plus the other two of T-3584 (policy/designer-pin.yaml, vendor/designer/, web/blueprints/designer*), T-3585 (lib/release.sh and config registries) and T-3569 (agents/audit/*-task-scan.py, lib/research_preserved.py). Touch ONLY your own task's files; if you must edit a shared file (the config registries, CLAUDE.md), make a minimal append and retry on conflict. Retry commits on git index.lock.

Rules:
- Stage by name only; commit messages start "<TASK>: ".
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* flags. If a gate refuses, stop and report what refused and why.
- After web/ edits: `bin/fw watchtower restart`, then `current`. Always finish with `bin/fw vendor self`, commit the vendored copies by name, then `--check`. If `--check` fails only because ANOTHER worker has uncommitted files, say so and do not try to fix their files.
- If your task has a render-review criterion, leave it unticked and the task in started-work. Otherwise close with `bin/fw task update <TASK> --status work-completed` when every criterion is ticked. If the close is blocked only by another worker's vendor drift, leave it and report.

Print only: commits, per criterion met or not (with the proof), and anything unresolved.
