# Recovered strand artifacts — 2026-07 worktree teardown (T-3103)

Three task files recovered verbatim from two linked worktrees that held 43
unlanded commits, dormant from 2026-07-01 until 2026-08-20 (OBS-174, T-2822 S1).

They are stored here as `*.task.md`, **not** under `.tasks/`, for one reason:
every one of their task IDs is now owned on master by an unrelated task. Filing
them under their original IDs would create duplicate IDs; filing them under new
IDs would fabricate provenance. Verbatim recovery with a manifest preserves the
record without doing either.

## Provenance

| Recovered file | Origin branch | Origin commit | md5 |
|---|---|---|---|
| `T-2505-worktree-usage-policy--refine-per-task-default.task.md` | `worktree-inception-gov-payload-mediation` | `54adb1fcf` | `1af96c61` |
| `T-2506-reconcile-main-checkout-stranded-uncommitted.task.md` | `worktree-inception-gov-payload-mediation` | `116740503` | `3bfa23d8` |
| `T-2428-worktree-teardown-strands-unpushed-commits.task.md` | `worktree-rca-worktree-push-strand` | `ec56fe61e` | `9e3a12dc` |

## ID collisions — why these could not be filed as tasks

| Strand task | ID | The task that owns that ID on master |
|---|---|---|
| worktree usage policy — refine per-task default | `T-2505` | `T-2505-ratify-p-03-red-team-test-contract-spec` (completed) |
| reconcile MAIN checkout stranded uncommitted work | `T-2506` | `T-2506-pre-compact-handover-silently-drops-sess` (completed) |
| worktree teardown strands unpushed commits | `T-2428` | `T-2428-governance-by-payload-mediation` (active) |

The collision is the T-2822 mechanism itself: the worktrees forked the task-ID
space along with the rest of the tracked governance state, and both sides then
allocated the next free ID independently. See L-506 (max+1 allocators over an
on-disk corpus).

## What supersedes each

- **T-2505 (strand)** — superseded by **T-2822**, which asked the same question
  (should a worktree hold governance state?) and was decided GO on 2026-08-06.
  Its research artifact was already recovered to master as
  `docs/reports/T-2822-prior-art-stranded-worktree-usage-policy.md`, byte-identical
  to the strand copy (md5 `2c62820025b6ea664d8774da2cdb80eb`).
- **T-2506 (strand)** — the reconciliation it asked for is what T-3103 performed.
- **T-2428 (strand)** — superseded by **T-3101** (visibility: strands now surface
  with unlanded count and age) and **T-3102** (teardown: governance-only dirt no
  longer blocks removal). Its lesson had already reached `CLAUDE.md`
  §Copy-Pasteable Commands item 6, which cites T-2428 by name.

## What was deliberately NOT landed

**24 source files** on `worktree-rca-worktree-push-strand` — `agents/audit/audit.sh`,
`bin/fw`, `lib/paths.sh`, `lib/worktree.sh`, `lib/config.sh`, `lib/reviewer/static_scan.py`
and 18 others.

These are **~2 months stale**. The strand branched on 2026-06-16 and its last
commit is 2026-06-24; master has moved 1728 commits since. Sampled:

| File | Strand | Master |
|---|---|---|
| `agents/audit/audit.sh` | 2026-06-24 | 2026-08-14 |
| `lib/paths.sh` | 2026-06-23 | 2026-07-31 |
| `agents/context/check-active-task.sh` | 2026-06-23 | 2026-08-14 |

Landing them would revert two months of work — including the worktree fixes
(T-3095, T-3098, T-3099, T-3101) that live in exactly those files. The strand's
own commit messages say why they are safe to drop: seven of them read
*"T-2481: go live — sync code (lib agents bin) to origin/master"*. That content
went to master in June by copy; the commits recording the copy never followed.

Also not landed, because already present on master: gaps **G-071**, **G-072**,
**G-083** (`.context/project/concerns.yaml`) and learning **L-486**
(`.context/project/learnings.yaml`); the `.tasks/` copies of **T-2323** (master's
is newer) and **T-2324** (master has it in `completed/`); ~24 June session
handovers; and the `.fabric/` component cards, which have been regenerated since.

## Verification

    # every recovered file is byte-identical to its strand original
    git show worktree-inception-gov-payload-mediation:.tasks/active/T-2505-worktree-usage-policy--refine-per-task-d.md | md5sum
    md5sum docs/recovered/strand-2026-07/T-2505-worktree-usage-policy--refine-per-task-default.task.md

Full content audit, including the per-file landed/unlanded classification for
both strands: `docs/reports/T-3103-strand-recovery.md`.
