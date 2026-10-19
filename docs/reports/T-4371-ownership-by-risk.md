# T-4371 — Task owner decided by a creation-time risk assessment

Inception. Proposed by 832-Workflow-designer (operator decision there 2026-10-19, msgs d9c04ae8, 4b41e99a).
The go/no-go is the AEF operator's.

## Problem

Today a task created with `--owner human` (the documented way in `lib/init.sh`, `lib/setup.sh`) stays operator-only.
That holds even when it has no open Human criterion. T-4156 moves ownership to agent only after an independent reviewer's verdict. 832's operator
wants the reverse default:

1. At creation a risk assessment decides the owner: agent normally, human for high risk.
2. Agent-owned work is always judged at close by an independent reviewer: green closes; amber/red say what is
   missing; escalate makes the owner human.
3. Human-owned work (high risk from the start, or escalated) is reviewed by the operator.

## Evidence (from 832)

**T-931 measurement** (832, 2026-09-29; predicate tools/_t931-ownership.py, 11/11 teeth; 176 active tasks):

| | count |
|---|---:|
| owner: human | 112 |
| justified (at least one open Human criterion) | 67 |
| stale (no open Human criterion) | 45 |
| — never had a Human criterion | 35 |
| — every Human criterion already ticked by the operator | 10 |
| rubber-stamp queue (stale and every Agent AC ticked) | 13 |

10 of the 13 had been reported "completable, not closed" (CTL-029) for a month. A first, regex-based count was wrong
("35 and 3"): it counted the template's comment examples as open criteria. The measure must use the real parser.

**T-1127** (832, 2026-10-19): owner human → agent only after a verdict.
- The criterion was an independent screenshot review at 1024/1440/1920.
- Run 1 was amber: no defect, but the lower half of the view was never shown.
- After evidence was added, run 2 was green. The criterion was reworded, since `[REVIEW]` claimed the operator, and run 3 was green again (V-20261019-18fe0c6e), applied at close.
- The same day the operator was asked to tick rulings already recorded (T-347, T-732 H1) that `fw task delegate` classifies as reviewer-judgeable. That friction is what the proposal removes.

## Where it would live (agreed with 832)

At `fw task create` / `fw work-on`, calling the classifier in `lib/delegation.py`. It has the same three human-only
classes `fw task delegate` uses: act-in-the-world, tier0-or-bypass, sovereignty fields. That keeps one definition
for "needs a human" at creation and at delegation. 832 will call it rather than copy its rules.

## Open questions (IW-1..3 in the task)

1. **Review cost.** Every agent-owned close becomes an independent reviewer dispatch (T-3579/T-3580 path, rung by
   impact). Today most agent-owned tasks close on P-010/P-011 alone. Is a reviewer on every agent close intended,
   or only where the task carries a reviewer-judged criterion?
2. **Existing human-owned tasks.** Re-classify the backlog once (dry-run first), or apply to new tasks only?
3. **Input at creation.** The classifier reads criteria; at `fw task create` most tasks have none yet. It may have to
   classify from name and description, then re-run when criteria are written.

## Dialogue log

- 2026-10-19, 832 (d9c04ae8): proposal, three questions. AEF answered: (a) T-4371, (b) `lib/delegation.py` at create,
  (c) a local create-time default is compatible while high-risk tasks still start human and close gates stay.
- 2026-10-19, 832 (4b41e99a): agreed on (b) and (c); sent the T-931 and T-1127 evidence above.
