You are building T-3578 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). It is slice 1 of T-3557 (GO recorded 2026-09-30). Focus is T-3578 (started-work) and you own it while you run. Follow CLAUDE.md.

Read first:
- .tasks/active/T-3578-*.md: its Context and ### Agent criteria are the spec.
- .tasks/completed/T-3557-*.md: the Decision, and IW-1, IW-2, IW-5.
- docs/reports/T-3557-agent-reviewer-default.md

Code: lib/delegation.py (CLASS_TO_DELEGATION at line ~79, classify_task, surface_scan, surface_verdict), lib/delegation_cli.py, and the audit/doctor rails that read `fw delegation surface --facts` (grep check_delegation_surface in agents/audit/audit.sh and the doctor). Tests: grep tests/ for delegation.

The one design constraint that matters: this slice changes ROUTING and REPORTING only. Nothing may close or tick a criterion because of the new bucket; closing needs an independent verdict, which slices 2 and 3 (T-3579, T-3580) build. Keep one encoding: the class->routing map lives in lib/delegation.py, and every reader imports it.

Update CLAUDE.md where it describes delegation (§Human Task Completion Rule "Delegation, when the open criteria are deterministic", and §AC Classification Guidance "Getting it wrong at author time is now recoverable"). Say that render, taste, unclassified and inception-decision criteria are now judged by an independent agent reviewer (T-3557), and that tier0/act-in-the-world/sovereignty stay human. Keep the edit tight. Run tests/lint/config-registry-parity.bats.

Rules:
- Stage by name only; commit messages start "T-3578: ".
- No --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- Finish with `bin/fw vendor self`, commit the vendored copies by name, then `bin/fw vendor self --check`.
- Tick each Agent criterion as you meet it. Write guarded commands into ## Verification (`> /tmp/.out 2>&1 && grep -q passed /tmp/.out && ! grep -q failed /tmp/.out`, and the bats form from the template).
- Then close with `bin/fw task update T-3578 --status work-completed`. If a gate refuses, stop and report why; do not bypass.

Print only: commits, the new surface counts by routing bucket (before -> after), test results, anything unresolved.
