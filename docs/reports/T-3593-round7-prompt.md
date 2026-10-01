You are doing round 7 of T-3593 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3593` alone on its line first. Follow CLAUDE.md.

## The principle for this round: NO NORMALISATION
Every round since round 4 has found the same class: two DIFFERENT targets share one approval key because a name or path was normalised. Examples: `+name` versus `name` (round 5); `link/` versus `link` (round 6); a branch literally named `refs/tags/x` versus tag `x`, and quoted whitespace collapsed in the fallback hash (codex round 6, docs/reports/T-3593-round6-codex.md). Kill the CLASS, not the instance:
- **Action keys:** use the FULLY QUALIFIED, LITERAL target. Pushes key on the full destination ref (`refs/heads/x`, `refs/tags/x`), resolved the same way at the text gate and at pre-push. Never strip `refs/heads/`. Local branch deletes key on the literal name (round 6 already does this). Paths in recursive-delete key on the literal operand as typed; do not resolve or collapse. If a target cannot be resolved to one fully qualified ref with certainty, the command is UNMAPPED (exact-text path).
- **The fallback (exact-text) hash:** hash the ORIGINAL command bytes. Do not collapse whitespace anywhere. Duplicate-fire dedup is by `tool_use_id` (round 4), so text normalisation is no longer needed for retries. Remove it, and fix the tests that relied on it.
- **The display** shows exactly the key.

## Also fix
- **codex round-6 MEDIUM, NUL in `$'..'`:** bash truncates an ANSI-C string at `\0` / `\x00`, and the detector must do the same before the tier0 check. Probes: `$'tier\0junk'0`, `$'tier\x00junk'0`.
- **Process:** in `bin/fw` and the docs, the T-3593 commit/vendor examples must avoid the `FW_VENDOR_ONLY="lib/tier0_action.py …"` path-order false block, OR fix the module-execution rule so a path inside an env assignment is not read as running the module. Prefer the fix; add a test.

## Tests
- Every collision codex found becomes a test: an approval for one target must not admit the other.
- A sweep test: for each verb, generate pairs of distinct targets (prefixes, trailing separators, case, `./`, a duplicated slash in the middle, quoted whitespace) and assert distinct keys, or unmapped.
- Push consumption at pre-push still works for ordinary forced pushes (round-4 end-to-end tests).

Other workers are running concurrently: T-3580 live proof (no source edits); 055 port batch C (bin/claude-fw). Do not touch bin/claude-fw, agents/termlink/termlink.sh, lib/verdict_ledger.py or lib/reviewer/.

COMMIT WITH AN EXPLICIT PATHSPEC: `git commit -m "T-3593: ..." -- <paths>`. With `bin/fw vendor self`, use `FW_VENDOR_ONLY`, and commit only your vendored copies.

SAFETY: fixtures only, under a tmp dir (git fence). NEVER delete a real branch, force-push or hard-reset in this repo or against a real remote. Never approve a real Tier 0 action.

Rules:
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* / FW_VENDOR_ALL flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` and `bin/fw work-on` alone on their line.
- Run EVERYTHING in the FOREGROUND, test suites included, and wait for them. Never background a command and end your turn; you will not be woken up again.
- Before the final commit, run t3593*, t3594*, every tier0_*.bats, check_tier0_comment_stripping and upgrade_fresh_machine_simulation.bats. Never write a bare `! cmd` that is not the last statement of a bats block.
- Leave the review criteria unticked and the task in started-work.

Print only: commits, per item fixed or not (with the proving test), the sweep result, test counts, and any ordinary command that now needs exact-text approval but did not before.
