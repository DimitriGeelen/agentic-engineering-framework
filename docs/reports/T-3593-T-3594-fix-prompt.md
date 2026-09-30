You are fixing T-3593 then T-3594 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Session-scoped focus: `bin/fw work-on T-3593`, later `bin/fw work-on T-3594`. Follow CLAUDE.md.

The independent review is docs/reports/T-3593-T-3594-review.md: T-3593 RED, T-3594 AMBER. Read it in full, including the reproduction probes. Fix every "fix before close" item, each with a bats test that reproduces the reviewer's probe first (red), then passes:
- T-3593 R1 (serious): a flagged segment counts as explained only if EVERY Tier 0 pattern matching it is covered by the action verb. `--no-verify` (and any other flagged option inside a push, reset or branch segment) raises Unmappable, so the command falls back to the exact-text path and the operator sees the whole command. Test: approving `git push -f --no-verify origin main` must NOT produce a bare force-push action approval, and the approval cannot be reused.
- T-3593 R2: the human check lives in the module. `approve-pending` refuses under CLAUDECODE=1 unless given a recorded override flag; the record's `approved_by` is carried into the bypass log, never hard-coded "human".
- T-3593 R3: `cd` carries over only across `&&`. After `;`, `||`, `|`, `&` or a newline, cwd becomes unknown, so relative targets are unmapped.
- T-3593 R4: put the resolved target commit into the hard-reset key and description (or state the gap in the description).
- T-3594 A1: a tag moved by force (a non-fast-forward tag update) is refused without approval. Test it.
- T-3594 A2: correct the limit wording in the hook, the block message, CLAUDE.md and FRAMEWORK.md. Add text-gate patterns for `git -c/-C … push` with force, `+` or delete, and for `core.hooksPath`.
- T-3594 A3/A4: register them in .context/concerns.yaml as follow-ups (read the review for the exact wording).

SAFETY, as before: fixtures only under a tmp dir. NEVER force-push, delete a branch or hard-reset in this repo or against any real remote. Never approve a real Tier 0 action.

Another worker (T-3580) edits lib/verdict_ledger.py, lib/reviewer/, agents/termlink/termlink.sh and tests/unit/t35{79,80,81}*. Do not touch those. Retry commits on index.lock.

Rules:
- Stage by name only; commit messages start with the task id.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- Run both bats files, the existing Tier 0 suites and upgrade_fresh_machine_simulation.bats.
- Leave the review criteria unticked and both tasks in started-work.

Print only: commits, per item fixed or not (with the proving test), test counts.
