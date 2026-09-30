# Independent code review: T-3578 (slice 1 of T-3557)

You are an independent reviewer with read-only access to /opt/999-Agentic-Engineering-Framework. You did not write this code. Do not modify anything.

## What changed and why
- The operator ruled (T-3557, GO 2026-09-30) that a human reviews only RISK: Tier 0, irreversible actions in the outside world, and sovereignty or project direction. Everything else goes to an independent agent reviewer, which evaluates and may escalate.
- Slice 1 changes ROUTING and REPORTING only. It adds a bucket, REVIEWER_JUDGES, for render-surface, taste, unclassified and inception-decision criteria. tier0-or-bypass, act-in-the-world and sovereignty-field stay OPERATOR_ONLY.
- Nothing may close or tick a criterion because of the new bucket; that needs slices 2 and 3.

Commits: `git show 8f7219eea` (the change) and `f7a9f713b` (vendored copies). Spec: `.tasks/completed/T-3578-*.md`. Design: `.tasks/completed/T-3557-*.md` and `docs/reports/T-3557-agent-reviewer-default.md`.

## Check
1. **Safety.** Can any path now convert, tick or close a REVIEWER_JUDGES criterion without a verdict? Trace `fw task delegate` (lib/delegation_cli.py cmd_delegate) and any auto-tick path (reviewer auto-tick, T-1985).
2. **Carve-out order.** Is a criterion that is BOTH render-touching and tier0, act-in-the-world or sovereignty guaranteed to stay OPERATOR_ONLY? Look for an ordering in the classifier where a render or task-level check could return first.
3. **One encoding.** Is CLASS_TO_DELEGATION really the only routing definition? Grep for any second copy (audit.sh, doctor, web/, tools/).
4. **Rails.** Do the audit/doctor facts line and its consumers still parse after the new column, including any consumer that splits the TSV by position?
5. **CLAUDE.md.** Does the edited text accurately describe the code?
6. **Tests.** Do they test the property or a proxy? Is there a negative control?

## Answer format
```
VERDICT: green | amber | red
FINDINGS:
  - severity: high|medium|low
    where: <file:line>
    what: <defect>
    fix: <exact change>
OVERALL: <one sentence>
```
