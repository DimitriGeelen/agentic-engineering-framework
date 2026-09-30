You are triaging red unit-test files for OBS-587 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Your task is named at the end of this prompt. Run `bin/fw work-on <task>` alone first. Then read your task file (the file list and ACs) and OBS-587 in .context/concerns.yaml. Follow CLAUDE.md.

For each file in your list:
1. Run it alone, in the FOREGROUND: `timeout 600 bats tests/unit/<name>.bats`, or `python3 -m pytest tests/.../<name>.py -q`. Note the failing tests.
2. Find the breaking commit. Check `git log` on the test and on the code it exercises. Where it isn't obvious, bisect in a scratch copy (`git archive <rev> | tar -x -C $tmp`). Never check out old revs in the main checkout, and do not create a worktree.
3. Classify: STALE TEST (the code changed on purpose and the test wasn't updated; cite the commit or task that made the change) or CODE REGRESSION (behaviour a user or gate relies on broke).
4. Stale test: fix the test only. The file must then pass in isolation with no skips. Commit per file or per small group, by name: `<task>: <file> — stale since <commit>`.
5. Code regression: do NOT fix it. Create one bug task per regression, with a description naming the failing test, the breaking commit and the evidence: `bin/fw task create --name "..." --description "..." --type build --owner agent --horizon next --tags "bug,OBS-587"`.
6. Record every file's verdict in your report file, `docs/reports/<task>-triage.md`: a table with file, failing tests, breaking commit, verdict, and action (the fixed commit or the new task id).

Time-box: at most 20 minutes per file. If a file is still unclear after that, mark it UNCLEAR in the report with what you found, and move on.

Other workers are concurrently editing:
- lib/tier0_action.py, agents/context/check-tier0.sh, agents/git/lib/hooks.sh;
- the nightly unit-suite runner and its audit check (agents/audit/);
- lib/verdict_ledger.py, lib/reviewer/, agents/termlink/termlink.sh.
Do not touch them. If a red test covers one of those, classify it but don't fix it. Note that in the report.

Rules:
- Stage by name only; commit messages start with your task id.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* / FW_VENDOR_ALL flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` and `bin/fw work-on` alone on their line.
- Run every command in the FOREGROUND and wait for it. Never background a command and end your turn; you will not be woken up again.
- Never write a bare `! cmd` assertion in bats; use `run …; [ "$status" -ne 0 ]`.
- Tick ACs as each one is proven. Do not close the task.

Print only: commits, counts (stale fixed / regressions filed with task ids / unclear), and the report path.

Your task:
