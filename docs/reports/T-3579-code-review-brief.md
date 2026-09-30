# Independent code review: T-3579 (slice 2 of T-3557). A new way to close tasks.

You are an independent reviewer with read-only access to /opt/999-Agentic-Engineering-Framework. You did not write this code. Do not modify anything.

## Context
- The operator ruled (T-3557, GO 2026-09-30) that a human decides only RISK: Tier 0, irreversible external acts, and sovereignty or direction. Everything else is judged by an independent agent reviewer who is never the producer.
- Slice 1 (T-3578) added the routing bucket REVIEWER_JUDGES in lib/delegation.py.
- Slice 2 (this one) lets a recorded GREEN verdict from an independent reviewer satisfy such a criterion and close the task through the normal gates, with no bypass flag.
- This is a new path by which work gets closed, so treat it as security-relevant: an agent that could forge or misuse it could close its own work unreviewed.

Commits: `git show 25d30001f ee3bcc42c` (vendored copies in 9dcdfc578). Spec: `.tasks/completed/T-3579-*.md`. Code: lib/verdict_ledger.py, agents/task-create/update-task.sh (apply_reviewer_verdicts, R-033, the P-013 render gate), the `fw reviewer verdict` CLI, and the tests tests/unit/test_t3579_verdict_ledger.py and t3579_verdict_close_path.bats.

## Try to break it
1. **Self-review.** Can the producing agent record a green verdict on its own task? The producer is derived from commit author, committer and Co-Authored-By identities plus an optional `producer:` field. Can it be evaded, for example by recording under a different `reviewer` string, or before any commit exists? Is there anything binding the `reviewer` field to a real independent process, or is it self-asserted? Say plainly what the check does and does not prove.
2. **Class bypass.** Can a green record satisfy a tier0, act-in-the-world or sovereignty criterion, for example through a criterion that is both render-touching and risky, a class computed at record time versus apply time, or editing the ledger file directly?
3. **Digest.** Does changing the criterion text invalidate the verdict everywhere it is used?
4. **Ledger integrity.** The ledger is a committed JSONL file. Could an agent append a line by hand and have it honoured? If so, is that detectable (audit), and is it at least logged?
5. **Failure modes.** A malformed ledger, missing evidence, or an unknown verdict: does each one fail closed (the criterion stays open)?
6. **Tests.** Do they include negative controls for each refusal, not just the happy path?

## Answer format
```
VERDICT: green | amber | red
FINDINGS:
  - severity: high|medium|low
    where: <file:line>
    what: <defect or residual risk>
    fix: <exact change, or "accept + document" with the wording>
OVERALL: <one sentence: is it safe to make this the normal close path?>
```
