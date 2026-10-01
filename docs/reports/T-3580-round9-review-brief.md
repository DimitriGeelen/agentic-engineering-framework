You are an INDEPENDENT REVIEWER, not the builder. Evaluate; do not rubber-stamp.
- The repo /opt/999-Agentic-Engineering-Framework is read-only for you. You may run the tests. Build fixtures only under a tmp dir.
- Never record a real verdict, and never tick a criterion in a real task.

## T-3580 round 9: SHORT targeted check before the operator's go/no-go
Check ONLY the round-9 fixes, against the round-8 findings:
- Claude R8-1 HIGH: cross-session inbound plus working-tree `.claude/`, `.mcp.json` and `CLAUDE.md` steering the reviewer;
- codex's three mediums: HEAD lookup fail-open, component undercount, recycled signed starts as spend;
- Claude R8-3, R8-4 and R8-5.
Sources: docs/reports/T-3580-round4-review.md "## Round 8 review" and docs/reports/T-3580-round8-review-codex.md.

Round-9 commits: a5b1dbbad, 924815293, bf7fad31b, f0f083427, d8851367c, 68ebe528e. Tests: tests/unit/t3580_round9_test.py. The builder's residuals are in the T-3580 Decisions and in CLAUDE.md "What the caller can still steer".

Answer exactly these:
1. Is R8-1 closed, for both (a) inbound messages and (b) working-tree project config? Check the real run.sh launch arguments and the `start` dirty-tree refusal. Is `{"crossSessionInbound": "refuse"}` passed via `--settings` honoured over a user file that says "accept" (check Claude Code's documented settings precedence)?
2. Are codex's three mediums and R8-3/4/5 closed?
3. Did round 9 open anything new: a fail-open path, over-blocking of an ordinary review dispatch, or a broken test?
4. Is any HIGH left, within the same-user boundary the operator accepted in T-3581? Answer YES or NO on its own line, then why.
5. Does the CLAUDE.md residual list match what is actually still possible?

Reply with: VERDICT green/amber/red, "HIGH LEFT: YES|NO", then findings (severity, where, what, fix). Keep it under 600 words. If you can write files, append it as "## Round 9 review" to docs/reports/T-3580-round4-review.md.
