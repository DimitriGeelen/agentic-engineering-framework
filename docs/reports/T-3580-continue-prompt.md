You are CONTINUING T-3580 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Focus is T-3580 (started-work); you own it while you run.

Read docs/reports/T-3580-build-prompt.md first. It is still the full brief and all its constraints hold, including the SOVEREIGNTY HOLD: fixtures and fake dispatchers only, and no real task judged. A previous worker built a skeleton (commits 40dfb3a8c, 590b9c56b, d06cb846e): CLI structure, rung calculation, brief generation, dry-run, and config keys. It left the core unbuilt, and it ticked nothing. Read its code before adding to it.

Finish these, each with tests and negative controls:
1. Real dispatch. `judge` dispatches the reviewer via `bin/fw termlink dispatch --task-type review`, registered with the ledger (`register-dispatch`), with a unique name (round-4 random suffix). Inject the dispatcher so tests use a fake.
2. The reviewer worker's side. The brief instructs the worker to compute the criterion digest (`fw reviewer verdict digest`), and to write AND commit its own verdict row via `fw reviewer verdict record --dispatch-id <its id>` under its own identity, with evidence and hashes. The parent never writes a verdict. Test end to end in a tmp git repo with a fake worker that runs the real `record`, and prove the resulting row passes `apply` and `audit`. Negative control: a row written by the parent identity is refused.
3. Screenshots for render criteria. Capture with Playwright (python playwright or the tests/playwright fixtures) of the pages the task touched (derive them from the changed web/ templates and blueprints, or from criterion text), and pass the paths as evidence. On capture failure, the brief says so explicitly, and a test proves such a brief forbids green.
4. Output parsing. The reviewer's printed verdict is parsed only for reporting. The authoritative record is the ledger row. A missing or malformed row counts as `unknown`, never green.
5. Hard human classes. tier0, act-in-the-world and sovereignty (from lib/delegation.py) are never dispatched and are reported as operator-only. Test with a mixed task.
6. The spend ceiling actually drops the rung and states it in the brief and the record.

Tick each Agent criterion only when fully met. Leave "Live proof" unticked (it waits on T-3581's Human criterion).

Rules:
- Stage by name only; commit messages start "T-3580: ".
- No --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- Do not close the task.

Print only: commits, per criterion met or not (with the test that proves it), test counts, anything unresolved.
