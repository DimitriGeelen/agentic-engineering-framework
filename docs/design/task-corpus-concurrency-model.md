# Task corpus concurrency model

**Status:** adopted (T-3106). Implementation status per rule, below.
**Origin:** three duplicate task IDs (T-2505, T-2506, T-2428) minted 2026-07-01 in
two linked worktrees, invisible for seven weeks. RCA context: T-100202 / L-506,
T-2822, T-3103.

## The mismatch

Git's worktree model assumes tracked content is **per-checkout**: you fork it,
edit it, merge it back. That is correct for source. Two branches editing
`lib/paths.sh` is normal, and merge resolves it.

The task corpus is not source. It is a **registry with global invariants** — IDs
unique across all space and time, one authoritative status per task. A registry
cannot fork and merge. There is no merge resolution for *"we both minted T-2505
for different work"*: the information needed to resolve it was destroyed at
allocation time, when each side independently answered "what is the next free
number?" with the same number.

Stated plainly: **we stored a database in a filesystem that supports branching,
and then branched it.**

## Why the storage is nonetheless right

The instinct is to conclude the storage is wrong and move tasks into SQLite. That
trades away two of the four constitutional directives:

- **Usability** — tasks are diffable, greppable, reviewable in a PR, renderable in
  Watchtower, and editable by a human with a text editor.
- **Portability** — no database dependency, no migration story, no server.

against a problem that is not actually about storage. Files-in-git is the right
substrate. **What was missing was a concurrency model** — a statement of who may
write, who may only read, and how allocation is serialised. That is what this
document supplies.

## The pattern

**Single authority, many read replicas, globally serialised allocation, and
verification that declares its scope.**

```
      ┌──────────────────────────┐
      │   MAIN CHECKOUT          │   authority
      │   .tasks/  .context/     │   sole writer
      └────────────┬─────────────┘
                   │ git checks out a copy
       ┌───────────┼───────────┐
       ▼           ▼           ▼
   worktree A  worktree B  worktree C     read-only replicas
   .tasks/     .tasks/     .tasks/        (source is writable; corpus is not)

   allocation: union-scan every replica, one lock at the authority
   verification: evaluate every replica, and say how many you evaluated
```

A replica exists because git puts it there — it cannot be prevented by *absence*
(T-2822 F2). It can only be made harmless by refusing **writes**.

## Business rules

| # | Rule | Status | Shipped by |
|---|---|---|---|
| **R1** | An ID identifies one task **forever**, across every view. Never reused, even after deletion. | invariant | — |
| **R2** | The main checkout is the **sole authority**. Worktrees hold read-only replicas of the corpus. | ✅ | T-3098 |
| **R3** | Allocation is **globally serialised**: union view of all replicas, one lock held at the authority. | ✅ | T-100202 |
| **R4** | Mutation is **single-writer**. Replicas never write the corpus. Source in a worktree remains freely writable. | ✅ | T-3098 |
| **R5** | Verification spans **all views**, and every check **states the set it evaluated**. | ✅ | T-3104, T-3105, T-3107 |
| **R6** | Divergence is reconciled by a **named operation**, never silently merged. | manual | T-3103 |
| **R7** | Enforcement must come from the **authority**, never from the replica it constrains. | ⏳ | T-3108 (GO) |

### R6 collapses once R2 and R4 hold

This is the property that makes the design closed rather than merely defensive.
If replicas cannot write, replicas cannot diverge, so there is nothing to
reconcile. R6 therefore applies only to **legacy** divergence created before
T-3098 — which is exactly the scope T-3103 handled by hand, once. It does not need
a standing verb.

### R5 is the live gap, and it is not about tasks

R5 failed three times in one day, in three unrelated systems:

| Surface | What it reported | What it evaluated |
|---|---|---|
| GO-scope-not-propagated | `PASS` | 2 of 444 inceptions (0 after the next filter) |
| skills-manager errors store | `No errors found` | nothing — it could not read the store |
| duplicate task IDs | `No duplicate task IDs` | 1 of 5 corpus views |

None of these lied. Each is true of the ground it covered. **The defect is that
none stated its ground**, so *"I found nothing"* and *"I looked nowhere"* render
identically — and only one of those deserves a green line.

The generalised rule:

> **A check may only PASS over the set it actually evaluated, and must report that
> set's size. An empty or unenumerable candidate set is a WARN, not a PASS.**

`no duplicate task IDs among 3124 tasks across 5 views` is falsifiable.
`No duplicate task IDs` is not. The count is what makes the line an assertion
rather than a mood.

## Why one definition of "the corpus", not two

The ID allocator already union-scans every replica (`_task_view_dirs`,
`agents/task-create/create-task.sh`). The audit's duplicate check does not. Both
answer questions *about the same corpus*, from two different definitions of what
the corpus is — and only one of them was updated when the worktree problem was
understood.

The fix is structural, and the framework has already demonstrated it works:
`fw_branch_hygiene` is a single predicate that both `fw doctor` and `fw audit`
read, which is why T-3101's new finding class appeared on both surfaces without
either being edited. One definition, many consumers.

