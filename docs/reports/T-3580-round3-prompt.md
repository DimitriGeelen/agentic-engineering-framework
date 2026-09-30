You are continuing T-3580 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3580` (session-scoped focus). Follow CLAUDE.md.

Read first:
- docs/reports/T-3580-round2-review-openai.md: RED, with 3 highs, 4 mediums and 1 low;
- docs/reports/T-3580-build-prompt.md: the sovereignty hold still applies: fixtures and fake dispatchers only, no real task judged, and no `.context/reviews/` in this repo;
- T-3580's Context, including "### Cost system integration (T-3583, for round 3)";
- policy/review-backends.yaml, `fw review cost|propose|approve|backend` (lib/review.sh) and CLAUDE.md's review-cost section. These encode the operator's cost ruling: every review logs a cost; subscription harnesses and the local GPU are internal; OpenRouter is paid and needs a proposal the operator approves. The registry is operator-extensible.

Principle: the LEDGER enforces, not the judge CLI.

Fix, each with a ledger-level test and a negative control:
1. HIGH, attribution is self-asserted: `record` builds the "signed completion" from its own row. The completion must be emitted by the dispatch RUNTIME when the worker actually finishes: agents/termlink/termlink.sh writes it at worker exit, with the worker session, exit state, and the result hash. `record` and `_row_fault` verify it, and `record` must never be able to manufacture it.
2. HIGH, reviewed revision: capture the commit sha BEFORE review, bind it into the dispatch and the worker result, and have `record` use and verify that sha, not HEAD at record time. Negative control: implementation changes between review and record.
3. HIGH, page discovery truncates at 6: preserve every required page in the signed run. If capture is capped, record the uncaptured pages so a render green is refused. Negative control with 7 pages.
4. MEDIUM, satisfying_verdict reports a latest non-green before validating it: run _fault first; invalid rows map to unknown.
5. MEDIUM, the worker command single-quotes reviewer-$FW_SIDECAR_AGENT_ID: fix the quoting, and add a test that runs the generated command in a real shell.
6. MEDIUM, restore the three loosened assertions: t3581_round4 missing-guidance (a separate tampering test; a fixture with a matching signed completion must fail for no guidance), t3579 "introduced by producer" (producer-specific), and t3579 "no commit references" (separate empty-repo and no-task-producer tests).
7. Cost integration (T-3580 Context): the judge reads backends from policy/review-backends.yaml (no hardcoded vendors), logs one cost record per seat via the helper, and a paid rung emits `fw review propose` and waits, never dispatching.

Rules:
- Stage by name only; commit messages start "T-3580: ".
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* flags; if a gate refuses, stop and report.
- Another worker (T-3591) edits web/blueprints/tasks.py in parallel; do not touch it. Retry commits on index.lock.
- `bin/fw vendor self`, commit the vendored copies by name (including bin/fw if changed), then `--check`.
- Run the full t3579, t3581 and t3580 test files and the bats files; report counts.
- Untick any criterion the review shows unmet; tick it only when proven. Live proof stays unticked. Do not close.

Print only: commits, per finding closed or not (with proving test), test counts, anything unresolved.
