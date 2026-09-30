You are fixing round 4 of T-3593 and T-3594 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3593` alone first. Follow CLAUDE.md.

Two independent reviewers came back with T-3593 RED and T-3594 AMBER. Read both in full:
- docs/reports/T-3593-T-3594-review.md, section "## Round 3 review" (Claude);
- docs/reports/T-3593-round3-codex.md (codex, a second model family).

Fix every finding, each with a bats test that reproduces the reviewer's probe first (red), then passes.

1. **Environment and prefix routes, one rule rather than a list.**
   - Any variable assignment before git, and any `env` / `env -u` / `env -i` wrapper, makes a segment UNMAPPED, so it takes the exact-text approval path. That covers `GIT_*`, `HOME`, `XDG_CONFIG_HOME`, `GIT_CONFIG_GLOBAL`, `GIT_CONFIG_PARAMETERS` (including multi-setting quoted values), `CDPATH`, and anything else.
   - Any git global option before the subcommand other than a small allowlist also makes it unmapped. `-P`, `--no-pager`, `-c`, `-C` and `--git-dir` are all in question: decide per option, and default to unmapped.
   - The HOOK BYPASS label must show whenever an override of `core.hooksPath` is possible.
2. **CDPATH:** a `cd` whose target is relative and not `./`-anchored, with CDPATH set anywhere in the command, never carries a known cwd.
3. **The 5-second T-1508 repeat window.** Replace the same-text-within-5s allowance with invocation-bound deduplication: the second hook fire of the SAME tool call is allowed, a second tool call is not.
   - Find what identifies one tool call in the hook's stdin, e.g. `tool_use_id`. Check it on a real payload: the PreToolUse input fields are documented, and `.context/working/` or the hook logs may hold samples.
   - If no per-call id exists, stop and report that. Do not keep a time window and call it single-use.
   - Test that an approved `git reset --hard HEAD~1` cannot run twice.
4. **T-3594 keys:**
   - tag deletes (`--delete v1`, `:v1`) and `src:dst` pushes must key identically at the text gate and at pre-push (`refs/tags/<t>` versus the short branch name);
   - a stranded tag-delete approval must never authorize deleting a same-named branch.
5. **`git commit -n -m x`** (combined and separated short flags): the no-verify check must catch every spelling git accepts.
6. **Docs:** CLAUDE.md §Enforcement Tiers and FRAMEWORK.md must say exactly what is covered. Name each residual explicitly, and do not claim "every GIT_CONFIG_*" unless it is true.

SAFETY: fixtures only, under a tmp dir. NEVER force-push, delete a branch or hard-reset in this repo or against any real remote. Never approve a real Tier 0 action.

Another worker (T-3580) is editing lib/verdict_ledger.py, lib/reviewer/ and agents/termlink/termlink.sh; T-3602 is editing the nightly unit-suite runner and its audit check. Do not touch those. With `bin/fw vendor self`, use `FW_VENDOR_ONLY="<your paths>"` and commit only your vendored copies, by name.

Rules:
- Stage by name only; commit messages start with `T-3593:` or `T-3594:`.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* / FW_VENDOR_ALL flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` and `bin/fw work-on` alone on their line.
- Run every command in the FOREGROUND and wait for it. Never background a command and end your turn; you will not be woken up again. That is how round 3 was lost.
- Run t3593 and t3594 bats, every tests/unit/*tier0*.bats and upgrade_fresh_machine_simulation.bats before your final commit. Never write a bare `! cmd` assertion in bats.
- Leave review criteria unticked and the tasks in started-work.

Print only: commits, per item fixed or not (with the proving test), test counts, and residuals.