### Where consumers may legitimately differ

`.tasks/` is corpus to the allocator and a **deliverable** to
`_wt_is_ignorable_path` in `lib/worktree.sh`, which decides whether a branch's
work has landed. Two callers, two correct answers, one path. This is not drift and
must not be "unified" — the difference is documented at both sites so the next
reader does not helpfully turn it into a bug.

## Implementation

| Slice | Deliverable | Task |
|---|---|---|
| 1 | Lift the corpus view set into a shared library; allocator and audit read one definition | T-3104 |
| 2 | Duplicate-ID detection spans all views; distinguishes *within-authority* duplicates (a real bug) from *cross-view* duplicates (a fork artifact) | T-3107 ✅ |
| 3 | Audit checks declare their evaluated set; empty or unenumerable sets WARN | T-3105 |

Slices 1 and 3 have disjoint write sets and run in parallel. Slice 2 writes
`agents/audit/audit.sh` (converging with slice 3) and depends on slice 1's
library, so it is serialised behind both — fan out on reads, fan in on writes.


## R7 — the enforcement code forks too

R1-R6 assume the rules are *enforced*. They are enforced by code. **That code is
tracked content, so it forks with the branch** — which means the replica supplies
the code that is supposed to constrain the replica. That is circular, and no
amount of hardening inside `agents/` escapes it.

This is not a hypothesis. Measured in this repo, in the `t100199-close` worktree:

| Fix | In the authority | In the replica |
|---|---|---|
| `check-worktree-governance-write.sh` (R2/R4) | present | **absent** |
| union-scan in the allocator (R3) | 2 occurrences | **0** |
| `${CLAUDE_PROJECT_DIR}` in `settings.json` (T-2709) | present | **0 refs** |

Its `bin/fw` is dated **6 July**. A session opened there today allocates IDs the
pre-T-100202 way and writes governance freely. **Every fix in this document is
absent from the replica it was designed to constrain.**

Vendored consumers are the same shape with a multiplier: `.agentic-framework/` is
tracked, so it forks identically, *and* consumers only receive fixes when someone
runs `fw upgrade`. `fw doctor` currently reports that **31 of 31 consumers are
missing `check-worktree-governance-write`**.

### The one anchor that does not fork

`.git/hooks` resolves to the **shared common dir** from the main checkout and from
every linked worktree alike — verified, and `core.hooksPath` is set explicitly
rather than merely defaulted. Four hooks already live there (`commit-msg`,
`post-commit`, `pre-commit`, `pre-push`).

**A git hook installed once at the authority runs in every linked worktree
regardless of that worktree's framework version.** It is the only enforcement
point immune to the fork, and therefore the only one that reaches a replica
created *before* the fix existed.

### Four legs

| Leg | What it does | What it does **not** reach |
|---|---|---|
| **L1** — corpus guard in the shared `pre-commit` | refuses a commit touching `.tasks/` when `--git-common-dir` ≠ `--git-dir`. Version-independent; reaches pre-existing and stale replicas | uncommitted writes; a repo that overrides `core.hooksPath` |
| **L2** — re-exec redirection | `bin/fw` detects a linked worktree and re-execs the **authority's** `bin/fw`, fixing stale-replica-code and allocation in one move | worktrees whose checkout predates the redirect — future-facing only |
| **L3** — worktrees as a drift subject | `fw doctor` audits 31 *consumers* for missing hooks and **zero worktrees**. Same predicate, new subject (the T-3101 shape) | nothing, once shipped — but it reports, it does not prevent |
| **L4** — loud vendored propagation | `fw upgrade` names which of a project's worktrees are behind; doctor says it unprompted | a project that never runs `fw upgrade` at all |

**L1 is the keystone** because it is the only leg with no version precondition.
L2 is the *complete* fix but only for replicas created after it ships. L3 and L4
make the gap visible rather than closing it — which is worth having, since the gap
was invisible for the seven weeks that produced T-2505, T-2506 and T-2428.

### The honest limits

L1 fires at commit-time, not write-time, so an uncommitted duplicate still exists
on disk — weaker than R2's write block, but universal where R2 is not. It assumes
`core.hooksPath` is not overridden. And none of the four legs reaches a project
that never upgrades, which is why L4 carries the vendored fleet and why a
**release channel** (stable vs experimental) is the natural companion decision:
today every consumer implicitly tracks whatever `master` happens to be, and the
only reason that has been safe is the accident of master sitting behind while
experimental work accumulated beside it. That safety is unmanaged.

## What would change this design

Evidence that a real workflow needs to **write** the task corpus from inside a
worktree, and cannot be restructured to write it on master instead. T-2822
searched for such a workflow and did not find one; the session-on-master flow
(T-100196) already assumes governance writes happen at the authority. If one is
found, R2 and R4 are the rules that must move, and R5 becomes load-bearing rather
than merely correct.
