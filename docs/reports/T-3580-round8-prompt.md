You are doing round 8 of T-3580 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3580` alone first. Follow CLAUDE.md.

TARGETED round. Fix only the findings below, each with a test that reproduces the reviewer's probe first (red), then passes. Iterate on the affected test files only, then run the full list once at the end.

Sources, both round 7:
- docs/reports/T-3580-round7-review-codex.md (codex RED, mediums only);
- docs/reports/T-3580-round4-review.md, section "## Round 7 review" (Claude AMBER; its probes are in /tmp/r7probe if still present).

Must fix:
1. **Claude N1: the builder can message the reviewer.**
   - For review dispatches, the prompt must be EXACTLY a fixed, committed review preamble plus the brief. No peer-consult or sidecar-inbox text, and no free text before the brief. Registration and start both check equality, not a suffix match.
   - Find where the consult text is injected into dispatch prompts (preamble, hook or wrapper), and exclude review dispatches there.
   - Record any peer-consult traffic addressed to a review worker's session in the run.
2. **Claude N2: model, endpoint and extra programs.**
   - Review dispatches refuse `--model` unless it equals the committed value for that worker kind in policy/review-backends.yaml; sign the resolved model into the run.
   - Refuse `--mcp-config`, `--strict-mcp-config`, `--allowed-tools`, `--tools` and `--permission-mode` from the caller on review dispatches; take them from committed config if a kind needs them.
   - Launch `claude -p` for review workers so project-local settings (`.claude/settings.local.json`, its env block and hooks) cannot apply, e.g. with `--setting-sources`. First check which flags the installed `claude` supports (`claude --help`), and use the documented one. If none exists, stop and report.
   - Fix the wrong "Workers spawn --bare" comment.
3. **codex 1: env.sh values are shell-evaluated.** Store env overrides as data (JSON) and load them without shell evaluation; bind the data to registration. Negative control: a command-substitution value. Positive control: a literal with shell metacharacters.
4. **codex 2: judge planning and the ledger disagree on the rung.** One history-aware `required_strength` for judge planning, registration, record and apply. Add a judge-level test for lowered-then-left-lowered.
5. **codex 3: git history errors fail open.** Distinguish "no history" from "could not read history". Refuse on the latter, and do not cache it.
6. **Claude N3: components are empty when the rung is chosen.** Count components from git (the task's commits) inside `required_strength`, and don't rely on the frontmatter field that close fills later.
7. **Claude N4: free-text spend rows.** A spend row counts toward the ceiling only if it names a signed run and dispatch, capped at that rung's cost.
8. **codex 4 (low):** catch OverflowError and cover oversized values.
9. **Claude N5 and N7 (cheap):**
   - add `--full-history` to the history walks;
   - review-dispatch caller `--env`: allow nothing (not even GIT_*) unless a test shows a reviewer needs it, and improve the refusal text.

Leave for follow-up tasks, created with `fw task create` and cited in Decisions:
- N6: crashed review directories are kept forever; the step-down WARN never expires;
- the step-down line in the handover.

Docs: update the CLAUDE.md delegation paragraph so it names what the caller can no longer steer and what remains. Move the cost-row lever out of the "needs the key" list if it is still reachable.

Concurrent workers:
- T-3602: the nightly unit-suite runner, audit check;
- T-3603: tests/unit triage;
- T-3610: test fixtures writing to /;
- T-3593: lib/tier0_action.py, check-tier0.sh, hooks.sh.
Do not touch their files.

**COMMIT WITH AN EXPLICIT PATHSPEC:** `git commit -m "..." -- <paths>`. All workers share ONE git index, and add-then-commit sweeps in other workers' staged files (your round 7 did exactly that). With `bin/fw vendor self`, use `FW_VENDOR_ONLY`, and commit only your vendored copies.

Rules:
- Commit messages start with `T-3580:`, one commit per finding.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* / FW_VENDOR_ALL flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` and `bin/fw work-on` alone on their line.
- Run everything in the FOREGROUND. Never background a command and end your turn.
- Leave the task in started-work. Do not record a verdict.

Print only: commits, per finding fixed or not (with the proving test), test counts, follow-up task ids, and residuals.
