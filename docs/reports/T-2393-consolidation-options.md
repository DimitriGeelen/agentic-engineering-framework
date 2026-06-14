# T-2393 — Resolve divergent worktree/master state cleanly without loss

**Type:** inception (tactical) · **Status:** exploration complete · **Recommendation:** GO — Option 1
**Date:** 2026-06-14 · **Sibling:** [[T-2394]] (structural remediation of the same class)

## Problem

| Line | Directory | Branch | HEAD |
|------|-----------|--------|------|
| This session | `…/.claude/worktrees/arc012-continuous-run-s4s5` | `worktree-arc012-continuous-run-s4s5` | `4b1ceb798` |
| Canonical | `/opt/999-…` (main checkout) | `master` | `4679b9a42` |

- Branch is **42 commits ahead** of master (all arc-012 / T-2380–T-2392 work + the 2 new bug tasks).
- Master is **6 commits ahead** of the branch — T-2376/T-2377/T-2378/T-2379, deployed *directly onto master* via cherry-pick/TermLink on 2026-06-13 20:10–22:14.
- merge-base: `74d4667b1` (chore: log Tier-2 focus-switch bypasses).
- Push blocked by 3 audit FAILs (worktree-local; see IW-3).
- 2 live `claude-fw` sessions on the master checkout (PIDs 1752988/1753004, one active inner `claude` 1753005).

**Constraint set:** (C-a) lose zero of the 42 commits; (C-b) do not mutate the master *working tree* while the 2 sessions are live; (C-c) reconcile the divergence (not just stack it).

## Investigation (IW dispositions)

### IW-1 — Are the 6 master commits duplicates of branch commits? → **answered: mostly NOT**
`git patch-id --stable` over the 6 master-only vs 42 branch-only commits:
```
UNIQ 4679b9a42 T-2379 refresh runbook
UNIQ b59668047 T-2378 episodic + reviewer override
UNIQ 04838ff93 T-2378 integration test
UNIQ fedc3acb1 T-2377 close on master + self-vendor
DUP  6c43bd5f0 T-2377 budget gauge reads hook stdin   ← only true duplicate
UNIQ db0a8ea5a T-2376 startup matcher
```
5/6 are unique diffs. The cherry-picks carried master-specific content (self-vendor paths, episodic
generation, reviewer-override file, runbook edits) that differs from the branch originals. **Assumption A1
(pure duplicates) is falsified** — master holds genuine content the branch lacks, so a *union* (merge),
not a discard, is required.

### IW-2 — Which operation reconciles with zero loss + no master-tree mutation? → **answered: merge-into-branch here, then FF master later**
`git merge-tree --write-tree --name-only master worktree-branch` (zero-mutation simulation) → exit 1,
**7 conflicted paths**, all documentation/state:
```
.agentic-framework/agents/handover/discard-manifest.sh   (add/add)
.context/episodic/T-2377.yaml                             (add/add)
.context/episodic/T-2378.yaml                             (add/add)
.context/working/reviewer-overrides.yaml                 (content)
.tasks/completed/T-2377-…md                               (add/add)
.tasks/completed/T-2378-…md                               (add/add)
.tasks/completed/T-2379-…md                               (add/add)
```
**Zero core-code conflicts.** Every conflict is a "same task closed on both lines" artifact — trivially
resolvable by taking the union / master's richer version. Operation matrix:

| Operation | C-a zero-loss | C-b no master-tree mutation | C-c reconciles | Verdict |
|-----------|:---:|:---:|:---:|---|
| FF master → branch | ✓ | ✗ (FF impossible — diverged) | ✗ | **rejected** (not FF-able) |
| `git merge` *in master checkout* | ✓ | ✗ (rewrites live tree) | ✓ | rejected (violates C-b) |
| Rebase branch onto master | risk (replays 42, conflicts ×N) | ✓ | ✓ | rejected (history rewrite, N-conflict) |
| **`git merge master` *in THIS worktree*** | ✓ | ✓ | ✓ | **SELECTED** |
| Push branch → server-side PR merge | ✓ | ✓ | ✓ (on server) | viable fallback |

The selected path merges master *into the branch* inside the isolated worktree → the branch becomes a
strict superset (master becomes an ancestor) → the eventual `master` advance is a **conflict-free
fast-forward** that the operator runs when the 2 sessions are quiesced. The hard merge work happens once,
in isolation, off the live checkout.

### IW-3 — Are the 3 push-blocking FAILs spurious? → **answered: 2 spurious, 1 trivial**
1. **Cron not installed at `agentic-audit-arc012-continuous-run-s4s5`** — target name keyed to the
   *worktree* name; master's cron is `agentic-audit` (already installed). Installing this = a system cron
   for a throwaway worktree. **Spurious.** Clears on the master line.
2. **Cron registry ahead of generated** — worktree-local generated crontab; registry last touched on the
   master line at T-2208 (old). On master, registry==generated. **Spurious.** Clears on the master line.
3. **Self-vendor drift `bin/fw`** — REAL but trivial: 19-line delta = exactly the T-2390 `CLAUDE_PROJECT_DIR`
   block present in source `bin/fw` but missing from vendored `.agentic-framework/bin/fw`. One `fw vendor`
   clears it. (Note: the T-2390 block is proven dead code — see [[T-2391]] — but that's a separate fix;
   for consolidation it's just a vendor-sync.)

**None are product defects.** `--no-verify` for this specific consolidation push is justified; cleaner still,
the FF+push happens from the master checkout where #1/#2 don't fire and #3 is cleared by `fw vendor`.

## Recommendation: GO — Option 1 (merge-into-branch here → FF master when quiesced)

Execution sequence (to run **after** GO, as a follow-on build task or by the operator — NOT under this
inception ID):

```bash
# Step 1 — in THIS worktree (isolated; mutates only the branch):
cd /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5
git merge master            # resolve the 7 doc/episodic conflicts (union / take master's richer copy)
bin/fw vendor               # clear the real self-vendor bin/fw drift (FAIL #3)
git add -A && FW_SWITCH_FOCUS=1 git commit -m "T-2393: merge master into branch + vendor sync (consolidation)"

# Step 2 — when the 2 master-checkout sessions are quiesced (operator coordinates):
#   trivial, conflict-free fast-forward (conflicts already resolved in Step 1)
git -C /opt/999-Agentic-Engineering-Framework merge --ff-only worktree-arc012-continuous-run-s4s5
git -C /opt/999-Agentic-Engineering-Framework push     # cron FAILs don't fire on master; bin/fw synced

# Fallback if sessions cannot be quiesced (zero master-tree mutation):
git push origin worktree-arc012-continuous-run-s4s5    # then merge via OneDev PR server-side
```

**GO rationale:** root cause identified (parallel landing of the same tasks on two lines via direct-to-master
cherry-pick); fix path is bounded and *proven* (merge-tree already simulated the exact 7-file conflict set,
all doc/state, zero code); scoped, testable, reversible (the merge commit is a single revert; nothing is
force-pushed or discarded). Zero commit loss; the live sessions are never written underneath.

**Why not the fallback as primary:** server-side PR merge is also zero-loss and zero-mutation, but it leaves
master behind until the operator merges the PR, and re-runs the divergence risk if more sessions commit to
master meanwhile. Option 1 makes the branch the single superset immediately and reduces the final step to a
no-judgement FF.

## Residual / hand-off to [[T-2394]]
This resolves the *instance*. It does nothing to stop the *next* instance — two sessions on the master
checkout can still commit directly to master, and parallel worktrees will diverge again. That structural
prevention is inception B (T-2394): master-as-merge-only enforcement + parallel-agent backlog/branch model.
