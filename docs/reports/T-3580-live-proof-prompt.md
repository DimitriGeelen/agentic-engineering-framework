You are doing the LIVE PROOF for T-3580 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Run `bin/fw work-on T-3580` alone on its line first. Read:
- the T-3580 task file: the last open Agent AC (the live proof), and the Decisions, including "2026-10-01 — Operator GO";
- docs/reports/T-3582-live-runs.md;
- docs/harnesses.md;
- CLAUDE.md §Human Task Completion Rule (the delegation and verdict-ledger paragraph).
Follow CLAUDE.md.

The operator GO'd T-3580 on 2026-10-01. T-3582 made claude, codex, opencode (Z.ai) and antigravity real review seats, and a three-vendor panel passed live on a fixture. Now prove the real path once: one REAL open reviewer-judged criterion on a REAL task, judged by `fw reviewer judge` at its REQUIRED rung, recorded in the verdict ledger, and closed through T-3579 by `update-task.sh --status work-completed`, with NO bypass flag.

1. Pick the criterion.
   - Run `bin/fw reviewer surface` and `bin/fw task delegate T-XXXX --dry-run` on the candidates.
   - Choose ONE open REVIEWER-JUDGES criterion that a reviewer can judge from text, HTML or command output. The new seats cannot see screenshots (docs/harnesses.md), so avoid purely visual layout criteria.
   - Candidates: T-3600's render criterion (counts equal between the tile and /approvals, the tile is populated; checkable by curl against `$(bin/fw watchtower url)`), T-3627's (pages respond, render the same tables), or a taste/unclassified criterion elsewhere.
   - State its required rung (`task_required_strength`) BEFORE judging, and record why you chose it.
2. Run `bin/fw reviewer judge` on it, as documented. All seats are internal-class; log the cost with `bin/fw review cost log` for each seat.
3. Outcome:
   - **green:** the verdict row is committed by the path as designed. Then run `bin/fw task update <task> --status work-completed`, and show the tick and the ownership change with no `--skip-*` flag.
   - **amber, red or escalate:** that is a valid outcome. Record it honestly, do not retry it into green, and pick ONE other candidate only if the first one escalated purely because of the screenshot limitation (say so).
4. Tick T-3580's live-proof AC only if a real criterion was closed this way. Then close T-3580 if every gate passes without a skip flag. If it does not close, report exactly which gate refused and why.

Do not touch other workers' files: lib/tier0_action.py, check-tier0.sh, hooks.sh, bin/fw, bin/claude-fw, lib/pickup.sh, the init templates. Do not edit any source file unless the proof exposes a defect. If it does, STOP and report it rather than patch it here.

COMMIT WITH AN EXPLICIT PATHSPEC: `git commit -m "T-3580: ..." -- <paths>`. All workers share one git index.

Rules:
- NEVER use --no-verify, --force, --skip-*, or FW_ALLOW_* flags. If a gate blocks you, stop and report it.
- Run `bin/fw context focus` and `bin/fw work-on` alone on their line.
- Run everything in the FOREGROUND. Never background a command and end your turn.

Print only: the criterion chosen and its required rung, the seats and their verdicts, the ledger row and commit, whether the target task's criterion ticked and what changed, and whether T-3580 closed.
