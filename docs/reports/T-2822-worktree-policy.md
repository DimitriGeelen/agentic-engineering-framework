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

**Status: complete.** It reframed the question, which is the useful outcome of a spike.

Created a scratch worktree (`git worktree add --detach`) and asked what a source-only
worktree would have to *not* contain. It contains all of it, immediately:

```
PRESENT .context   PRESENT .tasks   PRESENT .agentic-framework   PRESENT .claude
```

Because governance state is **tracked content**:

| Path | Tracked files |
|---|---|
| `.tasks/` | 2812 |
| `.context/` | 4582 |
| `.context/working/` | 96 |

Only `.context/working/.budget-status` is gitignored. Everything else — `focus.yaml`,
task files, decisions, learnings, handovers — is committed content that `git checkout`
reproduces in every worktree, by definition.

**This is the mechanism of the entire defect class, and it had not been named:**

> Governance state is tracked content. A worktree is a second checkout of tracked
> content. Therefore **a worktree is by construction a fork of the governance state**,
> and it begins diverging the moment either side writes.

Measured directly: `focus.yaml` already **differed** between the two trees moments
after the worktree was created.

Two consequences that change the shape of the answer:

1. **Source-only cannot be implemented by absence.** You cannot decline to put
   governance state in a worktree; git puts it there. Untracking it is not a bounded
   fix — 7394 files, and it would destroy the audit trail that makes the state useful.
2. **So enforcement must be at the *write* layer, not the presence layer** — refuse
   writes to `.context/`/`.tasks/` when cwd is a linked worktree, and let the read-only
   copy sit there harmlessly. That answers IW-3 by elimination rather than preference.

**The cost of source-only, measured:** any framework verb that writes governance state
stops working inside a worktree — `fw work-on`, `fw task update`, `fw context focus`,
`fw handover`, `fw note`, the PostToolUse counters. Under T-100196 that is not a
regression, because the session is supposed to be on master and the worktree is
supposed to build and land source. It *is* a regression for anyone using a worktree as
a full second workspace, which is what the two stranded worktrees were doing.

**Detection primitive is one line and reliable** (verified both directions):

```sh
[ "$(git rev-parse --git-dir)" != "$(git rev-parse --git-common-dir)" ]   # true iff linked worktree
```

## S3 — Shared-state spike

**Status: not run as a spike — the question was already answered by production, which
is stronger evidence than a spike would have been.**

S3 was to ask whether sharing governance state into a worktree closes the seams or
merely moves them. The shared-state premise has been running live in this repo for
five weeks across two worktrees. Result on record (S1b/S1c):

- 43 commits unlanded and unnoticed
- an inception on this very question lost
- gap G-083 filed and lost with it
- the task-ID space forked, `T-2505` and `T-2506` each naming two different tasks

The seams moved. A spike showing "it works once" would have been a weaker claim than
five weeks of it not working, and running one now would risk manufacturing a green
result about the wrong object — the failure mode this session has already been burned
by repeatedly.

**A2 verdict:** confirmed, with the mechanism corrected. Source-only is implementable,
but not as originally framed (keep state out); only as write-refusal (let the fork
exist read-only and refuse to write to it).

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

**F1 — The root cause, named precisely.** Governance state is tracked content, so a
worktree is a *fork of the governance state*, not a view onto it. Every "worktree
bug" on record is a consequence: either a consumer read the wrong fork (81% of the
defect record) or the two forks diverged and one was lost (the 43 stranded commits).

**F2 — The prior in the task file was right about the answer and wrong about the
mechanism.** Source-only wins, but it cannot be implemented by keeping state out of
the worktree — git puts it there. It is implemented by refusing *writes*.

**F3 — Source-only buys 81%, not 100%.** The branch/ref lifecycle class (T-2393,
T-100199) and the creation-precondition class (T-2821) are untouched by it. Selling
this decision as "fixes worktree problems" would repeat the overclaim pattern.

**F4 — Ambient isolation is a harness default AEF never chose.** No `worktree` key in
`.claude/settings.json`. The deadlock that started this was the harness creating a
worktree in a repo with no HEAD, for a policy reason AEF never adopted.

**F5 — There is no invisibility guard.** Sibling worktrees are excluded from
`git status` via `.git/info/exclude`, and `fw doctor`'s `diverged-fork` check watches
only the session's own branch. Nothing was lying — nothing was looking. This is why
five weeks passed.

**F6 — The decision has already been made once and lost.** T-2505 exists. That is
itself the strongest argument for landing this one on master before doing anything
else with it.

