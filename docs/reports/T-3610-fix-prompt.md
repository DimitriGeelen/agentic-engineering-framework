You are fixing T-3610 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3610` alone first. Then read the task file (Context, ACs), T-2787 (.tasks/active/T-2787-*.md, its Findings) and T-3303. Follow CLAUDE.md.

A test is still writing to the filesystem root. On 2026-09-30:
- `/.git/config` gained `[user] email = t@t, name = T` at 22:30:22 (+0200);
- `/.git/hooks/commit-msg` was rewritten at 22:30:59.
72 test files set `user.email t@t`.

Find the culprit by evidence:
- Which tests run `git config user.email t@t` and then install hooks (`fw git install-hooks`, hooks.sh) with a target that can resolve to `/`? Look for an unset or empty variable, `cd "$X"` where X can be empty, or `git -C "$X"`.
- Compare the commit-msg hook content in `/.git/hooks/commit-msg` with the generator's output for clues (read-only).
- Check which test files ran around 22:30 yesterday: .context/audits/unit-suite/, the TermLink dispatch dirs under /tmp/tl-dispatch/*/result.jsonl, and worker logs.

SAFETY:
- Do NOT delete, modify or clean anything under `/`. Clearing it is the operator's call.
- To reproduce, point the suspect test at a FAKE root (a tmp dir standing in for `/`, e.g. by setting the variable that leaked to a tmp path). Never run a suspected test in a way that could write to the real `/` again.
- Record the mtimes of `/.git/config` and `/.git/hooks/commit-msg` before and after your own test runs. They must not change.

Then fix the source and its siblings, and add the structural guard with a negative control (see the ACs). Candidates: a shared bats helper that refuses root targets, and/or a `bin/fw test lint` rule. Pick the one that catches the class, not just this instance, and record the choice in Decisions.

Other workers are running concurrently:
- T-3593 round 4: lib/tier0_action.py, check-tier0.sh, agents/git/lib/hooks.sh;
- T-3580 round 7: lib/verdict_ledger.py, lib/review_policy.py, lib/reviewer/, agents/termlink/termlink.sh;
- T-3602: the nightly unit-suite runner and its audit check;
- T-3603: triage of tests/unit files approvals*..lib_review*.
Do not touch their files. If the leak is in hooks.sh itself, stop and report rather than editing it. With `bin/fw vendor self`, use `FW_VENDOR_ONLY`, and commit only your vendored copies, by name.

Rules:
- Stage by name only; commit messages start with `T-3610:`.
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* / FW_VENDOR_ALL flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` and `bin/fw work-on` alone on their line.
- Run everything in the FOREGROUND. Never background a command and end your turn; you will not be woken up again.
- Tick ACs as each one is proven. Do not close the task.

Print only: commits, the culprit test(s) with evidence, the guard chosen, per AC done or not, and the root mtimes before and after.
