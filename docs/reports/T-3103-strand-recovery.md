# T-3103 — Landing the 43 stranded commits: content audit

**Instruction:** *"land the 43 commits before removing those worktrees."*

**Finding:** the 43 commits cannot be landed as commits, and do not need to be.
Their *content* is almost entirely on master already. Three task files are
genuinely unlanded; 24 source files must be actively refused.

## Headline

| Branch | Commits ahead | Deliverables | Genuinely unlanded | Landed here |
|---|---:|---:|---:|---:|
| `worktree-inception-gov-payload-mediation` | 6 | 3 | 2 tasks (+1 already on master under another name) | 2 |
| `worktree-rca-worktree-push-strand` | 37 | 27 | 1 task (+24 stale source, 2 superseded tasks) | 1 |
| **Total** | **43** | **30** | **3** | **3** |

## Why "land the commits" is the wrong operation

Both branches are enormously behind master — 1513 and 1728 commits — with
merge-bases at 2026-07-01 and 2026-06-16. A merge would drag every one of their
2-month-old source files over master's current versions. Those files include
`agents/audit/audit.sh`, `bin/fw`, `lib/paths.sh` and `lib/worktree.sh`, which is
to say: it would revert the worktree fixes shipped this week (T-3095, T-3098,
T-3099, T-3101) using commits whose stated purpose was to *fix worktrees*.

A rebase is no better — 43 commits replayed over 1700 commits of drift, where
24 of the 43 are session handovers and 7 are copy-to-master sync commits whose
content already arrived by other means.

The correct operation is **content recovery**, which is also what the framework's
own `fw worktree gc` performs (`_wt_work_landed`, `lib/worktree.sh:693`): compare
deliverable files byte-for-byte against master, because re-derivation defeats
`git cherry`. Its verdict on these two branches was `unlanded:3/3` and
`unlanded:14/53` — the starting point for this audit, refined below by checking
content rather than path.

## Per-strand classification

### `worktree-inception-gov-payload-mediation` (6 commits)

| File | Verdict |
|---|---|
| `docs/reports/T-2505-worktree-usage-policy.md` | **already on master** as `docs/reports/T-2822-prior-art-stranded-worktree-usage-policy.md`, md5 `2c62820025b6ea664d8774da2cdb80eb` on both sides |
| `.tasks/active/T-2505-worktree-usage-policy--refine-per-task-d.md` | **unlanded** → recovered |
| `.tasks/active/T-2506-reconcile-main-checkout-stranded-uncommi.md` | **unlanded** → recovered |
| `.context/project/concerns.yaml` (G-083) | already on master |
| 10 × `.fabric/components/*.yaml` | regenerated since; ignorable per `_wt_is_ignorable_path` |
| 1 × session handover | historical |

`gc` reported `unlanded:3/3` because it compares by *path*. Content comparison
drops that to 2 — the research artifact was recovered during T-2822 under a
different filename.

### `worktree-rca-worktree-push-strand` (37 commits)

| Group | Count | Verdict |
|---|---:|---|
| Session handovers (`T-077:` / `T-012:`) | 24 commits | historical; `.context/handovers/` ignorable |
| `T-2481: go live — sync code to origin/master` | 7 commits | content already copied to master in June; the commits recording the copy never followed |
| Source files under `lib/`, `agents/`, `bin/`, `deploy/` | 24 files | **stale by ~2 months — must not land** |
| `.tasks/…T-2323…` | 1 file | master's copy is newer |
| `.tasks/…T-2324…` | 1 file | master has it in `completed/`; landing the `active/` copy would duplicate the ID |
| `.tasks/…T-2428…` | 1 file | **unlanded** → recovered |
| G-071, G-072, L-486 | — | already on master |

Staleness evidence (last commit touching each file):

| File | Strand | Master |
|---|---|---|
| `agents/audit/audit.sh` | 2026-06-24 | 2026-08-14 |
| `lib/paths.sh` | 2026-06-23 | 2026-07-31 |
| `agents/context/check-active-task.sh` | 2026-06-23 | 2026-08-14 |

## The ID collision

All three recovered tasks collide with unrelated tasks that now own their IDs:

| Strand task | ID | Owner on master |
|---|---|---|
| worktree usage policy — refine per-task default | `T-2505` | ratify P-03 red-team test contract spec (completed) |
| reconcile MAIN checkout stranded uncommitted work | `T-2506` | pre-compact handover silently drops session (completed) |
| worktree teardown strands unpushed commits | `T-2428` | governance by payload mediation (active) |

This is the T-2822 mechanism reaching the ID space: the worktree forked the
task corpus, and each side then allocated max+1 independently (L-506). It is
also the reason the recovered files are stored as `docs/recovered/…/*.task.md`
rather than under `.tasks/` — filing them under the original IDs would create
duplicates the audit forbids, and filing them under fresh IDs would fabricate
provenance for tasks nobody is going to work.

All three are substantively superseded: T-2505 by T-2822's GO, T-2506 by this
recovery, T-2428 by T-3101 (visibility) and T-3102 (teardown).

## Result

`docs/recovered/strand-2026-07/` holds the three files verbatim plus a manifest.
Nothing unique remains on either branch, so both worktrees are safe to tear down
— which is what the instruction was protecting against.

Removal itself is Tier 0 and remains the operator's call. Note that until T-3102
lands, `fw worktree remove` will still refuse on governance-only dirt (26 and 5
dirty files, 23 and 4 of them `.context/`/`.tasks/`), and `--force` on these two
branches would have destroyed exactly the 43 commits this audit just cleared.
