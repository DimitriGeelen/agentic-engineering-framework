# T-100196 — Permanent Branch/Worktree Hygiene: Design

**Status:** design · **Owner:** agent (decision reserved for human GO on the keystone)
**Origin:** T-100194 (fork RCA), T-100195 (fork detection), T-100199 (pollution audit)
**Date:** 2026-07-05

## 1. Problem (one sentence)

The persistent interactive session lives on a long-lived **named branch**
(t2416/t2417…); real code lands on `origin/master` via throwaway worktrees +
one-way `fw integrate`, but the session branch keeps accumulating
handover/task-sync commits that **never merge back** — so it drifts from master
every session, and a go-live `git reset --hard` eventually orphans whatever
was not pushed, creating no-remote strands.

## 2. The invariant we are buying

> **The persistent session never holds a commit that is not already on `origin/master`.**

If this holds, divergence is impossible *by construction*: there is no session
branch to fork, nothing to reconcile, nothing to strand, nothing to prune.

## 3. Why a session branch has zero value in THIS framework

The usual reason to keep a session/feature branch is to keep `master`
releasable while WIP accrues. That reason does not apply here:

| Concern | In this framework |
|---|---|
| Half-built code polluting master | Impossible — real code lands via **worktree + `fw integrate`** (gated, FF-only), never from the session directly |
| "master must stay releasable" | `master` is the **continuously-deployed trunk** (go-live). It already receives every landed change |
| What the session actually commits | Governance state only — handovers, task files, `.context/` memory. This *belongs* on master; it is the framework's own record |

So the session branch carries **no releasable code** — only governance state
that should be on master anyway. It is pure liability: the sole source of drift.

## 4. Decision — mechanism

Three candidates were scoped on T-100196 AC#1:

- **(a) auto-merge-back** — keep the session branch, `fw integrate` merges
  origin/master back into it after each land. *Suppresses* drift but the branch
  still exists; one missed merge-back re-opens it. Does not eliminate the class.
- **(b) `fw go-live` guard verb** — ff-checks and routes forks to reconciliation
  instead of a bare reset. Handles the *reset* safely but still has session
  branches accumulating.
- **(c) session tracks `origin/master` directly** — no session branch. Dissolves
  the class at the root.

**CHOSEN: (c), with a lightweight guard from (b) as defense-in-depth.**

Rationale: (c) is the only option that satisfies the §2 invariant structurally
rather than by discipline. (a) and (b) both leave a session branch alive, i.e.
they leave the drift class alive and merely slow it. Per §3 the session branch
buys us nothing, so removing it is strictly a subtraction of liability.

## 5. Architecture / slices

### Slice 1 — Keystone: session-on-master  *(needs human GO — changes daily workflow)*
- The persistent interactive session runs with `HEAD = master`.
- Handover / task-sync / context commits go straight to `master` → pushed to
  `origin/master` (already permitted by the T-2462 push safe-list).
- Real code changes **unchanged**: worktree off `origin/master` → build →
  `fw integrate run master --push` → auto-prune worktree+branch.
- Session-start (`claude-fw` / SessionStart hook) checks out master (or, if the
  working dir is dirty / on another branch, WARNs and offers to switch).
- Push-conflict path: on `! [rejected]`, `git pull --rebase origin master` then
  re-push (a `fw sync` helper). Covers the rare concurrent-session case.
- **Docs:** rewrite CLAUDE.md §Session Start / §Session End to describe
  trunk-based session flow; delete the session-branch assumptions.

### Slice 2 — `fw worktree gc`  *(safe, additive, mechanism-agnostic — build now)*
The reclaim tool. Fixes the finding from T-100199 that `git cherry` **cannot**
prove a re-derived branch is landed (patch-ids never match after
`vendor self` re-commits).

- **Content-verify, not patch-verify:** for a candidate branch, compute the set
  of non-generated files it changed vs its merge-base; for each, compare the
  branch's blob to `origin/master`'s blob. If every deliverable file is
  byte-identical on master (or the branch touches only governance/generated
  paths), the branch's *work* is landed → safe to reclaim.
- Reclaim = `git worktree remove` (if a worktree) + surface the branch for a
  Tier-0 `git branch -D` (never self-approve the delete).
- No-remote branches whose work is **not** provably landed → never touched;
  reported as "push-then-triage" (the T-100199 strands).
- Wire a summary into `fw doctor` (WARN when N reclaimable worktrees/branches
  exist) and expose `fw worktree gc [--apply]` (dry-run default).

### Slice 3 — Guard  *(safe, additive — build now)*
- Reuse the T-100195 `diverged-fork` detector: `fw doctor` WARNs if the current
  session `HEAD` is a non-master branch that is diverged from origin/master
  (both-directions-exceed-threshold). This catches any regression back into the
  session-branch antipattern.

### Slice 4 — Migrate the existing mess  *(Tier-0 — needs human approval)*
1. Push the 3 no-remote strands to origin (zero-risk preservation):
   `audit-remediation-t2416`, `t2353-audit-emit-tasks`,
   `worktree-rca-worktree-push-strand`.
2. `fw worktree gc` content-verifies each; genuinely-unlanded work is merged
   back via a normal worktree+integrate; the rest is surfaced for prune.
3. Point the main working dir at master (`git checkout -B master origin/master`
   after `git merge --ff-only` — t2416 is a clean ancestor, so no reset needed).
4. Tier-0 prune the reclaimable branches (`learning/precompact-cleanup`,
   the landed t100199-* work branches) with your approval.

## 6. Rollback / safety

- Slices 2–3 are additive and read-only-by-default (`gc` dry-runs, doctor
  WARNs) — no workflow change, fully reversible.
- Slice 1 is reversible: if trunk-based session proves painful, re-create a
  session branch. Nothing is destroyed by trying it.
- Slice 4 touches history only via **push** (additive) and Tier-0 deletes (your
  approval, and every deleted branch is first confirmed landed on origin/master).

## 7. Open questions for GO

1. Confirm mechanism **(c)** (this doc's recommendation).
2. Green-light Slice 1 (flip the live session onto master) — the one workflow
   change. Slices 2–3 proceed regardless; Slice 4 waits on your Tier-0 approvals.
