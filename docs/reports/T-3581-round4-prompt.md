You are continuing T-3581 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Focus is T-3581 (started-work); you own it while you run. Follow CLAUDE.md.

Round 3 is AMBER from both vendors with no high findings: docs/reports/T-3581-round3-review-openai.md and docs/reports/T-3581-round3-review-zai.md. Read both. Fix the remaining items that are fixable here, each with a test and a negative control:

From OpenAI:
1. `_row_fault` (lib/verdict_ledger.py:627) returns early for non-GREEN rows. Validate guidance (mandatory for non-green) and introducing-commit presence for EVERY outcome before that return.
2. Revalidation depends on a mutable Markdown annotation (:991). Removing or case-changing it makes a reviewer-derived tick look hand-ticked. Identify reviewer-derived ticks from durable application provenance (the applied log / ledger), not only from the annotation. Cross-check the two at close and in audit: an annotation mismatch refuses the close and fails the audit. Converting a reviewer tick into a manual approval requires an explicit operator action; say which.

From Z.ai (the lows):
3. Dispatch ids that normalise to fewer than 4 characters skip the worker-identity check. Remove that exemption, or require a minimum length.
4. The record-to-commit window: an uncommitted RED deleted from the working file must not reopen an earlier GREEN. Uncommitted rows for a criterion already block it (round 3); make sure deletion before commit is covered too.
5. Registration is first-row-wins with predictable ids. Refuse a second registration of the same id, and make generated ids unpredictable (random suffix).
6. Evidence is cited by path, not by content. Record a content hash per evidence file at record time and verify it at apply.

Out of scope here, and do NOT attempt: worker attribution and binding the verdict writer to the worker (T-3580 builds that), and the same-user signing-key boundary (the operator's Human criterion).

Rules:
- Stage by name only; commit messages start "T-3581: ".
- No --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- Run the full T-3579 and T-3581 test files plus the bats files.
- Do not close the task (the Human criterion stays open).

Print only: commits, per item closed or not, and test counts.
