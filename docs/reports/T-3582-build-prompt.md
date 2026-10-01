You are building T-3582 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3582` alone first. Then read:
- the task file (Context with the operator's 2026-10-01 ruling, and all Agent ACs);
- CLAUDE.md §Review and Dispatch Cost Ruling;
- policy/review-backends.yaml;
- agents/termlink/termlink.sh (worker kinds, run.sh generation);
- lib/verdict_ledger.py (the T-3580 launch pinning: `_launch_fault`, registration, `start`/`complete`);
- the T-3580 round-9 review in docs/reports/T-3580-round4-review.md, "## Round 9 review", for R9-1.
Follow CLAUDE.md.

## Goal
Make Codex, Z.ai (opencode) and Antigravity real, launchable `fw termlink dispatch` worker kinds next to `claude`, with the same launch pinning T-3580 gives Claude. That makes a rung-5 panel of Claude + Codex + Z.ai possible. Also write the harness reference doc for the fleet cockpit (project 055), and fix T-3580 R9-1 in run.sh.

## Facts verified on this host (2026-10-01, as root)
- **Codex:** codex-cli 0.153.4. Headless: `codex exec -s read-only --skip-git-repo-check -o <outfile> "<prompt>" < /dev/null` (stdin must be closed). Auth is a ChatGPT subscription login (auth_mode chatgpt, ~/.codex/auth.json); no API key. Its read-only sandbox cannot write /tmp. A review worker that must write its verdict file needs a writable mode limited to its wdir; check `codex exec --help` for the sandbox options and pick the narrowest that works.
- **Z.ai:** opencode 1.18.31. Headless: `opencode run -m zai-coding-plan/glm-5.2 "<prompt>" < /dev/null`. Its output has ANSI escapes. Auth is in ~/.local/share/opencode/auth.json (provider zai-coding-plan).
- **Antigravity:** agy 1.1.15 at /home/dimitri-mint-dev/.local/bin/agy, logged into the operator's Google account. It must run as that user: `sudo -n -u dimitri-mint-dev -H agy -p "<prompt>" --mode plan --sandbox`. The operator approved this form for review use. It cannot read /root or a root-owned wdir, so plan how the brief reaches it and how its output comes back (for example a wdir readable by that user, or stdin/stdout only). If it cannot be made reliably non-interactive, record the evidence and leave it as a spare (an AC allows that).
- **Gemini CLI:** not on root's PATH. Check for it (`command -v gemini`, and under dimitri-mint-dev). Document it as not installed if absent; do not install anything.

## What to build (ACs in the task are the contract)
1. Worker kinds `codex`, `opencode` and `antigravity` in the dispatcher and the run.sh template. Each has:
   - a committed binary path and pinned model in policy/review-backends.yaml (`worker_kind`, `vendor`, `model`);
   - no caller env or flags;
   - the runtime-signed start/complete;
   - a verdict output the existing verdict parser reads. Normalise each harness's output into the same verdict file shape Claude workers produce.
   Settings isolation is per harness (each has its own config). Document what each one can and cannot isolate as a residual.
2. A forged vendor label is refused (test). A panel of three seats across anthropic, openai and zai is assembled and recorded end to end on a fixture task (test with stub binaries). Then do ONE live run per kind on a fixture task, with cost logged via `bin/fw review cost log` (all internal-class, no approval needed).
3. **T-3580 R9-1:**
   - no launch when `start` refuses;
   - append to stderr.log, never truncate;
   - make the dirty-tree check match what the pinned launch reads, so ordinary reviews in this shared checkout are not refused because another session edited CLAUDE.md. Prefer the narrow check, or the `git archive` export if that is simpler for all kinds alike. Decide and record it in Decisions.
4. `docs/harnesses.md` per the AC: all five harnesses, verified commands marked verified, everything else marked unverified, no secrets. It is the maintained source the fleet cockpit (055) will cite.
5. When the doc is committed, post ONE reply on the TermLink topic `cockpit:harness-access` with `--reply-to 1` and `--metadata from=999-agentic-engineering-framework`, naming the doc path and the commit, and saying which harnesses are verified. That is the only outward post you may make.

## Constraints
- Concurrent workers may edit lib/tier0_action.py, agents/context/check-tier0.sh, agents/git/lib/hooks.sh, web/, and tests/unit triage files. Do not touch them.
- COMMIT WITH AN EXPLICIT PATHSPEC: `git commit -m "..." -- <paths>`. All workers share one git index. With `bin/fw vendor self`, use `FW_VENDOR_ONLY`, and commit only your vendored copies.
- Commit messages start with `T-3582:`.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* / FW_VENDOR_ALL flags. If a gate blocks you, stop and report it. sudo is used ONLY in the exact operator-approved agy form above.
- Run `bin/fw context focus` and `bin/fw work-on` alone on their line.
- Run everything in the FOREGROUND. Never background a command and end your turn.
- Never write a bare `! cmd` that is not the last statement of a bats block.
- Tick Agent ACs as each one is proven. Leave the task in started-work.

Print only: commits, per AC done or not (with the proof), the live-run result per kind (verdict parsed or not, wall time), the doc path, the cockpit post offset, and residuals.
