You are **JUDGE PASS 2** in a three-role project value review (GATHERER → JUDGE → HUMAN).
Task: T-3370. Working dir: /opt/999-Agentic-Engineering-Framework.

Pass 1 has already classified the evidence and written
`docs/reports/VALUE-REVIEW-whole-repo-2026-09-16.md`.

**After pass 1 was dispatched, the operator issued a binding ruling that pass 1 could not
have seen.** Your entire job is to apply it. Nothing else.

# The ruling

It is recorded verbatim in `docs/reports/VALUE-REVIEW-whole-repo-2026-09-16-yardstick.md`
**§5 — Operator ruling**. Read that section first; it is binding and it outranks anything
pass 1 concluded.

In short: an item that is unused, unreferenced, or unwired has **three** possible
readings, not one —

- **A — wanted, but broken.** Non-use is a *symptom of the breakage*. → **ADD** (repair).
- **B — wanted, but never wired.** Implementation complete, nothing invokes it. → **ADD** (wire).
- **C — genuinely no longer wanted.** → **DELETE**, and only with an affirmative reason
  the *purpose* no longer needs it. An absence of references or telemetry is **not** such
  a reason.

# What to do

1. Read the yardstick §5, then the pass-1 report in full.
2. **Re-examine every DELETE row and every INVESTIGATE row.** For each, decide A, B or C.
   - If A or B → move it to ADD, reframed as the repair or wiring that is actually wanted.
     Keep the evidence refs. Say what capability it was reaching for.
   - If C → it stays DELETE, but the row must now **state why it is C** — the affirmative
     reason the purpose no longer needs it. If you cannot supply that reason from the
     evidence, it is not C.
3. Leave REFACTOR rows alone unless the ruling plainly changes one.
4. Do **not** re-gather. Do not grep the repo or open source files. Your inputs are the
   pass-1 report, the yardstick, and the six evidence files it cites, nothing else.

# Output

**Edit `docs/reports/VALUE-REVIEW-whole-repo-2026-09-16.md` in place.** Preserve its
structure and its section order. Then:

- Add a new section near the top, immediately after the verdict, titled
  **"Operator ruling applied (pass 2)"**, containing: the ruling in one sentence, a table
  of every row you moved (item · pass-1 axis · pass-2 axis · reading A/B/C · why), and a
  count of rows reclassified.
- Every DELETE row surviving pass 2 must carry a `reading: C` marker and its affirmative
  reason. Add a column if the table has none.
- If pass 1 proposed **no** DELETEs, say so explicitly and explain what that means —
  do not manufacture rows to look thorough.

Be honest about the direction of travel: if applying the ruling empties the DELETE axis
almost entirely, that is the finding, and it is worth stating plainly rather than
softening. Research is not authorization — nothing here is executed; the operator decides
each row.
