# T-4024: the servicing loop for "nothing to verify"

**Status:** design, awaiting operator yes. Filed 2026-10-10.
**Principle (operator, 2026-10-10):** a check that yields nothing is a signal, not a pass. Either the check is useless, or it is blind to what matters (exposure). Both are remediated.

## 1. What enters the loop

| Source | When |
|---|---|
| A `# verification: none — <reason>` declaration | at close of a build/refactor/decommission task (option D gate) |
| A logged bypass `FW_ALLOW_EMPTY_VERIFICATION=1` | at close, always (a bypass is the strongest signal) |
| A Verification block that only ran vacuous commands (`true`, a bare `echo`, `exit 0`) | at close, flagged by a static check |
| Backfill: the 238 historical empty closes | once, newest first |

Each entry is one row in an append-only ledger, `.context/audits/verification-servicing.jsonl`:
- task id;
- what was changed (files from the task's commits);
- the declared reason;
- the source (from the table above);
- the date.

## 2. Lifecycle of one entry

```
  open ──► proposed ──► decided ──┬─► remediating ──► closed (check added / evidence in place)
   │          │                   ├─► accepted risk ─► closed (reason recorded)
   │          │                   └─► rejected ─────► remediating (the reason did not hold)
   └─ aged > 7 days without a proposal ─► escalated (shown at the top)
```

1. **open:** the row exists. Nothing has looked at it yet.
2. **proposed:** an agent has investigated and attached ONE proposal:
   - **(a) add a check:** the exact command. Often a test that already exists and was never wired into Verification.
   - **(b) needs other evidence:** the change is real but no shell command can see it. The agent names which evidence:
     - a unit/bats test to write;
     - a T-4023 field check (deterministic probe, observed count, or judged question);
     - a human look (a Human AC on a follow-up task).
   - **(c) accept:** the reason holds. Nothing changed that could break, e.g. a typo fix in prose. The agent says why.
   - **(d) reject:** the reason does not hold. The agent says what *is* checkable.
3. **decided:** the operator accepts or redirects the proposal (for now; later the independent reviewer, see §5).
4. **remediating:** (a), (b) and (d) become a follow-up task. It is linked from the row and has a real Verification block of its own, so the fix cannot itself close empty.
5. **closed:** the follow-up task closed with its check passing, or the risk acceptance is recorded with who accepted it and why.

**Every entry ends closed. None stays open silently.** That is the point of the loop.

## 3. Both cases are serviced

- **Case 1, a check exists but was not written:**
  - Fix the instance: add the check to a follow-up task so it actually runs.
  - Fix the cause: if (a) dominates the ledger, authors are not wiring tests into Verification. The upstream remedy is at authoring time, e.g. the task template or a close-time hint that names the test files the task's commits touched.
- **Case 2, nothing a shell can see (exposure):**
  - Fix the instance: get the other evidence (a test written, a field check, a human look), or record an explicit risk acceptance.
  - Fix the cause: if (b) dominates, there is a class of change we cannot verify at all. That class goes to T-4023 as a field-check kind, or becomes a new test harness, so the next change of that kind is checkable.

## 4. The loop watches itself

The same principle applies to the loop: if it produces nothing, it is broken or blind.

- **Declarations exist but no proposals for > 7 days:** the servicer is not running. The audit WARNs.
- **Proposals are almost all (c) accept:** either the declarations are honest (fine), or the agent is rubber-stamping. The reviewer samples a few (c) items each week.
- **Zero declarations for a long stretch while tasks close:** either authors are writing vacuous commands instead (the static check in §1 catches that), or the gate is not firing. The audit cross-checks closes against the gate log.

## 5. Who decides

- **Now:** the operator decides each proposal. Agents do the investigation, so the operator's job is a yes/redirect per item, batched.
- **Later:** once the operator has seen enough proposals to trust them, decisions move to the independent reviewer agent (the D-626 delegation path). The operator then sees only escalations: (b) items that need a human look, rejected reasons, and aged items.

## 6. Where the operator sees it

Both places, because they answer different needs:
- **Watchtower /approvals:** a "Verification servicing" section listing open/proposed items, each with the agent's proposal and accept/redirect buttons. This is where decisions are made.
- **Handover:** one line with the counts (open, proposed, aged) and a link. This is where it is noticed.
- **CLI:** `fw verification servicing [list|propose|decide]` for agents and headless use.

## 7. Worked examples

- **T-3997** (budget-gate fix, closed 2026-10-08 with template only). The likely proposal is (a): the budget-gate suites (`tests/unit/t3989_budget_critical_handover.bats` and siblings) cover this code, so the check is "run them".
- **T-3958** ("Cut release v1.8.5", closed empty). This looks like "nothing to verify", but it is (a): the tag exists, master equals the tag, and the GitHub release exists. All three are checkable in one line each. A release cut is a good example of a reason that does not hold.
- **A wording-only change to a doc paragraph:** (c) accept, reason recorded.
- **A change to how mail is typed into a terminal** (T-4003-like): partly (a) (unit tests), partly (b), since live delivery is only provable in a real session. That becomes a T-4023 observed field check.

## 8. Build order

1. The gate with the declaration line (option D), plus the ledger row on each declaration or bypass.
2. The ledger plus the `fw` verb (list / propose / decide), and the audit WARN for aged items.
3. Agent pre-investigation (a TermLink worker per batch, review-type, read-only), writing proposals.
4. The Watchtower /approvals section and the handover line.
5. Backfill the 238, newest first.
6. Later, by operator decision: hand decisions to the reviewer agent.
