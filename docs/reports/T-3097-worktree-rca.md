# T-3097 — The worktree failure class: RCA and structural fix

**Type:** inception · **Opened:** 2026-08-20 · **Status:** exploration in progress

Created before research per C-001. Updated incrementally; the thinking trail is the
artifact.

## The question

The operator, verbatim:

> *"We still have huge headache with work trees. I want us to do an ultra deep analysis
> on the root cause, design a fix, and implement this fix. This is your highest priority
> and your... the single thing you're working on unless something breaks even worse.
> Also, look in your pickup requests … because one of the other agents already researched
> this and probably has proposed a root cause analysis and fixes."*

Plus a second, separable question:

> *"Read back in our errors log. Do you keep a record of errors? … I don't know if that's
> functioning. … Would be good to got this statistics."*

## Headline verdict

**The root-cause analysis the operator remembers exists, is correct, and was approved.
It was never built.**

The prior agent's work is `docs/reports/T-2822-worktree-policy.md` (2026-08-06). It names
the mechanism exactly right, recommends a bounded four-slice fix, and the operator
recorded **GO** on it the same day. Two weeks later:

| Slice | What it was | State today |
|---|---|---|
| 1. **Detection + write-refusal** — refuse `.context/`/`.tasks/` writes from a linked worktree | the only slice that *enforces* anything | **never built, and no task was ever filed for it** |
| 2. Visibility — surface sibling worktrees with unlanded counts and age | closes the five-week blindness | **partial** — `fw doctor`/audit report `worktree-merged`, never unlanded counts |
| 3. Turn off ambient isolation (`bgIsolation`) | stop the harness creating worktrees AEF never asked for | filed as **T-2861, status `captured`** — never started |
| 4. Re-target the shared-state code | audit, not removal | not started |

So the honest answer to *"why do we still have a headache"* is not that the analysis is
missing or wrong. It is that **a correct, approved fix produced no buildable work for its
keystone slice, and nothing noticed for two weeks.**

That reframes the RCA. There are two root causes stacked, and only the first has ever
been analysed.

---

## IW-1 — The errors log: does it exist, does it function?

**Disposition: answered. The operator's doubt is justified — there is a counter, but no log.**

Two things exist, and neither is an error record:

**1. A derived counter, not a log.** `agents/context/session-metrics.sh:244` recomputes
`failed_tool_calls` from the session transcript at handover time. Current values:

```
failed_tool_calls: 494          failed_tool_call_rate: 0.0754     (cumulative, 6551 tool calls)
session_failed_tool_calls: 12   session_failed_tool_call_rate: 0.0789
```

It is an aggregate over a JSONL that is not itself a register. There is no per-error row:
no timestamp, no tool, no message, no subsystem, no "did this recur". **Statistics beyond
the single rate are therefore not derivable** — including the one the operator actually
wants, which is *"how many of these were worktree errors."*

**2. A healing store that is four months dead.** `.context/project/patterns.yaml` is the
failure-pattern register `fw healing resolve` writes to. It holds **19 entries and was
last written 2026-04-08** — 134 days ago. Every entry carries `occurrences_at_step: 0`.
The Error Escalation Ladder (CLAUDE.md §A/B/C/D) is documented as feeding this file; in
practice nothing has fed it since April.

**What does function** is a de-facto incident record, scattered across four registers that
are not named "errors" and have no error-specific view:

| Register | Total entries | Mentioning worktree |
|---|---:|---:|
| `.context/inbox.yaml` (observations) | 329 | **11** |
| `.context/project/concerns.yaml` (gaps) | — | **50 lines** |
| `.context/project/learnings.yaml` | — | **7 lines** |
| `.tasks/{active,completed}/` | ~3030 | **188 files** |

So the record is real and rich — 188 task files touch worktrees — but it is a corpus you
grep, not a register you query, and no surface aggregates it. That is why the operator
cannot get statistics: not because nothing is captured, but because capture is scattered
across four schemas and the one register purpose-built for failure patterns is dead.

**This is a genuine finding and it is separable from the worktree work.** It gets its own
task rather than being bundled here (§Task Sizing Rules: one deliverable per task).

---

## IW-2 — What the peer agent already found

**Disposition: answered. Found, read, and it is right.**

`docs/reports/T-2822-worktree-policy.md` (340 lines, 2026-08-06). Its F1 is the mechanism,
and it is worth quoting because it is the sentence the whole class turns on:

> Governance state is tracked content. A worktree is a second checkout of tracked content.
> Therefore **a worktree is by construction a fork of the governance state**, and it begins
> diverging the moment either side writes.

Measured, not asserted: `.tasks/` is 2812 tracked files, `.context/` is 4582; only
`.context/working/.budget-status` is gitignored. `focus.yaml` was observed differing
between the two trees moments after a worktree was created.

