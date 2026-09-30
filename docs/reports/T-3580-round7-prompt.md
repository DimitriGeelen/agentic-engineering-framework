You are doing round 7 of T-3580 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3580` alone first. Follow CLAUDE.md.

This round is TARGETED. Fix only the findings below, each with a test that reproduces the reviewer's probe first (red), then passes. Run only the affected test files while iterating, and the full list once at the end. Do not re-audit or refactor anything else.

Sources, both round 6:
- docs/reports/T-3580-round6-review-codex.md (codex, RED);
- docs/reports/T-3580-round4-review.md, section "## Round 6 review" (Claude, AMBER; its probes are in /tmp/t3580r6probe/test_probe.py if still present).

Fix:
1. **The ceiling step-down lever.** Both reviewers found this: codex HIGH-1 and MEDIUM-2, Claude F1.
   - A decision is valid only for the run it was computed for: compute it at registration, from spend up to the registration time. A new run can never reuse an old decision.
   - Ceilings and spend values must be finite and ≥ 0; NaN, infinity, negative or malformed values refuse a step-down.
   - The ceiling has a floor. A ceiling of 0 or below, or below the floor, means "no step-down", never "always step down". Choose the floor from the spend data's units and state it in Decisions.
   - Spend comes from the committed cost ledger (`.context/costs/reviews.jsonl`, the append-only history) or from an append-only log validated against git, never from an untracked file.
   - Disclosure: the ticked criterion's annotation shows "rung R granted, rung D due, reason", and `fw audit` WARNs on every step-down. Fix the `lib/config.sh` description to say what is actually recorded.
2. **Claude F2, steering the worker.**
   - For review dispatches, refuse any `--env` key that chooses the program or model: PATH, any *_BASE_URL, ANTHROPIC_*, OPENAI_*, CLAUDE_*, or model or binary overrides. Use a deny-by-default allowlist, not a denylist.
   - Call the worker binary by absolute path, resolved at dispatch.
   - Sign a hash of the brief (prompt file) into the run, and check it at start.
   - Correct the Decisions sentence the reviewer quotes.
3. **Claude F3, codex MEDIUM-4.**
   - Take the launchable-kinds list and the run.sh template from the committed revision, not the working tree.
   - Pin one reviewed revision and one registry blob for the whole run; every seat must use that binding.
   - Add a negative control with mixed revisions and one kind under two vendor names.
4. **codex MEDIUM-3.** Cleanup must not delete a review worker's directory between `exit_code` and `finalised`. Apply the same finalisation check `_worker_done` uses. Add a test with a runtime paused in that window.
5. **Claude F4 (cheap).** The required rung is the highest rung over the task file's committed history of the risk fields, not only its current value.
6. **Docs.** The CLAUDE.md delegation paragraph must describe the enforced rungs, the step-down and its limits, and what it does NOT prove. Mark superseded Decisions as superseded.

Leave out: F5 (consumer without a committed `.agentic-framework/`). File it as its own task with `fw task create`, with the evidence the reviewer gave.

Other workers are running concurrently:
- T-3593 round 4: lib/tier0_action.py, check-tier0.sh, hooks.sh;
- T-3602: the nightly unit-suite runner and audit check;
- T-3603 and T-3604: tests/ triage.
Do not touch their files. If you must edit agents/audit/audit.sh for the step-down WARN, keep it to one new function and check `git diff` first for another worker's uncommitted hunk; if there is one, stop and report. With `bin/fw vendor self`, use `FW_VENDOR_ONLY`, and commit only your vendored copies, by name.

Rules:
- Stage by name only; commit messages start with `T-3580:`, one commit per finding.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* / FW_VENDOR_ALL flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` and `bin/fw work-on` alone on their line.
- Run everything in the FOREGROUND. Never background a command and end your turn; you will not be woken up again.
- Leave the task in started-work. Do not record a verdict.

Print only: commits, per finding fixed or not (with the proving test), test counts, and residuals.
