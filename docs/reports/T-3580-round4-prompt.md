You are continuing T-3580 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3580`. Follow CLAUDE.md. The sovereignty hold still applies: fixtures and fake dispatchers only, no real task judged, and no `.context/reviews/` in this repo.

Round 3 reviews: OpenAI RED (/tmp/claude-0/-opt-999-Agentic-Engineering-Framework/087d333f-7dd9-4211-90d2-8dfe791ceb11/scratchpad/t3580r3-codex.md; copy it to docs/reports/T-3580-round3-review-openai.md and commit it) and Z.ai GREEN with lows (…/scratchpad/t3580r3-zai.md; copy it to docs/reports/T-3580-round3-review-zai.md). The parent read the code: OpenAI's finding 1 is real. Fix:

1. HIGH, `complete` (lib/verdict_ledger.py ~438) is a public command. Any caller with a caller-written exit_code file can get a signed completion without the key. Make completion require a per-dispatch runtime secret:
   - generated at dispatch, held only by run.sh (mode 0600 in the wdir, or process-local), and NEVER exported into the worker's environment;
   - `complete` refuses without it.
   Negative control: a registered dispatch that never ran, with fake exit/result files and a `complete` call without the secret, is refused, and apply refuses.
   State the residual honestly in Decisions: a same-user process that reads the wdir can still act. That is inside the boundary the operator accepted on T-3581.
2. HIGH, panel diversity counts backend ids. Register the actual vendor/worker-kind with dispatch provenance, and count distinct VERIFIED vendors in the ledger. Negative control: three registry aliases for the same worker kind must not satisfy a three-vendor panel.
3. MEDIUM, race: `wait` returns on exit_code before completion signing. Publish a runtime-finalised marker after signing succeeds or fails, and make review waits require it. Test through the real wait-and-collect path, with delayed signing.
4. Z.ai lows: address them or record why not.
5. Also: worker results must be durable. On exit, run.sh copies result.md into the repo (e.g. `.context/dispatch-results/<name>.md`), because a /tmp/tl-dispatch wdir vanished today before its result was collected. Keep it minimal, and only if it fits without widening scope; otherwise file it as a separate task.

Rules:
- Stage by name only; commit messages start "T-3580: ".
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- Run the full t3579, t3581 and t3580 suites and the bats files, and report counts.
- Do not close; Live proof stays unticked.

Print only: commits, per finding closed or not (with the proving test), test counts.
