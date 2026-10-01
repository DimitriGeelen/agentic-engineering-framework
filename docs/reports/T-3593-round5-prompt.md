You are doing round 5 of T-3593 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3593` alone first. Follow CLAUDE.md. T-3594 is GREEN; do not change its behaviour.

## Why this round is different
Four rounds have closed lists of shell spellings, and every second-family review has found a new one: `command export`, a quoted `'export'`, `git -C /tmp/a\ b`, `sudo bin/fw tier0 approve`, brace expansion, `$'..'` quoting. A denylist over shell cannot be complete. This round INVERTS the classifier.

**Strict grammar.** A command maps to an ACTION only if every segment is in a small, explicit grammar:
- Tokens are plain words matching `[A-Za-z0-9._/:=@+%,-]+`. No quotes, backslashes, `$`, backticks, braces, globs, `~`, redirections, subshells or here-docs anywhere in the WHOLE command.
- Separators are `&&` only. `cd <plain path>` may precede; nothing else may precede or follow the git segment.
- The command is `git` (optionally `-C <plain path>`, `-P` or `--no-pager`), then the known subcommand, then plain options and refspecs. Long options resolve against git's own list, as today.
- `rm -rf <plain path>`, with the same rules.

ANYTHING outside the grammar is UNMAPPED and takes the exact-text approval path. That is the fail-safe direction: the operator sees the literal command. HOOK BYPASS labelling stays as a separate, best-effort warning, and must never be required for safety.

## Also fix (with tests that reproduce the reviewer probe first)
- **Claude round-4 F1, self-approval through privilege and session wrappers:** `sudo`, `su`, `runuser`, `tmux`, `screen`, `setsid`, `nohup`, `env -i`, `bash -c`/`sh -c`, and so on, anywhere in a command containing `tier0`; obfuscated spellings (``tier0 `echo approve` ``, `appr{o,}ve`, `approv$'e'`, `tier""0`, `$X approve`). Rule: any command whose text contains `tier0` (after removing quotes and backslashes) and is not a plainly spelled read-only verb (`fw tier0 status`, `fw tier0 list`) is Tier 0.
- **Claude F2:** `git config [--global|--system] include.path|includeIf.*` gets the same label as `core.hooksPath`; fix the FRAMEWORK.md over-claim.
- **codex round-4 HIGHs:**
  - environment taint behind `command`/quoted builtins;
  - escaped-space global-option arguments.
  The grammar should close both by construction; prove it with their exact probes.
- **codex MEDIUM:** the legacy path must fail closed when `flock` fails or is missing, and must never proceed unlocked.
- **codex MEDIUM:** a test that ACTUALLY runs the first approved `git reset --hard HEAD~1` in a fixture, attempts a second under a fresh tool_use_id, and checks the branch moved only once.
- **T-3610's Tier 0 false positive:** read-only `stat -c … /.git/hooks`, and `bash -c` next to a filename containing "hooks", were blocked as a `-c core.hooksPath` bypass. Fix the match (the `-c` must be git's option), with a test.
- **Claude F5:** FRAMEWORK.md's CDPATH wording.
- File the `rm -rf sub/../..` gap as a concern, or close it with the grammar (a `..` path component is outside the grammar, so the command is unmapped).

## Docs
CLAUDE.md §Enforcement Tiers and FRAMEWORK.md get one paragraph describing the grammar: "only these exact shapes map to actions; everything else needs approval of the exact text". Name the residuals honestly: anything inside a script, and writing the approval file directly.

Concurrent workers:
- T-3580: lib/verdict_ledger.py, lib/reviewer/, lib/review_policy.py, agents/termlink/termlink.sh;
- T-3621: agents/audit/ and the unit-suite baseline.
Do not touch their files.

COMMIT WITH AN EXPLICIT PATHSPEC: `git commit -m "..." -- <paths>`. All workers share one git index. With `bin/fw vendor self`, use `FW_VENDOR_ONLY`, and commit only your vendored copies.

SAFETY: fixtures only, under a tmp dir; the git discovery fence applies (`tests/git_fence.bash`). NEVER force-push, delete a branch or hard-reset in this repo or against a real remote. Never approve a real Tier 0 action.

Rules:
- Commit messages start with `T-3593:`.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* / FW_VENDOR_ALL flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` and `bin/fw work-on` alone on their line.
- Run everything in the FOREGROUND. Never background a command and end your turn.
- Run t3593*, t3594*, every tier0_*.bats, check_tier0_comment_stripping and upgrade_fresh_machine_simulation.bats before your final commit. Never write a bare `! cmd` that is not a block's last statement.
- Leave the review criteria unticked and the task in started-work.

Print only: commits, per item fixed or not (with the proving test), test counts, the over-blocking you accepted (which ordinary commands now need exact-text approval), and residuals.
