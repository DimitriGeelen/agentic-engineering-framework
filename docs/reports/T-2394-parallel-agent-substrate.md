# T-2394 — Structural remediation: concurrent AEF agents on a shared backlog and master

**Type:** inception (structural) · **arc:** parallel-execution-aef · **Status:** exploration complete
**Recommendation:** GO — layered direction, first slice = master-as-merge-only pre-commit guard
**Date:** 2026-06-14 · **Sibling:** [[T-2393]] (resolves the current instance; this prevents the class)

## Problem

Worktree isolation let multiple AEF agents run in parallel (own git-toplevel, own `.restart-requested`,
own `focus.yaml`). It fixed per-session blast-radius but exposed four *concurrency governance* gaps that
isolation alone cannot close. [[T-2393]] is the first symptom; the operator's invariant *"none other than
this should write to master"* is currently enforced by **nothing**.

| Gap | Description | Severity | Frequency | Owner |
|-----|-------------|----------|-----------|-------|
| **G1** | No guard stops a session on the master checkout committing **directly to master** | catastrophic | rare | **B (this task)** |
| **G2** | Parallel branches diverge; reconciliation is manual/ad-hoc | high | per-merge | **B (this task)** |
| **G3** | `focus.yaml` is per-worktree → two agents can grab the same `T-XXX` | medium | occasional | arc-011 (write-set) + future `fw task claim` |
| **G4** | Shared-state files (episodic/reviewer-overrides/completed `.md`/audit YAML) collide on merge | medium | **every merge** | **arc-011** (already its headline mechanic) |

## Investigation (IW dispositions)

### IW-1 — Minimal guard for "master is merge-only"? → **answered: extend the existing pre-commit hook**
`fw git install-hooks` already installs **commit-msg + post-commit + pre-commit** (agents/git/git.sh). The
pre-commit surface exists — no new plumbing. A guard there can distinguish intent by git's in-progress state:

| Action on master | pre-commit fires? | `.git/MERGE_HEAD`/`CHERRY_PICK_HEAD` | Guard verdict |
|------------------|:---:|:---:|---|
| Fast-forward from reviewed branch | **no** (no commit created) | — | allowed (silently) |
| Merge commit from reviewed branch | yes | MERGE_HEAD present | **allow** (it's a merge) |
| Direct authored `git commit` | yes | absent | **BLOCK** ← the invariant |
| Cherry-pick onto master | yes | CHERRY_PICK_HEAD present | policy choice (see Decisions) |

So the guard = "if HEAD is `master`/`main` in the *main* checkout AND no MERGE_HEAD → refuse, point at the
branch+merge flow." Bypass env-var (Tier-2 logged) for the documented deploy path. Feasible and bounded.

### IW-2 — Dominant friction? → **answered: G4 by frequency, G1 by severity**
[[T-2393]]'s `merge-tree` conflict set was **7/7 shared-state files** (episodic, reviewer-overrides,
completed-task `.md`, runbook, vendored doc) — G4 is the *frequent* toil. But G4 is **already arc-011's
headline mechanic** ("no `.tasks/` or `.context/audits/` merge conflicts"). G1 is *rare but catastrophic*
and has **zero current protection** — it is the operator-alarming case and B's unique high-value target.
Conclusion: B owns G1 (+G2); G4 routes to arc-011; don't duplicate.

### IW-3 — Existing claim/lease primitive? → **answered: none in fw; TermLink substrate exists**
No `fw task claim`/`lease` verb exists. TermLink provides `kv set/get/watch` and `channel claim / claims /
claim_transfer` — a viable substrate for a future cross-worktree `fw task claim T-XXX` lease (agent-id + TTL,
`fw work-on` refuses an already-leased task). This is **build-from-scratch** → defer G3 behind arc-011's
nearer-term disjoint-write-set discipline; file as a follow-on slice, not the first slice.

### IW-4 — Composition with arc-011? → **answered: clean split, no overlap**
arc-011 (`parallel-execution-aef`): *"Multi-agent concurrent execution over disjoint write-sets"*; scoped
driver "Disjoint Write-Set Discipline"; headline mechanic clause **"no `.tasks/` or `.context/audits/` merge
conflicts"**; tooling `fw write-set check <T-A> <T-B>` already exists. arc-011 governs **parallel dispatch**
(agents pick disjoint file-sets so their work doesn't collide). B governs the **shared-repo substrate
underneath** — who may write master (G1) and how branches reconcile (G2). arc-011 *assumes* a healthy
shared repo; B *provides* it. No contradiction; B is a dependency-sibling of arc-011, not a subset.

## Recommendation: GO — layered structural direction

**Layer 1 (first slice, build now after GO): master-as-merge-only pre-commit guard (G1).**
Extend agents/git/git.sh pre-commit: refuse an authored commit when HEAD is `master`/`main` and no
`MERGE_HEAD`, with a block message pointing at the branch→review→merge flow and a Tier-2-logged
`FW_ALLOW_MASTER_COMMIT=1` bypass for the documented deploy path. Bats-pinned (block direct / allow merge /
allow FF / bypass logs). This makes the operator's invariant **structural, not advisory** (L-405).

**Layer 2 (follow-on slice, captured): reconciliation protocol/helper (G2).**
Codify what [[T-2393]] did by hand into `fw consolidate` (or a documented runbook): merge-master-into-branch
in the worktree → vendor-sync → operator FF. Turns ad-hoc reconciliation into a one-verb path.

**Layer 3 (defer to arc-011): G4 shared-state conflicts** — already arc-011's headline mechanic; no B work.
**Layer 4 (follow-on slice, captured): `fw task claim` lease over TermLink kv/channel-claim (G3)** —
build-from-scratch; lower priority than G1; behind arc-011's write-set discipline in the meantime.

**GO rationale:** the highest-severity gap (G1) has a bounded, feasible fix on an *existing* hook surface,
is testable (bats) and reversible (a hook, env-bypassable), and directly delivers the operator's stated
invariant. The lower-severity/higher-frequency gaps are either already owned (G4→arc-011) or sequenced as
captured follow-ons (G2, G3) — so GO authorises a small, safe first slice without over-committing scope.

**NO-GO would require** that G1 needs a redesign of the git model or that no guard can distinguish merge
from direct commit — both falsified by IW-1.

## Decisions
### 2026-06-14 — cherry-pick-to-master policy (deferred to the build task)
- **Open choice:** whether the Layer-1 guard also blocks `git cherry-pick` onto master (CHERRY_PICK_HEAD
  present). Blocking it closes the exact path prior sessions used to deploy T-2376..T-2379 directly; allowing
  it leaves a direct-write channel open.
- **Disposition:** defer to the Layer-1 build task; recommend **block by default + Tier-2 bypass** for the
  rare deliberate deploy, consistent with "master is merge-only."

## Scope split with [[T-2393]]
A resolves the *current* divergence (one-time). B prevents the *class* (standing). A's residual hand-off
("two sessions can still commit master; worktrees will diverge again") is exactly B's G1+G2.
