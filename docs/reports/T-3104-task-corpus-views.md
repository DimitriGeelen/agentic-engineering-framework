# T-3104 — Lifting the task-corpus view set into a shared library

**Slice 1 of 3.** Slice 2 makes `agents/audit/audit.sh`'s duplicate-task-ID check
corpus-wide; this slice gives both consumers one definition to share.

## The problem this closes

A linked git worktree checks out its own snapshot of `.tasks/`. "The task corpus"
is therefore not one directory — it is the **union of every worktree's `.tasks/`**
plus the local view. `_task_view_dirs` computed that union, but it lived inside
`agents/task-create/create-task.sh`, so the **ID allocator was its only consumer**.

`audit.sh`'s duplicate-ID check (~line 553) scans only the main checkout. Three
IDs — **T-2505, T-2506, T-2428** — were minted twice on 2026-07-01 in two
worktrees and have been invisible to audit for seven weeks while it printed PASS.
This is **L-506 leg 2** (split filesystem views), origin **T-100202** (2026-07-21).

Verified before changing anything: the pre-lift function does union-scan all five
live views, and the allocator does consume it (`generate_id` at create-task.sh:257).

## Chosen location: `lib/paths.sh`, as `fw_task_view_dirs`

| Criterion | Evidence |
|---|---|
| Owns the variable the function reads | `paths.sh` is where `TASKS_DIR` is defined and re-derived (T-2289 sentinel logic). |
| Already holds the sibling worktree predicate | `fw_is_linked_worktree` (T-2435) sits immediately above; both answer "what is this git view?" |
| Both slice-1 and slice-2 consumers already source it | `create-task.sh:9` and `agents/audit/audit.sh:19`. Slice 2 needs **no new source line**. |
| Naming | `fw_` prefix, matching `fw_is_linked_worktree` and the shared-lib convention. |

Alternatives rejected: `lib/tasks.sh` (per-task lookup helpers — `find_task_file`,
`get_task_name`; this is a corpus-level question, not a task-level one) and
`lib/worktree.sh` (owned by T-3102 in flight, and it is the *landing-decision*
subsystem — see the two-answers note below).

## De-duplication decision: **DE-DUPLICATE**, first-occurrence order preserved

Pre-lift the function emitted the local view **twice** — once from
`git worktree list` (the main checkout is itself a worktree) and once from the
unconditional trailing `printf '%s\n' "$TASKS_DIR"`.

**Decision: de-duplicate inside the function.** Rationale: the incoming slice-2
consumer is a *duplicate-ID detector*. Handing a duplicate-ID detector the same
view twice would make every local task a duplicate of itself — the shared helper
must not ship that trap. The trailing unconditional append is **kept**, because it
is load-bearing for a different reason (below), not because it was a duplicate.

### Proof the allocator's result is unchanged

Two independent arguments:

1. **Structural.** The sole consumer was `done < <(_task_view_dirs | sort -u)` —
   it already collapsed the output to a **set**. De-duplication changes the
   multiset, never the set. `generate_id` then collects IDs into an array and
   applies its own `sort -n -u`, so ordering is irrelevant to it as well.
   (The `| sort -u` at the call site is now redundant and was removed.)

2. **Empirical, against the real 5-worktree corpus:**

   | | views emitted | unique views | next ID |
   |---|---|---|---|
   | **before** (`_task_view_dirs`) | 6 (local view twice) | 5 | **T-3106** |
   | **after** (`fw_task_view_dirs`) | 5 | 5 | **T-3106** |

   `diff <(before \| sort -u) <(after \| sort)` → **identical**. Next ID equal.
   Neither run created a task; `generate_id` was called directly in a harness.

## The trailing append is kept — and it is not the duplicate

`views+=("$TASKS_DIR")` runs unconditionally, outside the git branch. It carries
two guarantees that the `git worktree list` loop cannot:

- **Non-git fallback.** When `$TASKS_DIR`'s parent is not in a git repo (test
  harnesses, non-git consumers) the loop never runs; the append is the entire
  output. No crash, no stderr.
- **Local view always present.** The loop's `-d "$wt/.tasks"` guard skips a main
  checkout with no `.tasks/` on disk, and a symlinked `TASKS_DIR` may not match
  git's path textually. The append keeps the local view in the corpus regardless.

## Two callers, two correct answers — do not unify

`lib/worktree.sh:_wt_is_ignorable_path` does **not** list `.tasks/` among ignorable
paths, so for landing decisions `.tasks/` is a **DELIVERABLE**: a worktree whose
only change is under `.tasks/` holds real work that must land before teardown.

