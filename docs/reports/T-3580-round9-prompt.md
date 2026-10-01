You are doing round 9 of T-3580 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3580` alone first. Follow CLAUDE.md.

This is the SMALLEST targeted round yet. Fix only these, each with a test that reproduces the probe first (red), then passes. Iterate on the affected files, and run the full T-3580 list once at the end.

Sources, both round 8:
- docs/reports/T-3580-round4-review.md, section "## Round 8 review" (Claude AMBER);
- docs/reports/T-3580-round8-review-codex.md (codex AMBER, no HIGH).

1. **R8-1 (HIGH, Claude): steering through cross-session messages and working-tree project files.**
   - Launch the review worker with `--setting-sources user`, plus `--settings <file>` naming a committed, ledger-signed JSON: no env block, no hooks, cross-session inbound off. Use the documented key: check `claude --help` and the settings docs for the inbound setting's exact name. If inbound cannot be turned off per invocation, refuse at `start` when the effective user settings accept inbound, and record that refusal reason.
   - Also pass `--strict-mcp-config` with no `--mcp-config`.
   - `start` refuses when `CLAUDE.md`, `.claude/` or `.mcp.json` have uncommitted changes relative to the run's pinned revision. Prefer this over a clean export, as the smaller change.
   - Tests: a dirty `.mcp.json` / `CLAUDE.md` / `.claude/settings.json` is refused at start; the pinned settings file is what the worker gets.
2. **codex 1 and Claude R8-4: the HEAD lookup fails open.** Tell "no commits yet" apart from "git cannot answer", and refuse on the second.
3. **codex 2: component counting.** It can undercount valid cards and lose historical coverage. Fix per codex's finding. Also count only commits that changed files, not commits that merely mention the task id (Claude R8-2's side note).
4. **codex 3 and Claude R8-3: recycled starts as spend.** A spend row counts only when the dispatch's SIGNED start time falls inside the window. Ignore the row's own timestamp.
5. **Claude R8-5:** `complete` re-checks the hashes of prompt.md, brief.md and env.json.
6. **codex 4 and the Claude docs note:** the CLAUDE.md "What the caller can still steer" list names whatever is still possible after this round, and nothing that isn't.

Do NOT change the rung policy (Claude R8-2: most tasks now require rung 5). That is the operator's decision. Record in Decisions, with numbers, how many recent tasks require each rung under the current rule.

Concurrent workers:
- T-3593 round 5: lib/tier0_action.py, check-tier0.sh, hooks.sh;
- T-3621: agents/audit/, the unit-suite baseline.
Do not touch their files.

COMMIT WITH AN EXPLICIT PATHSPEC: `git commit -m "..." -- <paths>`. All workers share one git index. With `bin/fw vendor self`, use `FW_VENDOR_ONLY`, and commit only your vendored copies.

Rules:
- Commit messages start with `T-3580:`.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* / FW_VENDOR_ALL flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` and `bin/fw work-on` alone on their line.
- Run everything in the FOREGROUND. Never background a command and end your turn.
- Leave the task in started-work. Do not record a verdict.

Print only: commits, per item fixed or not (with the proving test), test counts, the rung distribution table, and residuals.
