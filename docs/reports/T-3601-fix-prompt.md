You are fixing T-3601 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3601` first. Then read the task file (Context, Agent ACs) and follow CLAUDE.md.

Four tests in tests/unit/checkpoint.bats (3, 5, 6, 7) are red on HEAD. They expect `50000` in `agents/context/checkpoint.sh status` output.
- Find the breaking commit. Bisect in a scratch copy: for each candidate rev, `git archive <rev> | tar -x -C $tmp` and run only those tests there. Never bisect or check out old revs in the main checkout, and do not create a git worktree.
- Decide on evidence whether the test is stale or the code regressed. A regression in transcript scoping is a real budget-reading bug. T-3598 just changed checkpoint.sh and budget-gate.sh (session-keyed cache); do not undo it.
- Fix the wrong side and fill in the RCA and Decisions.
- Answer why a red unit suite stayed invisible. Is the unit suite run anywhere automatically? Check `.context/audits/unit-suite/LATEST.yaml` and the audit or cron that writes it. If other unit files are red on HEAD, list them and file ONE concern (`.context/concerns.yaml`) for the class. Do not fix them here.

Other workers are running concurrently:
- T-3580: lib/verdict_ledger.py, lib/reviewer/, agents/termlink/termlink.sh;
- T-3600: web/.
Do not touch those. If you change a vendored path, use `FW_VENDOR_ONLY="<your paths>" bin/fw vendor self` and commit only your vendored copies, by name.

Rules:
- Stage by name only; commit messages start with `T-3601:`.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* / FW_VENDOR_ALL flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` and `bin/fw work-on` as their own calls, with nothing else on the line.
- Run commands in the FOREGROUND and wait for them. Do NOT background a command and end your turn; you will not be woken up again.
- Tick Agent ACs as each one is proven. You may close the task (`bin/fw task update T-3601 --status work-completed`) if every gate passes without any skip flag.

Print only: commits, the breaking commit and the verdict (test stale or code regressed), per AC done or not, other red suites found, and test counts.
