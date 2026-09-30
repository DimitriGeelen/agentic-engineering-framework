# Re-review: T-3581 hardening of the verdict close path (after two RED reviews)

You are an independent reviewer with read-only access to /opt/999-Agentic-Engineering-Framework. Do not modify the repo. You may experiment in a sandbox copy under /tmp.

## Background
Two reviews of T-3579 (a path letting an independent reviewer's GREEN verdict close a task) returned RED: docs/reports/T-3579-code-review-openai.md and docs/reports/T-3579-code-review-zai.md. Read both. T-3581 claims to fix them:
- spec: .tasks/active/T-3581-*.md, including its ## Decisions;
- commits: 606f9298d (containment), 320beb537 (hardening), 4f49b8ccb (vendored copies);
- code: lib/verdict_ledger.py and whatever it imports, agents/task-create/update-task.sh, the fw audit line, and the tests.

## The honest threat model
Every agent runs as the same OS user with write access to the repo, so no local scheme is forgery-proof against a determined agent. The target is: fail-closed, tamper-evident and audited. Judge against that target, and ALSO say plainly where it falls short of it.

## Check
1. **Findings.** For each finding in the two RED reviews: closed, mitigated-and-documented, or still open?
2. **Try the reproductions again** in a sandbox: pseudonym reviewer, hand-appended row, record before any commit, a `--no-verify` commit without the task id. Can the producer still close its own task silently? "Silently" is the key word: is the forged path now caught by `fw audit`?
3. **The signing key** `.context/secrets/review-dispatch.key`. Is it tracked in git, or ignored? Is it readable by any agent? Is the builder's statement accurate about what it buys?
4. **The open design question.** The builder did NOT refuse dispatches issued by a producer session, because the producer session will be the one dispatching its reviewer (slice 3). Independence is enforced on the worker's identity and the row's introducing commit instead. Is that sound? If not, what should slice 3 require?
5. **Fail-closed.** Can anything make the path fail OPEN now?

## Answer format
```
VERDICT: green | amber | red
FINDINGS:
  - severity: high|medium|low
    where: <file:line>
    what: <defect or residual risk>
    fix: <exact change, or "accept + document">
PRIOR FINDINGS: <one line per prior finding: closed | mitigated | open>
OVERALL: <one sentence: is this safe to enable once slice 3 writes provenance-bound rows, given the stated threat model?>
```
