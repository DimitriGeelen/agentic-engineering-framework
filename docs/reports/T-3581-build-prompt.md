You are building T-3581 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Focus is T-3581 (started-work) and you own it while you run. Follow CLAUDE.md.

This is security hardening of a close path. Two independent reviewers returned RED on T-3579: docs/reports/T-3579-code-review-openai.md and docs/reports/T-3579-code-review-zai.md. Read both in full, plus .tasks/completed/T-3579-*.md and lib/verdict_ledger.py. The spec is T-3581's ### Agent criteria (.tasks/active/T-3581-*.md).

Order of work:
1. CONTAINMENT, in its own commit, first. Make the path fail closed: a row counts only with verified review-dispatch provenance. Nothing has that yet, so the path is off. Add a test that a hand-appended green row is refused. Commit it ("T-3581: containment — ...") before anything else.
2. Then the remaining criteria, in their listed order.

Provenance design notes:
- Slice 3 (T-3580, not built yet) will dispatch reviewers via `bin/fw termlink dispatch --task-type review`. Find where dispatch records live (`.context/dispatches.jsonl`, /tmp/tl-dispatch/<name>/meta.json) and what they carry (dispatch id, task-type, issuing session). Bind to the durable one.
- Provide a writer, `fw reviewer verdict record --dispatch-id <id> ...`, that slice 3 will call from inside the reviewer worker. It must refuse when the dispatch id is unknown or is not a review dispatch.
- Z.ai named the introducing-commit check. The reviewers' OVERALL lines say the mechanics are good and the trust model is not; keep the mechanics and fix the trust.
- Do not claim more than you prove. If some finding cannot be fully closed in a same-user environment, write that plainly in the task's ## Decisions and in the CLAUDE.md passage that describes the path.

Rules:
- Stage by name only; commit messages start "T-3581: ".
- No --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- Tick Agent criteria as you meet them, EXCEPT the last one (the re-review by both vendors; the parent session runs it). Write guarded ## Verification lines.
- Do NOT close the task; it has a Human criterion (the operator's risk acceptance). Leave it in started-work.

Print only: commits, which findings are fully closed vs mitigated-and-documented, test counts, anything unresolved.
