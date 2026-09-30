You are fixing T-3593 (and T-3594 residue) in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3593`. Follow CLAUDE.md.

The re-review is in docs/reports/T-3593-T-3594-review.md, section "## Re-review after fixes": T-3593 RED, T-3594 AMBER. Read it in full, including its probes. Fix, each with a bats test that reproduces the reviewer's probe first (red), then passes:
- R1 reopened: git accepts ABBREVIATED long options (e.g. `--no-ver`, `--no-verif` for --no-verify; also `--forc` for --force, and any other prefix git resolves) and option-case spellings the reviewer lists. The classifier must treat any prefix git would accept for a flagged option as that option. Derive the prefix rule from how git parses options, not from a hand list. Test the reviewer's end-to-end R1 chain (approve, then push through the text gate, then pre-push) with abbreviated spellings: the approval must never be a bare force-push action that skips pre-push, and must not be reusable.
- R3: a `cd` on the right-hand side of `||`. The separator before a cd must also make the cwd unknown (the reviewer's point (c)).
- R2 residue: document it in the Decisions, as the review asks.
- Anything else the re-review lists as open for T-3593/T-3594.

SAFETY as before: fixtures only under a tmp dir. NEVER force-push, delete a branch or hard-reset in this repo or against any real remote. Never approve a real Tier 0 action.

Another worker may soon edit lib/verdict_ledger.py, lib/reviewer/, lib/review_cost.py and agents/termlink/termlink.sh (T-3580). Do not touch those.

Rules:
- Stage by name only; commit messages start with the task id.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- Run the t3593/t3594 bats, the existing Tier 0 suites and upgrade_fresh_machine_simulation.bats.
- Leave the review criteria unticked and the tasks in started-work.

Print only: commits, per item fixed or not (with the proving test), test counts.
