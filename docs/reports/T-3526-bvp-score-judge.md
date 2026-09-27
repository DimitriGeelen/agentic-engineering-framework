# T-3526 — the BVP score judge agent

Slice 2 of 3 under T-3524's GO (D-662). Restores producer-not-judge by
separating parties: `agents/termlink/bvp-estimator/estimator.py` proposes
`bvp_scores_proposed:`; this task builds the judge that reviews that proposal.
Neither party writes `bvp_scores:` — that stays the human's door via `fw bvp
confirm` (T-1924), protected by the T-3523 sticky guard from either side.

## What shipped

| File | Role |
|---|---|
| `lib/bvp_judge.py` | Core judge. Imports `lib/judge_verdict.py` for the whole verdict vocabulary; defines none of its own. Three independently-testable checks: `check_presence`, `check_sufficiency`, `check_goal_hierarchy`, combined by `judge_task()`. |
| `lib/bvp_judge_cli.py` | Inline CLI (`python3 -m lib.bvp_judge_cli T-XXX [--json]`). Read-only. |
| `lib/bvp_judge_dispatch_cli.py` | Dispatch CLI, a structural copy of `lib/reviewer/dispatch_cli.py` (T-1951) — same `TermLinkWorker`, same `fw bus post` shape, own single-hop sentinel (`FW_BVP_JUDGE_IN_DISPATCH`). |
| `lib/bvp.sh` | Wired `fw bvp judge T-XXX [--json]` and `fw bvp judge T-XXX --dispatch [--timeout N] [--json]`, plus `--help` text and the top-level `fw bvp --help` listing. |
| `tests/unit/test_bvp_judge.py` | 25 unit tests covering every AC, including the L-576 mutant-kill test. |
| `tests/unit/test_bvp_judge_dispatch.py` | 9 tests mirroring `test_reviewer_dispatch.py`'s coverage of the dispatch mechanism. |
| `tests/unit/t3526_bvp_judge_entrypoint.bats` | 5 tests running the REAL `bin/fw bvp judge` subprocess (no mocks, no override flags) against probe tasks. |
| `docs/reports/T-3526-bvp-score-judge.md` | This report. |

## The three checks, concretely

1. **Presence** — does `## Acceptance Criteria` carry at least one real
   (non-template, non-HTML-comment) checkbox item? If not: RED, guidance names
   the missing criteria.
2. **Sufficiency** — are the AC items substantive (≥15 chars after stripping
   `[PREFIX]` markers), and are there enough of them for the magnitude claimed
   (a driver scored ≥4 needs ≥2 substantive items, anything scored at all
   needs ≥1)? If not: AMBER, guidance names what's thin.
3. **Goal hierarchy** — resolves the written-down objective in order: task
   `description:`/`## Context` → arc's `description:`/`headline_mechanic:` →
   project's D1-D4 (`policy/value-drivers.yaml`). Two failure modes, both
   without inventing a keyword detector (T-3410 stays untouched, out of
   scope):
   - **Self-contradiction**: a driver scored >0 whose own rationale text says
     `no-signal` — the proposer's own evidence admits nothing was found, yet
     claims value anyway. This is the exact case D-662 names: *"a score
     claiming high value for work serving no stated objective is the case
     that must be caught."*
   - **Level mismatch**: a ≥4 claim resting only on the project-level
     fallback (no task description, no resolvable arc) has nothing narrower
     than "the project has objectives" behind a framework-level claim.

UNKNOWN fires only when no level resolves at all (task has no description/
Context, no arc, AND the project policy file is empty/unreadable) — a genuine
environmental failure, not "many tasks lack a goal." The control test
(`test_judgeable_task_does_not_come_back_unknown`) pins that a normal,
well-formed task does NOT fall into this bucket, so the judge cannot fail
safe into uselessness.

## Population and write boundary

- `judge_task()` calls `judge_verdict.reviewable()` first; closed
  (`work-completed`) tasks are skipped with a reason, never rescored (D-662
  IW-4).
- A task with no `bvp_scores_proposed:` entry is also skipped (nothing to
  judge) — distinct from a verdict.
- The module contains no write path at all — verified structurally
  (`test_module_has_no_write_function`) and behaviourally
  (`test_never_writes_bvp_scores_field` diffs the task file's bytes
  before/after `judge_task()` and asserts equality).

## Dispatch — reusing T-1951, not inventing a second mechanism

`lib/bvp_judge_dispatch_cli.py` is a line-for-line structural copy of
`lib/reviewer/dispatch_cli.py`: same `TermLinkWorker`, same worker-script
shape (`bin/fw bvp judge T-XXX --json` → `fw bus post`), same
non-blocking-Popen-then-return pattern, same single-hop recursion guard
(renamed `FW_BVP_JUDGE_IN_DISPATCH`). `fw bvp judge T-XXX --dispatch` in
`lib/bvp.sh` strips `--dispatch` and forwards to
`python3 -m lib.bvp_judge_dispatch_cli`, mirroring the reviewer's own
`--dispatch` routing in `bin/fw`.

## The "reachable on the real path" AC

Two of today's traps were guards that no live path reached (one keyed on
`MERGE_HEAD` absent at `pre-merge-commit` time, one behind a gate that refused
agents first) and a pass obtained with `--i-am-human` mistaken for evidence.
`tests/unit/t3526_bvp_judge_entrypoint.bats` runs the actual `bin/fw bvp
judge` subprocess — no mocks, no `--i-am-human`, no `FW_ALLOW_*` — against
three probe tasks (green, red/no-ACs, closed) plus a `--dispatch` recursion-
guard pin, all through the real CLI parsing and bash routing in `lib/bvp.sh`.
During build this was also run manually against the real `T-3526` and
`T-3524` tasks in this repo:

```
$ bin/fw bvp judge T-3526 --json
{"state": "green", ...}
$ bin/fw bvp judge T-3524 --json     # T-3524 is work-completed
{"skipped": true, "reason": "status 'work-completed' is closed; ..."}
```

## Out of scope, confirmed untouched

- `agents/termlink/bvp-estimator/estimator.py` (the estimator's detectors,
  T-3410) — zero changes, confirmed via `git status`.
- `lib/judge_verdict.py` — zero changes; the contract is consumed, not
  modified.
- Multi-model / multi-provider judge panel (D-662 IW-5) — not built, per the
  operator's explicit "not there yet, keep it simple for now."

## Verification run

```
bash -n lib/bvp.sh                                                    # OK
python3 -m pytest tests/unit/test_bvp_judge.py \
                   tests/unit/test_bvp_judge_dispatch.py -q            # 34 passed
bats tests/unit/t3526_bvp_judge_entrypoint.bats                        # 5/5 ok
bin/fw vendor self --check                                             # in sync
```

## Recommendation

**GO.** All 9 Agent ACs are ticked with evidence; verification is green;
`fw vendor self --check` is clean; T-3410 and the multi-model panel are
confirmed untouched. No Human ACs — read-only, internal tooling, deterministic
outcome, reversible (a new `lib/*.py` file with no external side effects).
