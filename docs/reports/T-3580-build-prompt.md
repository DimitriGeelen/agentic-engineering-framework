You are building T-3580 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). It is slice 3 of T-3557 (GO 2026-09-30). Focus is T-3580 (started-work); you own it while you run. Follow CLAUDE.md.

Read first:
- .tasks/active/T-3580-*.md: its Context holds SIX worker-attribution requirements added by T-3581; the ### Agent criteria are the spec.
- .tasks/active/T-3581-*.md: its ## Decisions and ## Recommendation.
- lib/verdict_ledger.py: `record`, `register-dispatch`, the provenance and history checks. You must write rows that pass them, never loosen them.
- The proven reviewer brief: docs/reports/T-3557-spike-prompt.md, with its answer key and verdicts. Reuse its shape.
- IW-7: docs/reports/T-3557-agent-reviewer-default.md §IW-7.
- The dispatch wrapper: agents/termlink/termlink.sh (review dispatch naming, the random suffix from round 4).

Build `fw reviewer judge T-XXX [--criterion N] [--dry-run]` per the criteria. Non-negotiables:
- The reviewer WORKER writes and commits its own verdict row, under its own identity, with its own dispatch id (T-3581 requirements). The parent that runs `judge` never writes a verdict.
- Hard human classes (tier0, act-in-the-world, sovereignty) are never dispatched.
- Render criteria get screenshots. If capture fails, the reviewer is told, and it must not return green on an unseen page.
- Malformed reviewer output becomes `unknown`, never green.
- The rung follows IW-7. The weekly spend ceiling is a config key in BOTH registries, and dropping a rung is stated in the verdict.

**IMPORTANT, a sovereignty hold:** the operator has NOT yet accepted T-3581's residual-risk question. Until they do, the verdict path must not close any real task. So:
- Test with fake dispatchers and fixture repos (tmp git repos) only.
- Do NOT run `fw reviewer judge` against a real task in this repo.
- Do NOT create `.context/reviews/` here.
- Leave the "Live proof" criterion UNTICKED and say it waits on T-3581's Human criterion.

Rules:
- Stage by name only; commit messages start "T-3580: ".
- No --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- Config keys go into lib/config.sh AND web/blueprints/config.py; run tests/lint/config-registry-parity.bats.
- `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- Tick the Agent criteria you meet. Do not close the task.

Print only: commits, per criterion met or not, test counts, anything unresolved.
