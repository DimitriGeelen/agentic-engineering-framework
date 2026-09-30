You are continuing T-3580 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3580`. Follow CLAUDE.md. The sovereignty hold still applies: fixtures only, no real task judged, and no `.context/reviews/` in this repo.

The round-4 review is AMBER with no highs: .context/dispatch-results/t3580-r4-review-a47797acb493.md. Copy it to docs/reports/T-3580-round4-review.md and commit it. Fix, each with a test and a negative control:

1. MEDIUM, vendor honesty. The ledger must derive the vendor from the dispatch's registered worker_kind through ONE mapping (policy/review-backends.yaml is the source), never from free text passed to register-dispatch. The reviewer's control (three worker_kind=claude dispatches registered as "anthropic", "vendor-2" and "vendor-3") must NOT satisfy a three-vendor panel.
2. MEDIUM, the never-run dispatch. The secret must not outlive its purpose. Delete it when run.sh finishes signing; expire it (TTL) so a dispatch that never ran cannot be completed later; and require evidence that run.sh actually started for this dispatch (e.g. a runtime start record the dispatcher writes). A registered-but-never-run dispatch plus fake files plus `complete` must be refused at APPLY. Note in ## Decisions what remains inside the operator-accepted same-user boundary (T-3581).
3. LOW, `finalised` written early by a worker: make wait verify it (for example that it is written by run.sh after signing, and consistent with the completion record). A test is optional; state what you chose.
4. LOW, .context/dispatch-results/: decide between gitignored (durable on disk, not committed) and committed under the worker's own identity, and implement one consistently. Recommendation: gitignore it; the worker's commits carry its real output. Say which.
5. LOW, the completion record: bring it under the same git-history append-only check as the verdict ledger, or document precisely why not.

Rules:
- Stage by name only; commit messages start "T-3580: ".
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- Run all t3579, t3581 and t3580 suites and the bats files; report counts.
- Do not close; Live proof stays unticked.

Print only: commits, per item fixed or not (with the proving test), test counts.
