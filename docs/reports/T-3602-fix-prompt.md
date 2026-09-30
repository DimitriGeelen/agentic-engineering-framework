You are fixing T-3602 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3602` alone first. Then read the task file (Context, Agent ACs, RCA), OBS-587 in .context/concerns.yaml, agents/audit/unit-suite.sh (or wherever T-3302 put the nightly runner) and the audit check that reads its report. Follow CLAUDE.md, including the cron-touching rule in §Verification Gate.

Goal: the framework can never again be blind to red unit tests because the nightly run times out.
1. Test first: a fixture report of a timed-out run with 2 recorded not-ok lines must make `fw audit` FAIL, naming both, plus "N of M ran". It is red on the current code.
2. Fix the audit side.
3. Measure where the run's time goes, using per-file durations. Add them to the report if they aren't there. Then make the run fit its budget: shard or parallelise, or cap each file with its own timeout and report it as timed-out. Record before and after wall time in Decisions.
4. Run the fixed nightly once on the live repo and compare its FAIL set with OBS-587. It may take a while: run it in the FOREGROUND with an adequate `timeout`, not in the background.
5. Do NOT fix the red suites themselves. Leave OBS-587's list for a separate triage.

Another worker (T-3580) is editing lib/verdict_ledger.py, lib/reviewer/ and agents/termlink/termlink.sh. Do not touch those. With `bin/fw vendor self`, use `FW_VENDOR_ONLY="<your paths>"` and commit only your vendored copies, by name.

Rules:
- Stage by name only; commit messages start with `T-3602:`.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* / FW_VENDOR_ALL flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` and `bin/fw work-on` alone on their line.
- Never background a command and end your turn; you will not be woken up again.
- Tick Agent ACs as each one is proven. Do not close the task.

Print only: commits, per AC done or not (with the proof), before and after wall time, the live run's FAIL count versus OBS-587, and test counts.