`fw_task_view_dirs` treats `.tasks/` as **CORPUS**: a view to read IDs out of.

Both are right. Collapsing them would produce a bug in whichever direction it
collapsed — either worktrees would be torn down with unlanded task files, or the
allocator would stop seeing a whole view. This is stated in both the function
header and here so the next reader does not "clean it up".

## Tests — `tests/unit/t3104_task_corpus_views.bats` (7/7 green)

Real fixture git repos with real `git worktree add`; the failure class lives in
git's view semantics, so a mocked `git worktree list` would only prove the mock.

1. main-only repo → exactly the one `.tasks/`
2. repo + 2 worktrees → all three views
3. non-git directory → `TASKS_DIR` alone, exit 0, **empty stderr**
4. worktree with no `.tasks/` → skipped, others still returned
5. **de-duplication asserted explicitly** — local view appears exactly once, and
   total lines == unique lines
6. worktree with an **empty** `.tasks/` → returned (a view, just empty)
7. main checkout with no `.tasks/` on disk → local view still emitted

## Mutation results

| # | One-line mutation | Killed by | Verdict |
|---|---|---|---|
| M1 | drop the `-d "$wt/.tasks"` guard | **test 4** | killed |
| M2 | remove the non-git guard (`if true; then`) | — | **survives — proven equivalent** |
| M3 | drop the trailing `views+=("$TASKS_DIR")` | **tests 3 and 7** | killed |

All three reverted; `lib/paths.sh` byte-identical to pre-mutation.

### M2 equivalence proof

Replacing the guard with `if true` is **behaviourally equivalent**, because the
inner call already handles the non-git case on its own. Measured directly outside
a repo:

```
git -C /nonrepo worktree list --porcelain  →  rc=128, stdout empty, stderr "fatal: not a git repository"
git -C ""      worktree list --porcelain  →  rc=128, stdout empty
```

Empty stdout ⇒ the `while` loop body never executes ⇒ identical output. The stderr
is already suppressed by the `2>/dev/null` on that same call.

So the guard and that `2>/dev/null` are a **redundant pair** protecting one
observable (silence outside a repo). A single-line mutation can only remove one of
them, which is why neither is individually detectable. Demonstrated:

| mutation | test 3 (no stderr) |
|---|---|
| M2 alone — guard removed, `2>/dev/null` kept | passes |
| M2b alone — `2>/dev/null` removed, guard kept | passes |
| **M2 + M2b jointly** | **fails** ← the pair is load-bearing |

This is defence-in-depth, not dead code, so the guard is **retained**. Recorded
rather than "fixed by adding a test", because no test can observe a redundancy
through the public interface; the honest artefact is the joint-removal evidence.

## Live check (project root, 5 views)

```
/opt/999-Agentic-Engineering-Framework/.tasks
/opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks
/opt/999-Agentic-Engineering-Framework/.claude/worktrees/rca-worktree-push-strand/.tasks
/opt/999-Agentic-Engineering-Framework/.claude/worktrees/t100196-vendor-fix/.tasks
/opt/999-Agentic-Engineering-Framework/.claude/worktrees/t100199-close/.tasks
count=5
```

## Pre-existing suites

`create_task_status_guard` 5/5 · `create_task_owner_gate` 4/4 ·
`inception_start_recommendation_gate` 14/14 · `task_id_race` 5/5 ·
`create_task_inception_recommendation_gate` 11/11 · `t100202_id_quarantine` 10/10 ·
`update_task` 19/19 · `t2924_update_task_owner_gate` 6/6 ·
`work_on_switch_focus` 4/4 · `bpmn_promote_e2e` 5/5 · `create_task` 29/30.

## Incidental finding — `create_task.bats` is not hermetic (NOT fixed here)

`tests/unit/create_task.bats` test 3 — *"T-2832: --start writes focus inside the
sandbox, not the live .context"* — **fails, and it fails identically at HEAD with
this task's changes reverted.** Pre-existing; verified by restoring both touched
files from `git show HEAD:` and re-running.

It is worth filing because the test is failing *about its own symptom*: running
the suite clobbered this worker session's **live** focus file
`.context/working/focus.t3104-corpusviews.yaml` (`T-3104` → `T-001`/`unknown`),
which then tripped the T-560 stale-focus gate and blocked the next command. The
sandbox redirection the test asserts is not holding for the per-session
`focus.<session>.yaml` path. Left for the parent to file as its own task
(one bug = one task); focus.yaml was restored to its pre-run value.
