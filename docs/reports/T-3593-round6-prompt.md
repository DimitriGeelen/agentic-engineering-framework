You are doing round 6 of T-3593 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3593` alone on its line first. Follow CLAUDE.md.

SMALLEST round. Fix only these two findings from docs/reports/T-3593-round5-codex.md, each with a test that reproduces the probe first (red), then passes. The round-5 strict grammar held against every shell-spelling probe; do not redesign it.

1. **HIGH: local branch deletion normalises different names to one key** (lib/tier0_action.py:~442).
   - `git branch -D victim`, `git branch -D +victim` and `git branch -D refs/heads/victim` currently produce the same action and key. For a LOCAL delete, git treats `+victim` and `refs/heads/victim` as literal, distinct branch names.
   - Keep local branch names LITERAL: no `+` stripping, no `refs/heads/` stripping. Refspec normalisation is for pushes only.
   - Show the literal name in the block message.
   - Fixture test: an approval for `victim` cannot be consumed by `-D +victim` or `-D refs/heads/victim`, and the other way round. Cover `-d`, `--delete` and `-D` with several names, and `git branch -D -- name`.
   - Then check the other verbs for the same class: the `hard-reset` branch/target and `recursive-delete` paths. Is any normalisation applied to them that could make two different targets share a key? Fix it if so; otherwise record "checked, none" in Decisions.
2. **MEDIUM: encoded-word self-approval** (`env -u CLAUDECODE bin/fw $'tier\x30' approve` returned SAFE).
   - Decode ANSI-C quoting (`$'...'`, with all escape forms bash supports: `\xHH`, `\NNN`, `\uHHHH`, `\cX`, and so on) before the tier0 self-approval keyword check.
   - Add tests: `$'tier\x30'`, `$'\x74ier0'`, `$'tier\060'`, `$'tier'0` and similar.
   - The docs already disclose run-time-built words (printf, eval) as residual; keep that wording.
3. **Docs (codex LOW):**
   - CLAUDE.md and FRAMEWORK.md say "everything else needs exact-text approval". Change it to "every DETECTED destructive command outside the grammar needs exact-text approval".
   - List the allowed bare `fw tier0`, `help`, `--help` and `-h` forms.
   - Qualify the lock-failure wording to cover same-call duplicate admission.

Concurrent workers (do not touch their files):
- T-3582: agents/termlink/termlink.sh, lib/verdict_ledger.py, policy/review-backends.yaml;
- the bug batches: bin/claude-fw, lib/pickup.sh, init templates, agents/sessions/, agents/resume/, agents/audit/;
- T-3635: .context/project/, .context/arcs/.
bin/fw is yours only if your fix strictly needs it.

COMMIT WITH AN EXPLICIT PATHSPEC: `git commit -m "T-3593: ..." -- <paths>`. With `bin/fw vendor self`, use `FW_VENDOR_ONLY`, and commit only your vendored copies.

SAFETY: fixtures only, under a tmp dir (git fence). NEVER delete a real branch, force-push or hard-reset in this repo or against a real remote. Never approve a real Tier 0 action.

Rules:
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* / FW_VENDOR_ALL flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` and `bin/fw work-on` alone on their line.
- Run everything in the FOREGROUND. Never background a command and end your turn.
- Before the final commit, run t3593*, t3594*, every tier0_*.bats, check_tier0_comment_stripping and upgrade_fresh_machine_simulation.bats. Never write a bare `! cmd` that is not the last statement of a bats block.
- Leave the review criteria unticked and the task in started-work.

Print only: commits, per item fixed or not (with the proving test), the other verbs checked, and test counts.