Its corollary is the part most likely to be got wrong by a fresh analysis, which is why
reading it first mattered: **source-only cannot be implemented by absence.** You cannot
decline to put governance state in a worktree — `git checkout` puts it there. It can only
be implemented by refusing *writes*. A from-scratch RCA would very plausibly have proposed
untracking or excluding, and would have been wrong.

It is also honest about its own limits: source-only buys **81% (13 of 16 defects)**, not
100%. The branch/ref lifecycle class and the creation-precondition class survive it.

**I am not re-deriving this.** It is adopted as the technical root cause. What follows is
the layer above it, which T-2822 could not see because it was inside it.

---

## IW-4 — Why every previous fix failed to end the class

**Disposition: answered, and this is the finding.**

The prior fixes did not fail because they were wrong. Two of them shipped and work:
`lib/hook_paths.py` / `fw_reanchor_from_cwd` (the T-2464 resolver) and the `fw worktree`
lifecycle verbs. The class stayed alive because **the one slice that converts the analysis
into enforcement was never filed as work.**

### The propagation gap, measured

`T-2822`'s frontmatter carries `related_tasks: []`. Its Recommendation names four slices
in prose. No task in the corpus declares `unlocks_inception_decision: T-2822:*`. The tasks
that *do* reference T-2822 (T-2824, T-2825, T-2829, T-2831, T-2861) are, with one
exception, the items T-2822 explicitly fenced **out** of its GO — strand recovery, teardown
bugs, the OBS-177 guard. The single exception, T-2861 (slice 3), sits at status `captured`.

**Slice 1 has no task, no hook, no branch, no commit.** `ls agents/context/ | grep -i
worktree` returns nothing.

### Why nothing caught it

The framework has a detector built for precisely this failure — `audit.sh:1517`,
*"GO-scope-not-propagated scan"*, whose docstring describes the T-2078 origin case in terms
that fit T-2822 exactly: *"completed inceptions whose Recommendation/Decision claim
sub-tasks were filed, but `related_tasks: []` and no other task back-references the
inception."*

T-2822 satisfies the structural half of that predicate — `related_tasks: []` is literally
true. It is skipped anyway, because the detector gates on a **phrase**:

```python
CLAIM_RE = re.compile(r'filed on GO|sub-tasks (filed|created)|build slices (filed|created)'
                      r'|child tasks (filed|spun off)', re.I)
```

T-2822's Recommendation says:

> **Bounded fix path**, in dependency order — each is a separate build slice:

`each is a separate build slice` does not match `build slices (filed|created)`. Verified
directly: the regex returns **no match**, so the inception is never a candidate. Today's
audit accordingly printed `[PASS] No GO-scope-not-propagated inception(s)` while a live
instance sat two weeks old.

That is the shape of the failure: **a rail that fires on how an inception phrased its
promise rather than on whether the promise was kept.** A detector keyed to prose will be
silent exactly when an author writes carefully, which is an inverse correlation with the
thing being measured.

### Why this is the operative root cause, not a footnote

The operator's question is *"why does this keep happening."* Six fixes shipped across five
months and the class is live. The technical mechanism (T-2822 F1) explains why worktrees
generate defects. It does not explain why the approved fix for that mechanism is absent
two weeks after approval — and that second thing is what makes the class *recurrent* rather
than merely *hard*. A seventh technical fix, designed today, is subject to the identical
gap unless the gap is closed first.

Stated as the causal chain:

```
governance state is tracked content
  → a worktree is a fork of it                          [T-2822 F1 — correctly analysed]
    → defects at every join                             [16 recorded, 13 of one class]
      → correct fix designed and approved (T-2822 GO)   [2026-08-06]
        → keystone slice never filed as a task          [the gap]
          → the detector for that gap is prose-keyed    [audit.sh:1545 — silent]
            → two weeks of PASS on a live instance      [today's audit]
              → operator still has the headache         [2026-08-20]
```

---

### The gap is a class, not an instance — measured

If T-2822 were the only inception whose GO produced no slices, the fix would be "file
slice 1" and this would be a footnote. It is not. Running the detector's own predicate
over the corpus:

```
completed tasks scanned                            : 2705
  workflow_type: inception                         :  444
  matching CLAIM_RE (the detector's gate)          :    2      <-- must be >0 to ever fire
    ...and related_tasks empty                     :    0      <-- the actual candidate set
```

**The candidate set is empty by construction.** In 444 completed inceptions the claim
regex matches twice, and both of those have populated `related_tasks`, so they are
filtered out at the next step. The detector has never had a candidate to report. Every
`[PASS] No GO-scope-not-propagated inception(s)` ever printed — including today's — is
vacuous: it asserts that a set nothing can enter is empty.

Against that, the population it was built to triage, with every filter applied
conservatively (GO recorded, names slices, `related_tasks: []`, back-referenced by
nobody, would not have matched the regex):

```
GO'd completed inceptions invisible to the detector : 178
```