**F7 — `git worktree add` on an unborn HEAD does not fail; it silently produces an
empty worktree.** Verified live on git 2.43.0 while checking T-2821's stated premise:

```
$ git init && git worktree add ./w1
No possible source branch, inferring '--orphan'
Preparing worktree (new branch 'w1')
RC=0                       # succeeds
$ ls -a w1  →  . .. .git   # one entry. no project files.
$ git -C w1 rev-parse HEAD →  fatal: ambiguous argument 'HEAD'
```

T-2821's Context said `git worktree add` *requires* a HEAD and refuses without one.
That is wrong, and the truth is worse: **RC=0 asserting success while producing an
unusable result.** The fresh-project deadlock is therefore not caused by refusal — it
is caused by the harness isolating a session into a valid-looking worktree that
contains no `.claude/`, no `.agentic-framework/`, no source, and no governance state.

Corrected in OBS-175. The T-2821 fix stands and is better motivated by the real
mechanism; only the narrative was wrong. Its test already asserted the right thing
("checks out from the real HEAD, not an orphan"), so the code was never at risk — the
*explanation* was.

Two consequences for this inception:

- **It strengthens the GO, not weakens it.** An empty-orphan worktree is the most
  extreme case of the S2 finding: worktree state is a fork of the main checkout's, and
  here the fork is empty. Same fault, maximal amplitude.
- **It adds a preflight to slice 3.** Whatever creates a worktree must verify HEAD
  resolves *first*, because git will not tell you. This is the same false-green class
  the framework has been fixing all session (T-2732, T-2774, T-2793) — and this
  instance is in git itself, so no amount of AEF hardening removes it; only a
  preflight does.

## Recommendation

**Recommendation: GO — source-only, enforced at the write layer.**

Answering the question as asked: **only source may live inside a worktree.** The
governance-state copy that git necessarily checks out is to be treated as read-only,
and writes to `.context/` and `.tasks/` from a linked worktree are to be refused.

**Rationale.** The evidence does not present a balanced trade-off. The shared-state
option is not hypothetical — it has been running in this repo for five weeks and its
measured output is 43 lost commits, a lost gap, a forked task-ID space, and a lost
inception on this exact question. The source-only option costs the ability to run
governance verbs from inside a worktree, which under the already-recorded T-100196
session-on-master flow is not something we are supposed to be doing. One option's cost
is measured and severe; the other's is a workflow we have already decided against.

**Bounded fix path**, in dependency order — each is a separate build slice:

1. **Detection + refusal.** One-line worktree detection in the existing PreToolUse
   path (the hooks already share `fw_reanchor_from_cwd`, `lib/paths.sh:110`); refuse
   Write/Edit to `.context/`/`.tasks/` when cwd is a linked worktree, with a block
   message naming the correct move (do it on master). Bypass env-var per L-399, and —
   per T-1890 — every *fw verb* the gate can block must accept the bypass end to end,
   not just the hook.
2. **Visibility.** `fw doctor` reports sibling worktrees with unlanded-commit counts
   and age. F5 is the reason five weeks passed; without this, slice 1 prevents new
   strands but never surfaces existing ones.
3. **Turn off ambient isolation** (IW-2) — set the harness key explicitly rather than
   inheriting a default, so worktree creation is a decision with a trigger.
4. **Retire or re-target the shared-state code** (IW-4) — `fw_reanchor_from_cwd` and
   the worktree-aware audit/doctor/budget work. **Not** a delete: under source-only,
   read-path re-anchoring is still correct and still wanted; it is the *write* paths
   that become unreachable. This slice is an audit, not a removal.

**Explicitly out of the GO**, and each needs its own task: recovering the 43 stranded
commits (OBS-174), the duplicate `T-2505`/`T-2506` IDs (T-100202 class), the
branch/ref lifecycle class (F3), and T-2821.

**Evidence:** S1a classification table (16 defects, 13 in the root-split class); S1b
live worktree inventory (`git worktree list`, `git rev-list --count`); S1c stranded
`54adb1fcf`; S2 tracked-file counts (2812 + 4582) and the measured `focus.yaml`
divergence; S2 detection primitive verified in both directions; A3 re-verified against
`.claude/settings.json`.

**What would change this recommendation:** evidence that a real workflow needs
governance writes from inside a worktree and cannot be restructured onto master. Slice
1 should ship behind a logged bypass precisely so that, if such a workflow exists, it
shows up in the bypass log as data instead of as a silent workaround.
