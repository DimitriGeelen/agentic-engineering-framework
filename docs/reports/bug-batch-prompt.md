You are fixing a BATCH of independent bug tasks in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Your task ids are listed at the end. Work them ONE AT A TIME, in the order given. One bug = one task: never mix fixes across tasks in one commit.

For each task:
1. Run `bin/fw work-on T-XXXX` alone on its line. Read the task file: its name, description and evidence.
2. If its Acceptance Criteria are placeholders, write real Agent ACs FIRST, using the Edit tool on the task file:
   - a test that reproduces the bug (red before the fix);
   - the fix;
   - a "no regression in the neighbouring suites" criterion.
   The G-020 gate blocks source edits until you do. Fill `## RCA` (symptom, root cause, why it was structurally allowed, prevention).
3. Reproduce the bug with a test first (red), then fix it (green). Keep the change minimal.
4. If you changed a vendored path (bin/, lib/, agents/, policy/, web/, .tasks/templates/), run `FW_VENDOR_ONLY="<your paths>" bin/fw vendor self` and commit those vendored copies too.
5. Commit with an EXPLICIT PATHSPEC: `git commit -m "T-XXXX: ..." -- <paths>`. All workers share ONE git index.
6. Tick the Agent ACs as each is proven. Close the task with `bin/fw task update T-XXXX --status work-completed` only if every gate passes WITHOUT any skip flag. If a gate refuses, leave the task open and say why.
7. If a bug turns out not to reproduce, record the evidence and leave the task open for the parent.

Concurrent workers:
- T-3582: agents/termlink/termlink.sh, lib/verdict_ledger.py, policy/review-backends.yaml, docs/harnesses.md;
- T-3593: lib/tier0_action.py, agents/context/check-tier0.sh, agents/git/lib/hooks.sh, bin/fw;
- T-3635: .context/project/objectives.yaml and the arc YAMLs;
- a second bug-batch worker on different tasks.
Do not touch those files. If your fix needs one of them, stop that task and report.

Rules:
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* / FW_VENDOR_ALL flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` and `bin/fw work-on` alone on their line.
- Run everything in the FOREGROUND. Never background a command and end your turn; you will not be woken up again.
- Never write a bare `! cmd` that is not the last statement of a bats block. Bats fixtures load tests/test_helper.bash, or source tests/git_fence.bash.
- Never touch anything outside this repo, and never touch the filesystem root.

Print only, per task: closed / open (why), commits, the proving test, and any new bug found (file it with `bin/fw task create`; do not fix it).

Your tasks, in order:
