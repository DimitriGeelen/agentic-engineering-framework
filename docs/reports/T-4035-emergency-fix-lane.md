# T-4035: Emergency fix lane

**Status:** proposal, first instance in progress (T-4032 as v1.8.9). Filed 2026-10-10.
**Origin:** the operator, while T-4032 (claude-fw killing sessions mid-turn, 1409's 5th cutoff) had to reach master. "We need an emergency fix process, besides Bleeding Edge and Master."

## Why a third lane

The release train has two lanes:
- **bleeding-edge:** development;
- **master:** releases, fast-forward only.

T-4020 adds the rule that master only receives fixes verified in the field.

An emergency breaks the shape: one fix must reach consumers now, while bleeding-edge carries other work that is not yet verified. Fast-forwarding master would ship all of it. Waiting for the whole candidate to mature leaves consumers exposed.

## The lane

```
master (vX.Y.Z) ──► hotfix/vX.Y.Z+1  (only the fix's code paths)
                         │  review + targeted tests + field confirmation by the reporter
                         ▼
                    operator: "Release vX.Y.Z+1 (hotfix: T-NNNN only) to master now? yes/no"
                         │  yes
                         ▼
master fast-forwards to the hotfix commit, tag vX.Y.Z+1, GitHub release
                         │
                         ▼
merge master back into bleeding-edge (so bleeding-edge contains master again;
the next normal release is a fast-forward as before)
```

## Rules

1. **Who declares it.** The operator, or the agent with the operator's yes. Criteria:
   - data loss or lost work in the field;
   - a security exposure;
   - or a broken core path (sessions, commits, gates) at a consumer.

   It is recorded on the task (`emergency: true` plus the reason).
2. **The branch** is cut from master, never from bleeding-edge.
   - It carries only the fix's code, its tests and their vendored copies. No task records, no unrelated changes.
   - The fix is first committed and pushed on bleeding-edge as usual. The hotfix applies the same change to master's code, so both lanes hold one fix.
3. **Checks before the release question.** All are required, and all are faster than a normal candidate:
   - the fix's own regression tests, which must fail on the old code;
   - the suites around the changed files, run on the hotfix branch itself;
   - one independent review (codex or another vendor);
   - field confirmation by the reporting project where possible. They run the hotfix and report that the failure is gone. If the reporter cannot confirm quickly, the operator decides whether to ship on review alone, and that choice is written on the task.
4. **The release question** is explicit, with the dry run shown: "Release vX.Y.Z+1 (hotfix: T-NNNN only) to master now? yes/no".
5. **Merge-back** happens immediately after the release. Master is merged into bleeding-edge, so the invariant "bleeding-edge contains master" holds and `fw release tag-and-release` keeps working.
6. **Announcement** to every consumer: what it fixes, the tag, and the upgrade line. The reporter is told first.

## Tooling (later, once the manual run has worked once)

`fw release hotfix T-NNNN [--dry-run]` would:
- cut the branch;
- apply the task's code paths;
- run the named suites;
- print the release question;
- on `--confirm`, fast-forward master, tag, merge back and announce.

Until then the steps are manual and logged here.

## First instance: T-4032 to v1.8.9

- **Fix:** committed on bleeding-edge as 661c026f3. The push is waiting on the full unit-suite gate.
- **Applies cleanly to v1.8.8** (simulated with git merge-tree): the five code/test files merge without conflict.
- **Review:** codex ran 4 rounds:
  - Round 1, DO-NOT-SHIP: another session's idle flag counted; a long wrap-up let the restart expire; the TermLink path killed at once; an early handover counted.
  - Round 2, DO-NOT-SHIP: an mtime slack was wrong in both directions. Measured: Claude Code appends bookkeeping 0.2–5.3 s after every Stop. A pre-signal handover qualified, and one test was vacuous.
  - Round 3, SHIP-WITH-CHANGES: a natural exit could lose the restart.
  - Round 4, SHIP.

  All four reports are in docs/reports/T-4032-codex-review*.md. Each finding was fixed with a test that fails on the code before it, and the rejected-Stop test was mutation-checked.
- **Hotfix branch** `hotfix/v1.8.9`, built from a temporary index without touching the main checkout:
  - v1.8.8 (f0fc58393) → d5ce92d7a (the fix: 8 files, vendored copies identical) → b82294243 (VERSION 1.8.9).
  - Master fast-forwards to it.
  - 85/85 related tests pass on the exported hotfix tree, i.e. against v1.8.8's code, not bleeding-edge's.
- **Lessons from the first run:** bleeding-edge pushes were held up twice by my own regressions from another task (T-4024 fixtures, and the template-hash list), each surfacing only in the full suite. The lane should run the full suite on the hotfix tree, not just the related suites, before the release question.
- **Full suite on the hotfix tree** (operator chose option b; a local clone of `hotfix/v1.8.9` in scratch, no worktree), 2026-10-10:
  - **Totals:** bats 6729 tests / 95 failed; pytest 4112 / 7 failed. 65 failures are not in v1.8.8's baseline.
  - **Control:** the same 29 bats files were run one at a time on an identically prepared clone of v1.8.8. Only 3 failures differed, and run sequentially they reproduce identically on both clones: audit.bats 5/15 failing, t1719_ask_routing.bats 3/11 failing.
  - **Conclusion:** every failure is environmental to a scratch clone (no installed hooks, no deployed cron, no live corpus, no Watchtower, no ollama), and **none is attributable to the hotfix**.
  - **Lesson:** a hotfix suite run needs a control run of the base release in the same environment, or the result cannot be read.
- **Field:** 1409 has asked their operator. Their confirmation is pending.
- **Then:** the release question to the operator, the manual release steps, and the merge-back.
