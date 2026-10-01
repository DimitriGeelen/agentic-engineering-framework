You are an INDEPENDENT REVIEWER, not the builder. Evaluate; do not rubber-stamp.
- Verdicts: green / amber / red / escalate, with guidance.
- The repo /opt/999-Agentic-Engineering-Framework is read-only for you. You may run the tests. Build fixtures only under a tmp dir.
- Never record a real verdict, and never tick a criterion in a real task.

## T-3580 round 8, TARGETED review
Check ONLY whether the round-7 findings are closed, and whether the round-8 changes opened anything new in the code they touched.

Round-7 findings:
- docs/reports/T-3580-round7-review-codex.md (codex RED, mediums only: env.sh values shell-evaluated; judge versus ledger rung; git-history errors fail open; OverflowError);
- docs/reports/T-3580-round4-review.md, section "## Round 7 review" (Claude AMBER: N1 the builder can message the reviewer through consult text, and the prompt is only suffix-checked; N2 caller-chosen --model, --mcp-config and settings.local.json; N3 components empty at rung time; N4 free-text spend rows; N5 --full-history; N7 env allowlist).

Round-8 commits: a37a45e64, 16f7777e4, a7a6f0c6d, d04898195, 76e386c77, b30b5bf0a, 337e7a6d8, 256aea768, d4b3d0586, 3407165fa, 105865fbc, f37041881, 1f773f3f2.
- Tests: tests/unit/t3580_round8_test.py. The builder reports 510 pytest and 68 bats passing.
- Residuals and follow-ups (T-3619, T-3620) are in the T-3580 Decisions.

## Check
1. Re-run each round-7 probe:
   - a consult stanza before the brief;
   - `--model` other than the pinned one;
   - `--mcp-config`;
   - a `settings.local.json` env block or hook;
   - a `$(...)` value in the env;
   - lowered-then-left-lowered risk at judge level;
   - a git history read failure;
   - components counted at rung time;
   - a committed free-text spend row;
   - 10**400 in a spend row;
   - a caller `--env` on a review dispatch.
2. The new surfaces:
   - the exact-preamble-plus-brief equality check;
   - the pinned `model:` in policy/review-backends.yaml;
   - `--setting-sources user,project` (is `~/.claude/settings.json` a remaining steering route, and is it within the accepted same-user boundary of T-3581?);
   - env.json and `review-env`;
   - `task_required_strength`;
   - the components-from-git count;
   - spend bound to signed runs.
   Can any be bypassed, or made to fail open? Does any over-block an ordinary review dispatch (`fw reviewer T-XXX --dispatch`, `fw termlink dispatch --task-type review`)?
3. Do the docs match the code without over-claiming?
4. Is there any HIGH left? If none, say so explicitly. The operator will then decide whether the remaining mediums and residuals are acceptable rather than run another round.

Write the full review as your final answer (VERDICT / WHAT I CHECKED / FINDINGS with severity, where, what and fix / GUIDANCE). If you can write files, also append it as "## Round 8 review" to docs/reports/T-3580-round4-review.md.
