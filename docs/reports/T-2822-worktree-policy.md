# T-2822 — Worktree policy: what may live inside a worktree

**Type:** inception · **Opened:** 2026-08-06 · **Status:** exploration in progress

Created before research per C-001. Updated incrementally; the thinking trail is the
artifact, and this file — not the conversation — is what survives.

## The question

> **What may live inside a worktree — source only, or shared governance state?**

Everything else in this inception falls out of that answer.

## Why this is a decision and not a task

Two contradictory premises are live in the codebase at once:

| Premise | Built on it |
|---|---|
| Governance state should follow you into the worktree | `fw_reanchor_from_cwd` (T-2464), worktree-aware audit/doctor (T-2435, T-2437), budget-gauge worktree fixes (T-2375, T-2377, T-2400) |
| Governance state lives only in the main checkout | CLAUDE.md §Trunk-Based Session Flow (T-100196) — session on master, worktrees for landing source |

Each is coherent alone. Holding both produces defects at the joins, which is the
shape of the incident record.

## Origin

The operator's question, verbatim:

> *"ok but why are we creating a worktree from start, thouigh we discussed only doing
> this is special circumstanced, pelase readback teh diacussiuona and decsioin we had
> for thsi (especially because we had somemany worktree isseus)"*

The readback found only **two** recorded worktree decisions in `decisions.yaml`
(:168 WorktreePool for audits; :2149 integrate cleanup). Neither authorises ambient
isolation of a governance session. `.claude/settings.json` has **no `worktree` key** —
so the `bgIsolation` behaviour that deadlocked the fresh-project session is a *harness
default AEF never chose*, not an AEF decision. That is the second question (IW-2).

## S1 — Corpus mine

**Status: complete.** It found more than a classification — it found live evidence.

### S1a — Classification of the defect record

23 worktree-referencing tasks; 16 are defects (the rest are the tooling built to
manage them: T-2464 inception, T-2466/T-2469 `fw worktree`, T-2478 verify).

| Seam | Tasks | n |
|---|---|---|
| **Root resolution** — a consumer resolved PROJECT_ROOT to the main checkout while running in a worktree | T-2463, T-2465, T-2468, T-2390, T-2392, T-2501 | 6 |
| **Derived-path reconstruction** — a path rebuilt from the project dir name, which differs in a worktree (transcript dir, costs, budget gauge) | T-2375, T-2377, T-2380, T-2400, T-2425 | 5 |
| **Environment-vs-content** — cron/audit loaded from the wrong tree | T-2435, T-2437 | 2 |
| **Branch/ref lifecycle** — divergence, stranded branches, hygiene | T-2393, T-100199 | 2 |
| **Creation precondition** — no HEAD, worktree not creatable | T-2821 | 1 |

**A1 is substantially confirmed but not universal — 13/16 (81%)** of defects are the
first three rows, and all three are the same underlying fault: *governance state lives
in the main checkout and something in the worktree needed it*. The residual 3 are
genuinely different (lifecycle and creation), and **a source-only policy would not
have prevented them**. Stating that plainly matters: the decision buys 81%, not 100%,
and IW-1 must not be sold as fixing the divergence class.

### S1b — Three live worktrees, two of them stranded

Not history. Present state of this repo, found while grepping for callers:

```
.claude/worktrees/inception-gov-payload-mediation   6 unlanded commits, last activity 5 weeks ago
.claude/worktrees/rca-worktree-push-strand         37 unlanded commits, last activity 5 weeks ago
.claude/worktrees/t100199-close                     0 unlanded  (clean)
```

**43 commits, dormant five weeks, invisible to every governance surface.** They are
excluded via `.git/info/exclude`, so `git status` is clean; `fw doctor`'s
`diverged-fork` check (T-100195) watches the *session's* branch, not sibling
worktrees. Nothing was lying — nothing was looking.

Each stranded worktree contains its **own full `.context/` and `.tasks/`**. That is
the shared-state premise running in production, and this is what it produced.

### S1c — The finding that decides it

Among the stranded commits:

```
54adb1fcf  T-2505: file inception — worktree usage/lifecycle policy (refine per-task default)
```

**A prior inception on this same question was filed on 2026-07-01, at this operator's
request, and was lost inside a worktree.** Its trigger, verbatim from the stranded
artifact:

> *"seems the worktrees give us a lot of difficulties right now"* … *"did we not
> re-evaluate worktree separation, refining not to use worktrees for every task?"*

The operator's recollection was correct, and the record was there — in a worktree
nobody could see. Their question five weeks later (*"pelase readback teh diacussiuona
and decsioin we had for thsi"*) could not be answered from master because the answer
had been written to a tree that never landed.

Worse: **the task ID `T-2505` was re-allocated on master** (`T-2505-ratify-p-03-red-team-test-contract-spec`),
as was `T-2506`. Two different tasks share each ID depending on which tree you read —
the T-100202 split-view class, caused here by governance state being authored inside a
worktree.

### What S1 established

1. 81% of the defect record is one fault: state in the main checkout, consumer in the worktree.
2. The shared-state premise is running live and has silently lost 43 commits.
3. It lost, among other things, the previous attempt to answer this very question.
4. It corrupted the task-ID space, which is supposed to be globally unique.

Point 3 is not rhetorical. It is the cost of the shared-state option, observed rather
than predicted.

### Prior art absorbed from stranded T-2505

T-2505 asked a **different axis** — *how often* should a worktree be created (its
candidates C1–C4 are all about frequency and lifecycle). T-2822 asks *what may live
inside one*. They compose: T-2505 is IW-2 here. Not a duplicate; T-2505's candidates
are inherited rather than re-derived.

T-2505 also verified, and this run re-verified, that **`D-026` (2026-04-25, T-1483) is
the only recorded worktree usage decision, and it is audit-specific** (WorktreePool,
one worktree per audit run). There has never been a decision authorising worktrees as
a general per-task default — which is precisely what the operator remembered.

### A3 re-verified

`.claude/settings.json` contains **no `worktree` or isolation key**. Ambient
background-session isolation is a harness default AEF never chose. Confirmed.

## S2 — Source-only spike

*Status: not started.*

## S3 — Shared-state spike

*Status: not started.*

## Dialogue Log

**2026-08-06 — operator asks whether to incept.**

> *"ok what now, whjat do we do to better implement teh worktreeu usage when its
> reall yasneeded thinking?"*

Agent proposed five items (source-only gate, disable ambient isolation, preflight at
`fw worktree create`, deterministic cleanup + doctor surfacing, lifecycle testing) and
recommended **building none of them yet**, because items 1 and 2 are a genuine
either/or and building the wrong one is how the current state accumulated.

> *"should we incpet this and deep researcha nd etst this ?"*

Agent: yes. Reasoning recorded at the time — (a) it is a fork, not a task, and the two
premises above are demonstrably both live; (b) the evidence base already exists in
episodic memory, so this is a corpus *read*, not a discovery project. Scoped to one
question per §Task Sizing Rules; T-2821 fenced out because it is a bug under either
policy and is nearly done.

## Findings

*Populated as spikes complete.*

## Recommendation

*Pending S1. Filed DEFER at creation — a genuine evidence gap, not a hedge: no spike
has run.*

**Prior (to be killed or confirmed, not assumed):** source-only, with governance
writes structurally refused inside a worktree. It matches T-100196 and removes the
split rather than managing it. Recorded here explicitly so S1–S3 can falsify it.