**Corrected upward from 54 during the build, and the correction matters.** This section
first reported 54, because I additionally required the inception's prose to *mention*
slices or sub-tasks. That filter is itself vocabulary — the very thing the fix removes —
so applying it to size the backlog reproduced the defect in the measurement of the defect.
Under the purely structural predicate (GO recorded · `related_tasks:` empty or absent · no
back-reference · no `unlocks_inception_decision:`) the count is **178**, confirmed
independently against the shipped detector. T-2822 is finding #48 of 178. The worktree headache is a symptom of a governance rail that has
been reporting green while blind since it shipped (T-2096).

**Two caveats, stated so the number is not oversold.** The 178 are *candidates for triage*,
not 178 confirmed abandoned decisions — some may have shipped work that simply never linked
back, which is exactly the judgement the detector was supposed to force somebody to make.
And the detector scans `completed/` only, so live inceptions are out of scope by design.
Neither caveat touches the finding: 2/444 on the gate means the rail cannot fire.

---

## IW-5 — The fix

**Disposition: answered. Two legs, neither of which requires a new decision.**

### Leg A — build T-2822 slice 1 (the approved, never-built enforcement)

Refuse agent Write/Edit to `.context/**` and `.tasks/**` when the tool call's cwd is a
linked worktree. Detection is one line and was verified in both directions by T-2822's S2:

```sh
[ "$(git rev-parse --git-dir)" != "$(git rev-parse --git-common-dir)" ]
```

Design notes that matter:

- **Refusal, not absence.** Per T-2822 F2 — you cannot keep governance state out of a
  worktree, git puts it there. The checked-out copy stays and is treated as read-only.
- **Bounded blast radius by construction.** A PreToolUse hook sees agent tool calls, not
  writes performed inside scripts (the Tier 0 scope boundary, CLAUDE.md §Enforcement
  Tiers). So `fw integrate` and friends are untouched; what is governed is an agent
  authoring governance state into a fork of it, which is precisely the T-2505 loss shape.
- **Ships behind a logged bypass, deliberately.** T-2822's own words: *"so that, if such a
  workflow exists, it shows up in the bypass log as data instead of as a silent
  workaround."* The framework's dispatch protocol does use worktrees for parallel edits,
  and whether those workers legitimately need governance writes is an open empirical
  question. The bypass log answers it in weeks; guessing now does not.
- **Per L-399 / T-1890**, the bypass must work end to end — env-var form (`git commit` and
  other external parsers cannot take a flag), and every `fw` verb the gate can block must
  accept it without an "Unknown option".

This needs **no new go/no-go**: the operator recorded GO on it 2026-08-06. Building it is
executing an existing decision.

### Leg B — make the GO-scope detector structural instead of prose-keyed

Replace the phrase gate with the structural predicate that is already true of the failure:
a GO'd inception, `related_tasks:` empty or absent, no task back-referencing it, and no
`unlocks_inception_decision:` pointing at it. That predicate needs no vocabulary and
cannot be evaded by writing carefully.

The 178 become a backlog to triage, not 178 new WARNs on day one — the detector should report
a count and a sample, with the full list behind a command, or it will be ignored the way
every wall-of-text audit section is.

This is a bug fix under the existing rail, not a new capability: one bug, one task.

### What is explicitly NOT in this fix

- Recovering the 43 still-stranded commits. T-2824 recovered the *content* and correctly
  routed **branch deletion to the operator as Tier 0**; that handoff is simply outstanding.
  It is an operator action, not agent work, and it is listed in the handoff below.
- The branch/ref lifecycle class and the creation-precondition class — T-2822 F3 is honest
  that source-only does not touch them.
- The errors-log gap (IW-1). Separate deliverable, separate task.

## Open at this point

- **IW-3** (one class or several) — T-2822's S1a classification is adopted provisionally:
  three mechanisms, 13/16 in the root-split class. Being re-derived independently by a
  dispatched corpus miner; its output lands in `T-3097-worktree-incident-corpus.md`.
- **IW-5** (the fix) — not yet written. Blocked on the corpus result and on measuring
  whether the propagation gap is an instance or a class (below).
- **The propagation gap's own frequency is unmeasured.** If T-2822 is the only inception
  whose GO produced no slices, this is an instance and the fix is to file slice 1. If it
  is one of many, the detector hole is the higher-value target. This is the next
  measurement and it decides the shape of the recommendation.

## Dialogue Log

**2026-08-20 — operator escalates worktrees to sole priority.**

Verbatim ask reproduced at the top. Three explicit instructions: ultra-deep RCA, design
*and implement* the fix, and — the one that changed the outcome — *look for the other
agent's prior research first*.

That instruction was load-bearing. The prior artifact (T-2822) contains a mechanism
finding (`source-only cannot be implemented by absence`) that a fresh analysis would
likely have missed, and its existence-plus-non-execution is itself the principal finding
of this inception. Had I started from a blank page I would have re-derived a worse version
of an analysis that was already approved, and the actual defect — that approval produced no
work — would have stayed invisible.
