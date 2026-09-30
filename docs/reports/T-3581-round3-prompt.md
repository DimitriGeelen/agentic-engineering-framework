You are continuing T-3581 in /opt/999-Agentic-Engineering-Framework (branch bleeding-edge, main checkout, NO worktree). Focus: `bin/fw context focus T-3581` (it is started-work). You own it while you run. Follow CLAUDE.md.

The independent OpenAI re-review of your round-2 hardening is still RED: docs/reports/T-3581-rereview-openai.md. Read it in full. The Z.ai re-review was cut off before a verdict; its partial log is not usable. The path stays contained (off) meanwhile; keep it that way.

Fix every finding in the OpenAI re-review:
1. HIGH, content substitution: verify each row's canonical bytes against the commit that introduced it, on the accepted history. Refuse modified rows, duplicate ids, deleted rows (a withdrawal row that existed in history and is gone now must block, not silently vanish), and uncommitted replacements. The ledger becomes append-only as verified against git; audit checks history as well as current rows.
2. Audit uses the SAME structural+provenance validator as apply, for every row. Keep "historical integrity" separate from "current criterion eligibility", so legitimately superseded verdicts stay auditable and do not fail the audit.
3. Validate rows BEFORE digest-based selection; a malformed object naming a task/AC blocks that criterion instead of being filtered out.
4. Render gate: identify the specific render-review criteria (the [REVIEW] criteria that make the task render-surface; see lib/delegation.py:534, which currently classifies every non-risk criterion on a render task as render-surface) and require THEIR valid approval. Fix the test at tests/unit/test_t3579_verdict_ledger.py:654, which currently expects the wrong thing, and add the negative control: unrelated GREEN plus render AMBER fails check-render.
5. A missing verdict module refuses the close (update-task.sh:113) and makes the audit report a failure, not a skip.
6. Record the producer-issuer exception in T-3581's ## Decisions (it is still template-only there). Correct the CLAUDE.md wording so it does not overstate: audit cannot distinguish a coherently fabricated provenance chain made by a same-user agent. Say exactly what it does catch.
7. Worker attribution (the dispatch proves registration, not authorship): write the precise requirements slice 3 must meet into T-3580's Context. The fresh worker/session identity, reviewed revision, criterion digest, evidence and exact verdict contents are bound to the dispatch result. Do not build slice 3.

Each fix gets a test with a negative control. Rules:
- Stage by name only; commit messages start "T-3581: ".
- No --no-verify, --force, --skip-*, or FW_ALLOW_* flags.
- `bin/fw vendor self`, commit the vendored copies by name, then `--check`.
- Do not close the task; leave the re-review criterion and the Human criterion open.

Print only: commits, and per finding closed / mitigated-and-documented, plus test counts.
