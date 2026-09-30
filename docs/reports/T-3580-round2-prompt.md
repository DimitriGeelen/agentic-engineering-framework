You are continuing T-3580 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Focus is T-3580 (started-work); you own it while you run. Follow CLAUDE.md.

The independent OpenAI review of slice 3 is RED: docs/reports/T-3580-code-review-openai.md. Read it in full, together with docs/reports/T-3580-build-prompt.md (the sovereignty hold still applies: fixtures and fake dispatchers only, no real task, and no `.context/reviews/` in this repo) and the SIX worker-attribution requirements in T-3580's Context.

The principle behind all three high findings: **the LEDGER enforces, not the judge CLI.** Anything the judge promises must be refused by `lib/verdict_ledger.py`'s shared validator (`_row_fault` / `satisfying_verdict` / `apply` / `check-render` / `audit`), or it does not exist.

1. HIGH, worker attribution. Implement the six requirements as a signed worker completion. The worker records, and the ledger verifies:
   - a fresh worker session identity;
   - the reviewed revision (commit sha);
   - the criterion digest;
   - the evidence hashes;
   - the exact verdict contents hash;
   - that the row's introducing commit is by exactly that worker identity.
   Verify all of it in `record` AND in `_row_fault`. Negative control per binding.
2. HIGH, unseen pages. Persist, in dispatch provenance, the required pages per render criterion and the capture result per page, preserving partial failures (judge_cli.py:303 currently discards them). The shared validator rejects a render green unless every required page has verified screenshot evidence. The negative control goes through apply and check-render, not the display.
3. HIGH, panels. Bind rows to a review run with its required seats. `satisfying_verdict` accepts only when every required seat has a valid completed green. Negative control: seat 1 green plus seat 2 missing leaves the criterion open through apply.
4. MEDIUM, IW-7 medium tier. Implement the low/medium/high mapping from docs/reports/T-3557-agent-reviewer-default.md §IW-7, using reversibility, components/consumer paths, audience, value and uncertainty; record the inputs and the reason.
5. MEDIUM, single-vendor honesty. Until T-3582 builds real codex/opencode seats, a rung-5 run is reported as "degraded: single-vendor panel", and its rows cannot satisfy a requirement that demands three vendors. Either downgrade the requirement visibly, or leave the criterion open; choose one and document it.
6. MEDIUM, validate every outcome before reporting; invalid rows map to unknown.
7. MEDIUM, tests. Ledger-level negative controls for each item above. Assert real dispatcher vendor arguments. FakeWorker must produce a signed completion; a row without one must fail.

Rules:
- Stage by name only; commit messages start "T-3580: ".
- No --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- Untick any Agent criterion that the review shows was not really met, and re-tick it only when it is.
- Do not close the task. Live proof stays unticked.

Print only: commits, per finding closed or not (with the proving test), test counts.
