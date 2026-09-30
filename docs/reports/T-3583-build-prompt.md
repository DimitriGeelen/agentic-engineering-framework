You are building T-3583 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Focus is T-3583 (started-work); you own it while you run. Follow CLAUDE.md.

Read .tasks/active/T-3583-*.md: its Context (the operator's words, verbatim) and ### Agent criteria are the spec. Also read the operator decision just added to .context/project/decisions.yaml (search "Review and dispatch cost ruling").

Patterns to reuse, not reinvent:
- the Tier 0 approval flow: agents/context/check-tier0.sh, `fw tier0 approve`, and how /approvals surfaces pending items (web/blueprints/approvals.py);
- the agent-refusal pattern under CLAUDECODE=1 with `--i-am-human` (lib/inception.sh do_inception_decide);
- the PreToolUse hook registration pattern (.claude/settings.json, and `bin/fw enforcement baseline` after any change to it);
- the config registries (lib/config.sh + web/blueprints/config.py) if you add a key.

Back-fill data: the 13 hand-run reviews from 2026-09-29/30 are the report files matching `docs/reports/T-35{35,79,80,81}-*review*-{openai,zai,anthropic}.md`. Of those, codex = OpenAI, opencode = Z.ai coding plan, claude -p = Anthropic, all subscriptions. There are also two runs with no saved report: one Z.ai re-review of T-3581 cut off by a permission prompt, and one Z.ai re-review of T-3580 stopped by the parent. Log them as internal/unmetered and say so.

Do NOT touch lib/verdict_ledger.py or lib/reviewer/judge_cli.py beyond what the T-3580 criterion needs. If the judge integration is large, leave it to T-3580's round 3 and write the exact requirement into T-3580's Context instead; say which you chose.

Rules:
- Stage by name only; commit messages start "T-3583: ".
- No --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- If you edit .claude/settings.json, run `bin/fw enforcement baseline` and add it to ## Verification.
- `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- If a render surface changes (the /approvals page), the parent session gets it reviewed. Do NOT tick that; do not close the task. Otherwise, close with `bin/fw task update T-3583 --status work-completed` when every criterion is met.

Print only: commits, per criterion met or not, test counts, anything unresolved.
