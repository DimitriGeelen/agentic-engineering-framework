You are building two tasks IN SEQUENCE in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree): first T-3593, then T-3594. Session-scoped focus: `bin/fw work-on T-3593`, and later `bin/fw work-on T-3594`. Follow CLAUDE.md.

Read first:
- .tasks/completed/T-3576-*.md: the inception and its GO;
- the two task files' ### Agent criteria (the spec);
- agents/context/check-tier0.sh, the `fw tier0` verbs (grep bin/fw and lib/ for tier0 approve/status), agents/git/lib/hooks.sh (the pre-push hook), and CLAUDE.md §Enforcement Tiers (T-2742).

SAFETY, non-negotiable:
- Test ONLY against fixture git repos and fixture bare remotes under a tmp dir. NEVER force-push, delete a branch, or hard-reset in this repo or against any real remote.
- NEVER approve a real Tier 0 action yourself. `fw tier0 approve` is human-only by design; tests use fixtures and `--i-am-human` inside fixture repos only.
- Do not weaken existing Tier 0 blocking. Every change must be at least as strict for the command-text path, and add the action path.

Rules:
- Stage by name only; commit messages start with the task id.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* flags; if a gate refuses, stop and report.
- If .claude/settings.json changes, run `bin/fw enforcement baseline`.
- `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- Keep tests/unit/upgrade_fresh_machine_simulation.bats green.
- Tick each criterion when proven, EXCEPT the independent-review criterion in each task (the parent session runs it). Leave both tasks in started-work.

Print only: commits per task, per criterion met or not (with the proving test), anything unresolved.
