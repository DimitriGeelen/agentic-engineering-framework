You are building T-3621 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3621` alone first. Then read the task file (Context, ACs). Also read T-3602's changes to the unit-suite runner and to the audit check that reads its report: find them with `git log --oneline -8 -- agents/audit/`. And read OBS-587 in .context/concerns.yaml. Follow CLAUDE.md.

Goal: pre-push stops blocking on the PRE-EXISTING red backlog, but still blocks on NEW breakage, and the backlog never reads as green anywhere.
- The baseline is a committed file. Pick the location, e.g. `.context/audits/unit-suite/baseline.yaml`, and generate it from today's `.context/audits/unit-suite/LATEST.yaml`.
- Map each entry to its owning triage task where one exists: docs/reports/T-3603-triage.md, docs/reports/T-3604-triage.md, T-3611..T-3617, T-3605..T-3609. Otherwise mark it "untriaged".
- Expiry defaults to 14 days.
- The pre-push section and the full audit must differ ONLY in how baselined reds are graded (WARN versus FAIL). Find how audit.sh knows it is running under pre-push (`--section structure`, or an env flag), and reuse that. Do not invent a second path.
- The baseline may only shrink without the operator: a regenerate verb drops entries that turned green, and adding entries needs `--i-am-human`.
- Write the tests listed in the ACs first. Each must be red on the current code.
- Finish by running `git push origin bleeding-edge` in the FOREGROUND, without `--no-verify`. The push itself is allowed: it is a fast-forward to the sanctioned branch. If it is still blocked, report the exact FAIL lines and stop. Never bypass it.

Other workers may be running concurrently on lib/verdict_ledger.py, lib/reviewer/, agents/termlink/termlink.sh, lib/tier0_action.py, agents/context/check-tier0.sh and agents/git/lib/hooks.sh. Do not touch those. If you edit agents/audit/audit.sh, check `git diff` first for another worker's uncommitted hunk; if there is one, stop and report.

COMMIT WITH AN EXPLICIT PATHSPEC: `git commit -m "..." -- <paths>`. All workers share one git index. With `bin/fw vendor self`, use `FW_VENDOR_ONLY="<your paths>"` and commit only your vendored copies.

Rules:
- Commit messages start with `T-3621:`.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* / FW_VENDOR_ALL flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` and `bin/fw work-on` alone on their line.
- Run everything in the FOREGROUND. Never background a command and end your turn.
- Tick ACs as each one is proven. Do not close the task.

Print only: commits, per AC done or not (with the proof), the baseline size (entries, triaged versus untriaged), and the push result.
