You are an INDEPENDENT REVIEWER, not the builder. Evaluate; do not rubber-stamp.
- Verdicts: green / amber / red / escalate, each with guidance.
- The repo /opt/999-Agentic-Engineering-Framework is read-only for you. You may run the tests. Build fixtures only under a tmp dir.
- Never record a real verdict, and never tick a criterion in a real task.

## T-3580 round 6: slice 3 of T-3557 (`fw reviewer judge`, the verdict ledger)
The round-5 same-family (Claude) review was GREEN. The second-family (codex) review was RED: docs/reports/T-3580-second-family-codex.md.
- HIGH: the ledger did not enforce the required IW-7 rung.
- MEDIUM: a signed start did not prove that a reviewer ran.
- LOW: vendors were trusted from the working-tree registry.

Round-6 fix commits: bba485463 (HIGH), 7a6ca340b (MEDIUM), 21a201ee8 (LOW), b650d509f (tests and fabric).
- Key code: new lib/review_policy.py; lib/verdict_ledger.py; lib/reviewer/judge_cli.py; agents/termlink/termlink.sh (run.sh).
- Tests: tests/unit/t3580_round6_test.py and the other t3579/t3580/t3581 files.
- The builder reports 333 pytest passed, plus termlink.bats 8, t3595 8, t3579 bats 11 and upgrade simulation 11.
- The builder's residuals are in the Decisions section of .tasks/active/T-3580-*.md.

Background: CLAUDE.md §Human Task Completion Rule (the delegation paragraph), the T-3557 IW-7 impact-risk design in docs/reports/, and T-3581 (the operator ACCEPTED the same-user residual: audited and fail-closed, not forgery-proof).

## Try to break it
1. Re-run the codex probes. Is each finding closed, and is each negative control a real negative, not a tautology?
2. Rung enforcement: can a green at a lower rung than required tick a criterion, via record, via apply, through the spend-ceiling step-down, with a forged or stale ceiling decision, or by editing the spend log? Is the step-down visible?
3. Runtime capability: can a completion be produced without the registered run.sh actually running? Is the process-ancestry check sound? Which residuals are beyond the accepted same-user line, and which are within it?
4. Vendor provenance: a committed registry at the reviewed revision, launchable kinds only. Can a panel be satisfied by one vendor wearing two names, by antigravity, or by a registry changed after the reviewed revision?
5. Does anything that worked before break: ordinary review dispatches, termlink cleanup (T-3595), a vendor-only upgrade?
6. Do the docs (CLAUDE.md delegation paragraph, task Decisions) claim no more than the code proves?

Write the full review as your final answer (VERDICT / WHAT I CHECKED / FINDINGS with severity, where, what and fix / GUIDANCE). If you can write files, also append it as a section "## Round 6 review" to docs/reports/T-3580-round4-review.md. Otherwise print it only.
