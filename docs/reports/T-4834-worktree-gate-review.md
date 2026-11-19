# T-4834: review of 055's worktree-grant gate for AEF

Received source: docs/reports/T-4834/received-055-worktree-gate.md (055 T-649, commit 0cd10ba5).

## Dialogue Log

### 2026-11-19 — walkthrough of the ready inceptions

The agent built a first "which inception first" list (T-3496 spike v0). It ranked T-3682
first among the inceptions waiting on the agent. **Operator, verbatim:** "4, T-4834 first,
it only needs the verdict." Recorded in T-3496 as the first calibration point: the operator
weights *closeness to a decision* above *being named by other tasks*.

Correction found while doing it: T-4834 was not "only the verdict" in the strict sense. Its
one question counted as disposed because it was deferred to the operator, while the task
text still owed an agent review of 055's hook. That review is below; the verdict follows it.

## Review against AEF

What 055's hook refuses without a live operator grant: `git worktree add` (also after shell
keywords, in subshells, `$( )`, `bash -c`, `eval`), `fw worktree create`,
`fw termlink dispatch --project <linked worktree>`, Claude Code's EnterWorktree, Agent with
`isolation: worktree`; and any agent write to the grant file. The grant is written only by an
interactive command that needs a real terminal and refuses `--yes`.

Fit with AEF:
- **Footprint.** Only `fw worktree create` (lib/worktree.sh:347) creates worktrees in framework
  code. Releases (lib/release.sh) and `fw termlink dispatch` do not, so nothing routine breaks.
- **Grant route.** AEF's operator-only actions are verbs refused under agent control
  (`fw tier0 approve`, `fw inception decide`, `fw reviewer ruling record`). A
  `fw worktree grant [--hours N]` verb fits that pattern better than a project-specific
  run-me script, and is what consumers would get through `fw upgrade`.
- **Same limits as every text gate** (CLAUDE.md Tier 0 boundary): a script that runs
  `git worktree add` inside a file is not seen. Fail-closed against accidents, not forgery.
- **Policy text.** CLAUDE.md §Worktree Policy says the mechanism "is NOT gated"; GO changes
  that sentence, which is why the decision is the operator's.

Evidence that the behavioural rule alone is not enough:
- 055: 27 uninstructed worktree branches in 8 days (2026-10-19..27).
- AEF: two worktrees from 2026-09-25/26 still on disk (`/opt/aef-f21-f24`, `/opt/aef-f25`,
  both prunable); no new worktree branches since 2026-10-20 except release hotfix branches.

## Verdict

GO — see the task's Recommendation for the proposed shape.
