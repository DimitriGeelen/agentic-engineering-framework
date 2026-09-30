# Independent code review: T-3580 `fw reviewer judge` (slice 3 of T-3557)

You are an independent reviewer with read-only access to /opt/999-Agentic-Engineering-Framework. You did not write this code. Do not modify anything, and do not run git commit or add, even in /tmp.

## Context
- T-3557 (GO): a human decides only risk. Everything else is judged by an independent agent reviewer who is never the producer.
- Slice 2 (T-3579) and its hardening (T-3581, four rounds of review, now AMBER with no high findings) built a verdict ledger. A row counts only with signed review-dispatch provenance, an introducing commit by a non-producer, and verified evidence hashes.
- Slice 3 (this one) is the verb that dispatches the reviewer. Commits: `git show 40dfb3a8c 590b9c56b 75cac55c5` (vendored copies in d06cb846e and 3ea85609f). Spec: `.tasks/active/T-3580-*.md`, including the six worker-attribution requirements in its Context. Tests: `tests/unit/t3580_judge_cli_test.py`.

## Check
1. **The parent never writes a verdict.** Is there any path where `judge`, the parent process, records or commits a verdict row itself, or where the worker's row could be written under the producer's identity?
2. **Hard classes.** tier0, act-in-the-world and sovereignty must never be dispatched. Could a mixed or reclassified criterion slip through?
3. **Unseen pages.** Is a green on a render criterion whose screenshot failed really impossible to use? Trace it to the ledger's apply, not just the brief.
4. **Unknown, never green.** A missing, malformed or wrong-task row: is it `unknown` everywhere?
5. **Rungs.** Does the IW-7 rung logic match docs/reports/T-3557-agent-reviewer-default.md §IW-7? Does the spend ceiling drop a rung visibly? Is the rung-5 "panel" honest about being single-vendor (tracked as a new task)?
6. **Tests.** Do they test properties with negative controls, or mocks that assert the mock?

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
