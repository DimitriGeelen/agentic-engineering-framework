# T-3829: enforce the dialogue log for decision walkthroughs

Origin: 1409-sprind proposal, 2026-10-01 (their T-1664): a dialogue file per decision
walkthrough, operator quoted verbatim, agent self-corrections marked, a checker run from
`## Verification` so the task cannot close until the dialogue is committed.

## Measurement 2026-11-19

- C-001 (CLAUDE.md §Inception Discipline item 7) already asks for a `## Dialogue Log` in
  inception research artefacts. Nothing checks it: the commit-msg hook only requires that a
  `docs/reports/T-XXX-*.md` exists.
- 189 of 1,143 reports in docs/reports/ carry a Dialogue Log; 21 completed inceptions do.
- Today's walkthrough of the ready inceptions: the operator's rulings on T-3240, T-3496 and
  T-4834 were recorded only because the agent wrote them down by hand.

## Dialogue Log

### 2026-11-19 — walkthrough of the ready inceptions, item 4 of 6

**Agent presented** four options: (1) GO narrow — enforce the existing C-001 log, on by
default for inceptions (checked before decide), opt-in key for other tasks, log stays in the
research report; (2) GO as 1409 proposed — separate per-walkthrough file and checker;
(3) NO-GO; (4) not yet. Recommended (1).

**Operator, verbatim:** "1"

## Verdict and scope for the build task

GO, narrow:
1. `fw inception decide` (and the Watchtower decide path) refuses when the inception's
   research report has no `## Dialogue Log` with at least one quoted operator line.
2. A frontmatter key (for example `dialogue_log: required`) makes the same check a close gate
   for any other task.
3. The log lives in the task's research report; no new folder.
4. The handover lists open walkthroughs whose log is missing.
