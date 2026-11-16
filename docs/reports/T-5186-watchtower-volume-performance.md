# T-5186 — Watchtower overview pages at volume

**Task:** T-5186 (inception) · **Trigger:** dimitri-mint-dev msg fc3a6ba2, 2026-11-16 · **Status:** exploring

## Question

Why do Watchtower overview pages (`/approvals`, `/`) slow down as a project grows? 1409-sprind (~6,150 tasks)
times out after 90 s. Is it systemic work per request, CPU starvation on a loaded host, or both? Does it need an
index layer, or is caching enough?

## Reported evidence (from the trigger)

| Project | Tasks | `/approvals` |
|---|---|---|
| dimitri-mint-dev | ~233 | 0.95 s |
| 1023 | ? | 1.25 s |
| 055 | ? | 4.3 s |
| 1409-sprind | ~6,150 | > 90 s (also `/`); `/review/T-6144` 0.03 s |

The host load average was 37. Since 2026-11-12, Watchtowers started from claude-fw sessions run at CPUWeight=20.

## Method

Profile in-process with the Flask test client on this repo (about 920 active + 4,250 completed task files, close to
1409's size). This measures CPU work with no host contention. 1409 is never touched.

## Findings (2026-11-16, this repo: ~920 active + ~4,250 completed task files)

**F1. Live timings.** `/approvals` took 31.4 s on the first measurement, then 3.7 / 2.4 / 2.4 s. `/` takes 2.3 s and a
task page 0.12 s.

**F2. A cold `/approvals` costs 34–44 s, and the time is review-history validation, not reading task files.** Profiled
in-process with the Flask test client (no host contention; `T-5186-profile-page.py`, `T-5186-profile-subprocesses.py`):

| Cost | Calls | Time | From |
|---|---|---|---|
| `git show` | 1,909 | 10.5 s | `lib/verdict_ledger.py` `_git_out` (1,843) and `_worker_fault` (66) |
| `git log` | 6 | 7.3 s | `lib/verdict_ledger.py` `_git_out` |
| `bash -c` | 48 | 5.2 s | `web/shared.py` `_run` |
| Python | — | ~12–22 s CPU | mostly the same validation: `review_readiness` → `_compute_readiness` → `verdict_ledger.satisfying_verdict` → `_fault` / `_row_fault` |

That totals 2,041 subprocesses for one page. Around 400 tasks awaiting review each have their readiness computed, and
each readiness check re-validates the review-ledger rows that concern the task against git history.

**F3. A warm `/approvals` costs ~2.3 s, and a new commit alone does not make it cold.** Moving the git state (the
mtime of `.git/logs/HEAD`, as any commit does) left the next request at 2.2 s. The git memo and the per-task readiness
keys (T-4394) already cope with unrelated commits.

**F4. Any write to any review ledger makes it cold again.** `web/shared.py:_readiness_stamp` keys every task's cached
readiness on the mtime of every `.context/reviews/*.jsonl` (13 files): dispatch registry, completions, refusals,
applied ticks, costs and so on. Simulating one such write in-process (no file touched) took the next request from
2.4 s to 16.5 s. A process restart costs the full 34–44 s. In the last 24 h, 42 commits touched `.context/reviews/`,
not counting uncommitted appends. So in a project that runs reviews, the page is cold often.

**F5. 1409 may be a different case.** There, `/` also exceeds 90 s, while here `/` is 2.3 s at a similar task count.
F2–F4 explain `/approvals` here, but not a slow `/` on 1409. Either 1409 hits another hotspot, or CPU starvation
(CPUWeight=20 at load 37) stretches a cold path past 90 s. Concurrent cold requests each recompute the same cache
(no single-flight), which is worse when starved. This cannot be settled without a profile from 1409's side.

## Candidate directions

| | What | Addresses | Size |
|---|---|---|---|
| A | Persistent, content-addressed memo of per-row ledger validation (keyed on the row's bytes and the git object ids it was validated against, which never change), on disk so it survives restarts | F2, F4 cold cost; restarts | S–M |
| B | Narrow `_readiness_stamp`: a task's readiness depends on ledger rows for that task, not on every ledger file's mtime | F4 (the trigger) | S |
| C | Single-flight + serve-stale-while-refreshing for `/approvals` (T-5147 already does this for the board; a READY is never served stale) | F5 starvation, thundering herd | S |
| D | The operator's proposal: a general rebuildable index (e.g. SQLite) between task files and Watchtower above a volume threshold | task-file parsing at volume | L |

On this repo's evidence, D aims at the wrong cost: parsing ~5,000 task files is already cached and cheap (`/` 2.3 s).
The cost is re-validating review history. A, B and C target it directly and keep the files and ledgers as the only
source of truth, which D also wants. Whether 1409 needs D depends on F5.

## Dialogue Log

- 2026-11-16: the operator said "proceed as suggested" after the proposal to measure first, then recommend.
