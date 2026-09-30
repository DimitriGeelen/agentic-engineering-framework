# Second-model-family check: T-3580 after round 5 `fw reviewer judge` (slice 3 of T-3557)

Round 1 RED: docs/reports/T-3580-code-review-openai.md; round 2 RED: docs/reports/T-3580-round2-review-openai.md. Read both. Round 3 reviews: docs/reports/T-3580-round3-review-openai.md (RED: public `complete` command lets a caller manufacture a signed completion; panel counts backend ids as vendors; wait/sign race) and docs/reports/T-3580-round3-review-zai.md (GREEN, lows). Round 4 review: docs/reports/T-3580-round4-review.md (AMBER: vendor free text; never-run dispatch; finalised marker; dispatch-results; completion not append-only). Round 5 commits: `git show 48289f47a 0bc5251cf`; part of round 5 landed in T-3595 commit ba35b3559 (termlink.sh), see T-3580 Decisions. The parent ran the suites: 271 pytest + 11 bats pass. Round 3 commits for context: 4bc020e86 878861019. The builder claims every round-2 finding is closed; the runtime (agents/termlink/termlink.sh run.sh) now signs the worker completion after exit, and `record` signs nothing. **Verify with `git show 4bc020e86 -- tests/` that no assertion was weakened; round 2 did weaken three, and round 3 claims to restore them as separate specific tests.** 211 pytest and 11 bats pass (parent-run). Principle to judge against: the LEDGER (lib/verdict_ledger.py shared validator) enforces; the judge CLI only asks.

You are an independent reviewer with read-only access to /opt/999-Agentic-Engineering-Framework. You did not write this code. Do not modify anything, and do not run git commit or add, even in /tmp. Reason from the code and git show.

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


**You are the second model family.** The Claude reviewer returned GREEN on round 5 (.context/dispatch-results/t3580-r5-review-7e8ad45c349d.md; read it) with four lows. Both earlier reviewers asked that a different model family check this before the verdict path goes live. Look especially for what a Claude reviewer reviewing Claude-written code could share a blind spot on: whether any path lets the PRODUCER close its own task, or lets three same-family seats count as three vendors.
