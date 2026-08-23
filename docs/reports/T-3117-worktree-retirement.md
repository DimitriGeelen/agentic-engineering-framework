# T-3117 — retiring the four stale linked worktrees

**Task:** T-3117 · **Design:** `docs/design/task-corpus-concurrency-model.md` §R7
**Relation to R7:** T-3110–T-3113 stop new divergence. They do not remove the
divergence already on disk. This is that cleanup.

---

## Why nothing had been reclaimed

`fw worktree gc` existed for exactly this job and had been reporting all four
worktrees as holding unlanded work. Two defects, both erring toward "keep",
which is the direction nobody re-examines:

| # | Defect | Effect |
|---|---|---|
| 1 | `_wt_master_ref` preferred `refs/heads/master` | the session-on-master flow (T-100196) lands by pushing `HEAD:master`, never advancing the **local** master ref. Measured 2026-08-23: **1744 commits behind**. Every landing verdict used a six-week-old trunk. |
| 2 | `_wt_work_landed` only compared file content against master *today* | a branch whose commits are all in master but which is behind gets `unlanded:1440/1442`, because master has since changed those files again — for a branch git calls a strict ancestor. |

Fixed in `lib/worktree.sh` (commit `e9a673f12`), pinned by
`tests/unit/t3117_gc_landing_predicate.bats` (8/8). After the fix,
`t100196-vendor-fix` and `t100199-close` move from KEEP to RECLAIM.

The irony is worth stating plainly: the two worktrees the tool refused to
reclaim are the two whose stale enforcement code minted T-2505, T-2506 and
T-2428 twice — the incidents R7 was built to prevent.

## Preservation ledger

No worktree is removed before its own row here is filled.

| Worktree | Branch | Unique commits vs origin/master | Verdict | Preserved by |
|---|---|---|---|---|
| `t100196-vendor-fix` | `t100196-vendor-fix` | **0** — strict ancestor of origin/master | landed | nothing to preserve; every commit is in master |
| `t100199-close` | `t100199-close` | **0** — strict ancestor of origin/master | landed | nothing to preserve; every commit is in master |
| `inception-gov-payload-mediation` | `worktree-inception-gov-payload-mediation` | **6** | unlanded | branch pushed to `origin` before removal |
| `rca-worktree-push-strand` | `worktree-rca-worktree-push-strand` | **37** | unlanded | branch pushed to `origin` before removal |

Uncommitted state in all four is session churn only — `.context/working/*`,
`VERSION`, audit snapshots — which is what `_wt_is_ignorable_path` classifies as
discardable dirt. No deliverable is dirty in any of them.

## The three cross-view ID collisions

Each is a fork artifact: a second, unrelated task minted onto an ID the
authority had already used. In every case the fork's *subject* has since
shipped on master under a different ID, so retiring the worktree costs nothing
but the duplicate.

| ID | Authority holds | Fork holds | Where the fork's subject actually shipped |
|---|---|---|---|
| T-2428 | "Governance by payload mediation" (work-completed) | "worktree teardown strands unpushed commits + ephemeral worktree paths" | **T-2825** — same title stem, completed; plus CLAUDE.md §Copy-Pasteable Commands rule 6 (G-075) and T-2829, T-3102 |
| T-2505 | "Ratify P-03 red-team test contract" (completed) | "Worktree usage policy — refine per-task default" | `docs/design/task-corpus-concurrency-model.md` (T-3106) — the policy that inception asked for, written and adopted |
| T-2506 | "pre-compact handover silently drops session memory" (completed) | "Reconcile MAIN checkout stranded uncommitted work" | operational, July-scoped; MAIN is clean and the class is guarded by T-2825/T-3102 |

The branch history keeps every fork file recoverable after the worktree
directory is gone, which is why pushing the two unlanded branches is the whole
of the preservation requirement.

## Removal — what actually happened

Preservation refs confirmed on `origin` **before** any removal:

```
f59472365  refs/heads/worktree-inception-gov-payload-mediation   (was 2d108af23 — 3 commits pushed)
ec56fe61e  refs/heads/worktree-rca-worktree-push-strand          (new branch — all 37 commits pushed)
```

`t100196-vendor-fix` and `t100199-close` needed no push: `git merge-base
--is-ancestor <branch> origin/master` is true for both, so every commit is
already in master.

Then:

| Worktree | Removed by | Dirty state at removal |
|---|---|---|
| `t100196-vendor-fix` | `fw worktree gc --apply` (verdict `merged`) | — |
| `t100199-close` | `fw worktree gc --apply` (verdict `merged`) | — |
| `inception-gov-payload-mediation` | `fw worktree remove` | 26 discardable: 23 governance (non-authoritative fork), 3 vendored/generated |
| `rca-worktree-push-strand` | `fw worktree remove` | 5 discardable: 4 governance, 1 vendored/generated |

Every branch was **kept**; only the working directories are gone. Branch
deletion is Tier 0 and stays with the operator.

`git worktree list` now shows one entry. `git worktree prune` had nothing to
do — `.git/worktrees/` is gone entirely.

### One orphan left deliberately

`.claude/worktrees/t100196-go-live-guard/` survives as an untracked 4K
directory containing a single file, `.context/audits/2026-08-11.yaml`. It has no
`.git` link, was never a registered worktree, and holds no `.tasks/` — so it is
not a corpus view and does not affect the collision check. It is the residue of
an audit run whose `PROJECT_ROOT` resolved into a worktree that no longer
exists. Deleting a directory is Tier 0; it is listed in the operator handoff
rather than removed here.
