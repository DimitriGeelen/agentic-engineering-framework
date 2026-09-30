You are building T-3579 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). It is slice 2 of T-3557 (GO 2026-09-30). Focus is T-3579 (started-work) and you own it while you run. Follow CLAUDE.md.

Read first:
- .tasks/active/T-3579-*.md: Context and ### Agent criteria are the spec.
- .tasks/completed/T-3557-*.md: Decision, IW-1..IW-7.
- .tasks/completed/T-3578-*.md: slice 1. It added REVIEWER_JUDGES to lib/delegation.py, which is the one place routing is defined.
- docs/reports/T-3578-code-review.md, if present: the independent review of slice 1.
- The manual path this slice replaces: see how T-3544, T-3552 and T-3574 were closed (their task files and `git log`). A hand-moved criterion plus `--skip-render-review` plus `FW_ALLOW_PARTIAL_COMPLETE_EDIT=1`.

Code to study: agents/task-create/update-task.sh (check_render_surface_human_ac around line 506, the R-033 human-ownership branch, the partial-complete logic), lib/render_surface.sh, lib/human_review_state.py, the reviewer auto-tick path with its digest and feedback-stream (T-1985; grep auto_tick in lib/reviewer), and lib/judge_verdict.py (the existing green/amber/red/unknown contract; reuse it, do not invent a second one).

Design constraints:
- A verdict is data written by a reviewer who is not the producer, never by the closing agent. The closer only reads the ledger. Provide a small writer function or CLI that slice 3 will call, e.g. `fw reviewer verdict record ...`, and make the producer check real. The producer is the identity that committed the task's work; derive it from commits referencing the task, or from a recorded field, and document which.
- Only REVIEWER_JUDGES criteria can be satisfied by a verdict. Read the class from lib/delegation.py; do not re-derive it.
- Digest-keyed, as T-1985: changed criterion text means the verdict no longer applies.
- Non-green verdicts go to the refusal ledger. Check whether T-3555 built one (`ls .context/` and grep refusal). If not, use a documented interim JSONL and say so.
- No bypass flags anywhere in the new path. The whole point is that closing on a green verdict is the NORMAL path.

Rules:
- Stage by name only; commit messages start "T-3579: ".
- No --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- Tick Agent criteria as you meet them; write guarded ## Verification lines.
- Close with `bin/fw task update T-3579 --status work-completed`. If a gate refuses, stop and report; do not bypass.

Print only: commits, what the ledger record looks like (one example line), test results, anything unresolved.

## First: three findings from the independent review of slice 1 (docs/reports/T-3578-code-review.md, OpenAI, AMBER, no safety defects)
Fix these first, in their own commit ("T-3579: slice-1 review fixes — ..."), and record them in T-3579's Updates:
1. lib/delegation_cli.py:294: inception tasks return before classification, even with --dry-run --json. Remove the early return and use the shared classifier (inception criteria still cannot convert). Replace the refusal test with assertions covering routine and risky inception criteria, valid JSON, and no mutation.
2. lib/delegation_cli.py:418: the delegate summary omits the reviewer-judged count. Add it to both the text and the JSON output.
3. CLAUDE.md ~808: the documented WARN condition must say "reviewer-closeable and reviewer-judges are both zero".
