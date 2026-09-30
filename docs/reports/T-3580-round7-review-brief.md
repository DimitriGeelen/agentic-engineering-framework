You are an INDEPENDENT REVIEWER, not the builder. Evaluate; do not rubber-stamp.
- Verdicts: green / amber / red / escalate, with guidance.
- The repo /opt/999-Agentic-Engineering-Framework is read-only for you. You may run the tests. Build fixtures only under a tmp dir.
- Never record a real verdict, and never tick a criterion in a real task.

## T-3580 round 7, TARGETED review
Check ONLY whether the round-6 findings are closed, and whether the round-7 changes opened anything new in the code they touched.

Round-6 findings:
- docs/reports/T-3580-round6-review-codex.md (codex RED: stale ceiling decision reuse, NaN fail-open, cleanup/signing race, panel registry binding, docs);
- docs/reports/T-3580-round4-review.md, section "## Round 6 review" (Claude AMBER: F1 ceiling lever via env/config/untracked spend; F2 steering the worker via --env PATH / *_BASE_URL and an unbound brief; F3 working-tree kinds and template; F4 rung from producer-controlled fields).

Round-7 commits: fcc26c6e8 (F1), 518cd440b (F2), f87304b8e (F3), 5654a6f4f (cleanup race), fc1fb72cb (F4), 64584b83b (docs), e107da08d (vendored).
- Tests: tests/unit/t3580_round7_test.py and t3580_round7_cleanup.bats. The builder reports 378 pytest and 86 bats passing.
- Residuals are in the T-3580 Decisions section.
- Note: fcc26c6e8 also carried two unrelated T-3602 files (agents/audit/unit-suite.sh and its test) through a shared git index. Judge only the T-3580 content, but say if anything in those files affects T-3580.

## Check
1. Re-run each round-6 probe:
   - a 2020 ceiling decision for a new run;
   - untracked spend;
   - ceilings of 0, -1, NaN, inf and 50;
   - `.framework.yaml` set to 0;
   - `--env PATH`, `ANTHROPIC_BASE_URL` and other steering keys;
   - a changed brief after registration;
   - mixed revisions with one kind under two vendor names;
   - cleanup between `exit_code` and `finalised`;
   - lowered-then-left-lowered risk fields.
2. The new surfaces:
   - the step-down computed at registration from the committed ledger;
   - the floor of 100;
   - the env allowlist (it currently refuses FW_SESSION_SCOPED_FOCUS / FW_FOCUS_SESSION_KEY. Is that right, or should keys that choose neither program nor model be allowed?);
   - the absolute worker path;
   - the brief hash;
   - the history-max rung.
   Can any be bypassed or made to fail open? Does any over-block ordinary review dispatch?
3. Is the step-down disclosure (annotation plus audit WARN) visible where an operator would see it?
4. Do the docs match the code, without over-claiming?

Write the full review as your final answer (VERDICT / WHAT I CHECKED / FINDINGS with severity, where, what and fix / GUIDANCE). If you can write files, also append it as "## Round 7 review" to docs/reports/T-3580-round4-review.md.
