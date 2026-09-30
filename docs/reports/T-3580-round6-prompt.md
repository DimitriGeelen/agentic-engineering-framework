You are doing round 6 of T-3580 (slice 3 of T-3557, `fw reviewer judge`) in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3580` first. Then read the task file, CLAUDE.md §Delegation (the verdict-ledger paragraph) and the design in docs/reports/T-3557-*IW-7* (the impact-risk model).

Round 5 got a GREEN from the same-family (Claude) review. The second-family review (codex, a different model family) came back RED: docs/reports/T-3580-second-family-codex.md. Read it in full. Fix every finding, each with a test that reproduces it first (red), then passes:

1. HIGH (lib/verdict_ledger.py ~1271): the ledger never enforces the task's required IW-7 rung. A review dispatch can record a green with a lower `--rung` and no `--run-id`, and apply ticks it on a task that needs a panel.
   - Compute the required strength in ONE shared policy function (the same code `judge` uses) and enforce it at both record and apply.
   - Bind every review dispatch to its authorised run BEFORE launch.
   - A reduction (the spend-ceiling step-down) is allowed only through a validated, recorded ceiling decision.
   - Add the negative control the review names: an unbound, lower-rung review of a high-impact task must not tick.
2. MEDIUM (~511): a signed start does not prove that a reviewer ran; the caller gets the secret at registration. Move the issuing of the completion capability into the spawning runtime (agents/termlink/termlink.sh run.sh), not into caller-accessible registration. Authenticate start and complete in the shared implementation. Replace the `_never_ran` → start/complete → tick control in tests/unit/t3580_round5_test.py:215 with:
   - a refusal test;
   - a positive control that actually launches a worker (a stub worker kind is fine).
   Anything that remains within the documented same-user residual (T-3581): say so in the task's Decisions. Do not claim more than you prove.
3. LOW (~378): vendor verification trusts the working-tree registry. Validate vendor provenance against the committed registry revision and the launchable worker kinds. Add a negative control for an uncommitted or unsupported vendor declaration.

`policy/review-backends.yaml` now has an `antigravity` backend with no worker_kind. Do not invent one. A vendor without a launchable worker kind must not count toward a panel.

Two other workers are running concurrently:
- T-3598 is editing agents/context/budget-gate.sh, agents/context/checkpoint.sh and budget tests;
- T-3593 is editing lib/tier0_action.py, agents/context/check-tier0.sh, agents/git/lib/hooks.sh and the t3593/t3594 bats.
Do not touch those files. With `bin/fw vendor self`, use `FW_VENDOR_ONLY="<your paths>"` and commit only your vendored copies, by name.

Rules:
- Stage by name only; commit messages start with `T-3580:`. Commit after each finding.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* / FW_VENDOR_ALL flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` as its own call, never chained.
- Run all t3579/t3580/t3581 tests (bats and pytest), tests/unit/termlink.bats, t3595_cleanup_scope.bats and upgrade_fresh_machine_simulation.bats. Report counts.
- Leave review criteria unticked and the task in started-work. Do not record any verdict.

Print only: commits, per finding fixed or not (with the proving test), test counts, and the residuals you left.
